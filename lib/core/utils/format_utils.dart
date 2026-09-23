import '../constants.dart';

/// 2.0 -> "2", 0.5 -> "0.5", 1.25 -> "1.25"
String formatAmount(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// "2 tablets", "1 capsule", "5 ml"
String formatDose(double amount, String unit) =>
    '${formatAmount(amount)} ${Units.label(unit, amount)}';

/// Index 0 = Monday (DateTime.monday == 1).
const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String describeDays(List<int> days) {
  if (days.length == 7) return 'Every day';
  final sorted = [...days]..sort();
  return sorted.map((d) => weekdayShort[d - 1]).join(', ');
}
