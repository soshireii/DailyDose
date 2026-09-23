import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/utils/format_utils.dart';
import '../core/utils/time_utils.dart';
import '../models/medicine.dart';

/// Schedules repeating local notifications (they keep firing while the app is
/// closed), one-off "running low" alerts, and advance "time to refill"
/// reminders based on projected days of stock left.
///
/// Notification ids: `medicine.notificationBase * 64 + slot`
///   slot = timeIndex * 8 + dayCode   (dayCode 0 = every day, 1..7 = weekday)
///   slot 62 is the advance refill reminder, slot 63 the instant low-stock alert.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  bool _askedForExactAlarms = false;

  static const int _idsPerMedicine = 64;
  static const int _refillSlot = 62;
  static const int _lowStockSlot = 63;

  /// How many days before the projected empty date to send the refill reminder.
  static const int refillWarningDays = 3;

  static const NotificationDetails _reminderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'medicine_reminders',
      'Medicine reminders',
      channelDescription: 'Reminders to take your medicine',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  static const NotificationDetails _stockDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'low_stock',
      'Stock alerts',
      channelDescription: 'Low-stock and refill-reminder alerts',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> init() async {
    if (kIsWeb) return; // notifications are not supported on web
    try {
      tzdata.initializeTimeZones();
      try {
        final name = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(name));
      } catch (_) {
        // Falls back to UTC; reminders would be offset, but the app still runs.
      }

      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(settings);
      _ready = true;
    } catch (_) {
      _ready = false; // Notifications unsupported on this platform.
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  /// Asks for permission to show notifications (Android 13+, iOS).
  Future<void> requestNotificationPermission() async {
    if (!_ready) return;
    await _android?.requestNotificationsPermission();
    await _ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Exact alarms make reminders fire on the minute. Android 12+ needs the
  /// user to allow this in system settings; we ask once per app session.
  Future<void> ensureExactAlarmPermission() async {
    if (!_ready || _askedForExactAlarms) return;
    final android = _android;
    if (android == null) return;
    if (await android.canScheduleExactNotifications() ?? true) return;
    _askedForExactAlarms = true;
    await android.requestExactAlarmsPermission();
  }

  /// Replaces every scheduled reminder (dose times + refill reminders) with
  /// the schedule implied by [medicines].
  Future<void> syncAll(List<Medicine> medicines) async {
    if (!_ready) return;
    await _plugin.cancelAll();
    for (final medicine in medicines) {
      await _scheduleDoseReminders(medicine);
      await _scheduleRefillReminder(medicine);
    }
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }

  Future<void> showLowStock(Medicine medicine) async {
    if (!_ready) return;
    final left = formatDose(medicine.quantity, medicine.unit);
    await _plugin.show(
      medicine.notificationBase * _idsPerMedicine + _lowStockSlot,
      '${medicine.name} is running low',
      medicine.isOutOfStock ? 'You are out of stock.' : 'Only $left left.',
      _stockDetails,
    );
  }

  // ---------------------------------------------------------------- internals

  Future<void> _scheduleDoseReminders(Medicine medicine) async {
    if (!medicine.remindersEnabled || !medicine.hasSchedule) return;

    final canExact = await _android?.canScheduleExactNotifications() ?? true;
    final title = 'Time for ${medicine.name}';
    final body =
        'Take ${formatDose(medicine.dosePerIntake, medicine.unit)}'
        '${medicine.strength.isEmpty ? '' : ' (${medicine.strength})'}';

    // Every-day medicines need one repeating notification per time;
    // otherwise one per (time, weekday).
    final everyDay = medicine.days.length == 7;
    final dayCodes = everyDay ? [0] : medicine.days;

    for (var t = 0; t < medicine.scheduleTimes.length; t++) {
      final time = TimeUtils.decode(medicine.scheduleTimes[t]);
      for (final code in dayCodes) {
        final id = medicine.notificationBase * _idsPerMedicine + t * 8 + code;
        final first = _nextInstance(
          time.hour,
          time.minute,
          weekday: code == 0 ? null : code,
        );
        final repeat = code == 0
            ? DateTimeComponents.time
            : DateTimeComponents.dayOfWeekAndTime;

        Future<void> schedule(AndroidScheduleMode mode) =>
            _plugin.zonedSchedule(
              id,
              title,
              body,
              first,
              _reminderDetails,
              androidScheduleMode: mode,
              matchDateTimeComponents: repeat,
            );

        try {
          await schedule(
            canExact
                ? AndroidScheduleMode.exactAllowWhileIdle
                : AndroidScheduleMode.inexactAllowWhileIdle,
          );
        } on PlatformException {
          // Exact alarms not permitted: fall back to a slightly less precise one.
          await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
        }
      }
    }
  }

  /// Schedules a one-off "time to refill" notification [refillWarningDays]
  /// before the medicine is projected to run out, based on its current
  /// stock and dosing schedule. Skipped if it's already due (the low-stock
  /// alert covers that) or if there's nothing to project from.
  Future<void> _scheduleRefillReminder(Medicine medicine) async {
    if (!medicine.remindersEnabled || medicine.isOutOfStock) return;
    final daysLeft = medicine.daysRemaining;
    if (daysLeft == null) return;

    final now = DateTime.now();
    final runOutDate = TimeUtils.dateOnly(now)
        .add(Duration(days: daysLeft.floor()));
    final reminderDay = runOutDate.subtract(
      const Duration(days: refillWarningDays),
    );
    final scheduled = DateTime(
      reminderDay.year,
      reminderDay.month,
      reminderDay.day,
      9,
      0,
    );
    if (!scheduled.isAfter(now))
      return; // too soon; low-stock alert already covers it

    final id = medicine.notificationBase * _idsPerMedicine + _refillSlot;
    final tzTime = tz.TZDateTime.from(scheduled, tz.local);
    try {
      await _plugin.zonedSchedule(
        id,
        'Time to refill ${medicine.name}',
        'At the current pace you will run out around '
            '${DateFormat('MMM d').format(runOutDate)}. Consider ordering a refill.',
        tzTime,
        _stockDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {
      // Best-effort: a missed refill reminder shouldn't break the rest of sync.
    }
  }

  tz.TZDateTime _nextInstance(int hour, int minute, {int? weekday}) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (weekday != null) {
      while (scheduled.weekday != weekday) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
    }
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(Duration(days: weekday == null ? 1 : 7));
    }
    return scheduled;
  }
}
