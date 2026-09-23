import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/dose_slot.dart';

/// A 7-day (Sun-Sat) strip. Each day is a circle showing the date, with a
/// colored ring + dot underneath: green = every dose taken, yellow = day
/// still has time left, red = something was missed, gray = nothing scheduled.
/// Tap a day to view its plan; the arrows page a week at a time.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.selectedDate,
    required this.onSelect,
    required this.statusFor,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelect;
  final DayStatus Function(DateTime day) statusFor;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  DateTime _startOfWeek(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday % 7)); // Sunday start
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _monthLabel(DateTime start) {
    final end = start.add(const Duration(days: 6));
    if (start.month == end.month) return '${_months[start.month - 1]} ${start.year}';
    return '${_months[start.month - 1]} - ${_months[end.month - 1]} ${end.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = _startOfWeek(selectedDate);
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous week',
              icon: const Icon(Icons.chevron_left),
              onPressed: () =>
                  onSelect(selectedDate.subtract(const Duration(days: 7))),
            ),
            Expanded(
              child: Text(
                _monthLabel(start),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next week',
              icon: const Icon(Icons.chevron_right),
              onPressed: () => onSelect(selectedDate.add(const Duration(days: 7))),
            ),
          ],
        ),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: _DayCell(
                  date: start.add(Duration(days: i)),
                  selected: _sameDay(start.add(Duration(days: i)), selectedDate),
                  isToday: _sameDay(start.add(Duration(days: i)), todayOnly),
                  status: statusFor(start.add(Duration(days: i))),
                  onTap: () => onSelect(start.add(Duration(days: i))),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.selected,
    required this.isToday,
    required this.status,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final bool isToday;
  final DayStatus status;
  final VoidCallback onTap;

  static const _weekdayLetters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  Color _statusColor() {
    switch (status) {
      case DayStatus.complete:
        return AppColors.statusTaken;
      case DayStatus.missed:
        return AppColors.statusMissed;
      case DayStatus.partial:
        return AppColors.statusPending;
      case DayStatus.none:
        return AppColors.neutralGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dotColor = _statusColor();
    final hasStatus = status != DayStatus.none;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _weekdayLetters[date.weekday % 7],
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.secondary : Colors.transparent,
                border: Border.all(
                  color: hasStatus ? dotColor : scheme.outlineVariant,
                  width: 2,
                ),
              ),
              child: Text(
                '${date.day}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : (isToday ? AppColors.secondary : scheme.onSurface),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasStatus ? dotColor : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}