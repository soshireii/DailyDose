import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Reminder times are stored as "HH:mm" strings so they stay independent of
/// time zones and of Flutter's TimeOfDay class.
class TimeUtils {
  static String encode(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static TimeOfDay decode(String value) {
    final parts = value.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  /// The given "HH:mm" on a specific calendar day.
  static DateTime on(DateTime day, String hhmm) {
    final t = decode(hhmm);
    return DateTime(day.year, day.month, day.day, t.hour, t.minute);
  }

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool sameMinute(DateTime a, DateTime b) =>
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day &&
      a.hour == b.hour &&
      a.minute == b.minute;

  /// Uses the device's 12h/24h preference.
  static String format(BuildContext context, DateTime d) =>
      TimeOfDay.fromDateTime(d).format(context);

  static String formatHm(BuildContext context, String hhmm) =>
      decode(hhmm).format(context);

  static String dayLabel(DateTime day, DateTime now) {
    final today = dateOnly(now);
    final diff = today.difference(dateOnly(day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEEE, MMM d').format(day);
  }
}
