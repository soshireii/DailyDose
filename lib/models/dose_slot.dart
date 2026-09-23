import 'intake_log.dart';
import 'medicine.dart';

enum DoseState { upcoming, due, overdue, taken, skipped }

/// Rolled-up status for one calendar day, used by the week strip.
enum DayStatus { none, complete, partial, missed }

/// One scheduled dose on a given day's plan, matched with its log entry (if any).
class DoseSlot {
  const DoseSlot({required this.medicine, required this.scheduledAt, this.log});

  final Medicine medicine;
  final DateTime scheduledAt;
  final IntakeLog? log;

  bool get isDone => log != null;

  DoseState stateAt(DateTime now) {
    final l = log;
    if (l != null) {
      return l.status == IntakeStatus.taken
          ? DoseState.taken
          : DoseState.skipped;
    }
    if (scheduledAt.isAfter(now)) return DoseState.upcoming;
    return now.difference(scheduledAt) > const Duration(hours: 1)
        ? DoseState.overdue
        : DoseState.due;
  }
}

/// Reduces a day's dose slots to one status: complete (all taken), missed
/// (something overdue or skipped), partial (still has time left), or none
/// (nothing scheduled that day).
DayStatus dayStatusOf(List<DoseSlot> slots, DateTime now) {
  if (slots.isEmpty) return DayStatus.none;
  final states = slots.map((s) => s.stateAt(now)).toList();
  if (states.every((s) => s == DoseState.taken)) return DayStatus.complete;
  if (states.any((s) => s == DoseState.overdue || s == DoseState.skipped)) {
    return DayStatus.missed;
  }
  return DayStatus.partial;
}
