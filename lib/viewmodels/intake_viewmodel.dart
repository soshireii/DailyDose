import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/utils/time_utils.dart';
import '../models/dose_slot.dart';
import '../models/intake_log.dart';
import '../models/medicine.dart';
import '../repositories/intake_repository.dart';
import '../services/notification_service.dart';
import 'medicine_viewmodel.dart';

/// Intake history + the dose plan for any given day. Logging an intake also
/// lowers the medicine's remaining quantity.
class IntakeViewModel extends ChangeNotifier {
  IntakeViewModel(this._repo, this._medicines, this._notifications) {
    // Rebuild dependants when medicines change (the day plan depends on them).
    _medicines.addListener(notifyListeners);
  }

  final IntakeRepository _repo;
  final MedicineViewModel _medicines;
  final NotificationService _notifications;

  String? _uid;
  StreamSubscription<List<IntakeLog>>? _sub;
  List<IntakeLog> _logs = const [];
  bool _loading = false;
  String? _error;
  String? _filterMedicineId;

  bool get isLoading => _loading;
  String? get error => _error;
  String? get filterMedicineId => _filterMedicineId;

  void bindUser(String? uid) {
    if (uid == _uid) return;
    _uid = uid;
    _sub?.cancel();
    _sub = null;
    _logs = const [];
    _error = null;
    _filterMedicineId = null;

    if (uid == null) {
      _loading = false;
      return;
    }
    _loading = true;
    _sub = _repo
        .watchLogs(uid)
        .listen(
          (logs) {
            _logs = logs;
            _loading = false;
            notifyListeners();
          },
          onError: (Object _) {
            _loading = false;
            _error = 'Could not load your history. Check your connection.';
            notifyListeners();
          },
        );
  }

  // ---------------------------------------------------------------- day plan

  /// Every dose scheduled on [date], oldest first, matched with its log entry.
  /// Works for past, present or future dates.
  List<DoseSlot> dosesForDate(DateTime date, {DateTime? now}) {
    final day = TimeUtils.dateOnly(date);
    final slots = <DoseSlot>[];

    for (final m in _medicines.medicines) {
      if (!m.hasSchedule || !m.days.contains(day.weekday)) continue;
      final createdDay = TimeUtils.dateOnly(m.createdAt);
      if (createdDay.isAfter(day)) continue; // didn't exist yet on this day
      for (final time in m.scheduleTimes) {
        final at = TimeUtils.on(day, time);
        // Don't nag about doses from before the medicine was added that day.
        if (createdDay == day && at.isBefore(m.createdAt)) continue;
        slots.add(DoseSlot(medicine: m, scheduledAt: at, log: _logFor(m, at)));
      }
    }

    slots.sort((a, b) {
      final byTime = a.scheduledAt.compareTo(b.scheduledAt);
      return byTime != 0 ? byTime : a.medicine.name.compareTo(b.medicine.name);
    });
    return slots;
  }

  /// Convenience wrapper kept for older call sites.
  List<DoseSlot> todaysDoses({DateTime? now}) =>
      dosesForDate(now ?? DateTime.now(), now: now);

  /// Rolled-up status for [date] (for the week strip's dots).
  DayStatus statusForDate(DateTime date, {DateTime? now}) {
    final current = now ?? DateTime.now();
    return dayStatusOf(dosesForDate(date, now: current), current);
  }

  /// Number of consecutive fully-completed days, counting backward from
  /// today (or from yesterday if today isn't finished yet, so a streak
  /// isn't broken while today is still in progress). Days with nothing
  /// scheduled don't break or extend the streak.
  int currentStreak({DateTime? now}) {
    final current = now ?? DateTime.now();
    var day = TimeUtils.dateOnly(current);
    if (statusForDate(day, now: current) != DayStatus.complete) {
      day = day.subtract(const Duration(days: 1));
    }
    var streak = 0;
    // Hard cap so an account with medicines added long ago (all "none"
    // before that) can't loop forever.
    for (var i = 0; i < 400; i++) {
      final status = statusForDate(day, now: current);
      if (status == DayStatus.complete) {
        streak++;
      } else if (status != DayStatus.none) {
        break;
      }
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  IntakeLog? _logFor(Medicine m, DateTime slot) {
    for (final log in _logs) {
      final scheduled = log.scheduledFor;
      if (log.medicineId == m.id &&
          scheduled != null &&
          TimeUtils.sameMinute(scheduled, slot)) {
        return log;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------- history

  List<IntakeLog> get visibleLogs {
    final id = _filterMedicineId;
    if (id == null) return _logs;
    return _logs.where((l) => l.medicineId == id).toList();
  }

  /// History grouped by calendar day, newest day first.
  List<MapEntry<DateTime, List<IntakeLog>>> get groupedLogs {
    final groups = <DateTime, List<IntakeLog>>{};
    for (final log in visibleLogs) {
      groups.putIfAbsent(TimeUtils.dateOnly(log.takenAt), () => []).add(log);
    }
    return groups.entries.toList();
  }

  /// medicineId -> name for every medicine that appears in the history.
  Map<String, String> get filterOptions {
    final names = <String, String>{};
    for (final log in _logs) {
      names.putIfAbsent(log.medicineId, () => log.medicineName);
    }
    final entries = names.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    return Map.fromEntries(entries);
  }

  void setFilter(String? medicineId) {
    _filterMedicineId = medicineId;
    notifyListeners();
  }

  // ---------------------------------------------------------------- actions

  /// Records a dose and subtracts it from the stock counter.
  /// Returns the saved log entry (so the UI can offer "Undo"), or null on error.
  Future<IntakeLog?> takeDose(
    Medicine medicine, {
    DateTime? scheduledFor,
  }) async {
    final uid = _uid;
    if (uid == null) return null;

    // Never let the counter go below zero.
    final deducted = math.min(medicine.quantity, medicine.dosePerIntake);
    final log = IntakeLog(
      id: '',
      medicineId: medicine.id,
      medicineName: medicine.name,
      unit: medicine.unit,
      amount: medicine.dosePerIntake,
      status: IntakeStatus.taken,
      takenAt: DateTime.now(),
      scheduledFor: scheduledFor,
      deducted: math.max(0.0, deducted),
    );

    try {
      final saved = await _repo.recordIntake(uid, log);
      final remaining = medicine.quantity - saved.deducted;
      if (remaining <= medicine.lowStockThreshold) {
        _notifications.showLowStock(medicine.copyWith(quantity: remaining));
      }
      return saved;
    } catch (_) {
      _error = 'Could not log this dose. Please try again.';
      notifyListeners();
      return null;
    }
  }

  /// Marks a scheduled dose as skipped (stock is untouched).
  Future<IntakeLog?> skipDose(Medicine medicine, DateTime scheduledFor) async {
    final uid = _uid;
    if (uid == null) return null;
    final log = IntakeLog(
      id: '',
      medicineId: medicine.id,
      medicineName: medicine.name,
      unit: medicine.unit,
      amount: medicine.dosePerIntake,
      status: IntakeStatus.skipped,
      takenAt: DateTime.now(),
      scheduledFor: scheduledFor,
    );
    try {
      return await _repo.recordIntake(uid, log);
    } catch (_) {
      _error = 'Could not skip this dose. Please try again.';
      notifyListeners();
      return null;
    }
  }

  /// Removes a log entry and gives the stock back (if the medicine still exists).
  Future<bool> deleteLog(IntakeLog log) async {
    final uid = _uid;
    if (uid == null) return false;
    final restore =
        log.status == IntakeStatus.taken &&
        _medicines.byId(log.medicineId) != null;
    try {
      await _repo.deleteLog(uid, log, restoreStock: restore);
      return true;
    } catch (_) {
      _error = 'Could not remove this entry. Please try again.';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _medicines.removeListener(notifyListeners);
    _sub?.cancel();
    super.dispose();
  }
}
