import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../models/medicine.dart';

/// State of the add/edit form that isn't a plain text field: unit, reminder
/// times, weekdays, the reminders switch and the photo.
class MedicineFormViewModel extends ChangeNotifier {
  MedicineFormViewModel({Medicine? initial})
    : initial = initial,
      unit = initial?.unit ?? Units.all.first,
      times = [...?initial?.scheduleTimes],
      days = {
        ...(initial?.days ?? const [1, 2, 3, 4, 5, 6, 7]),
      },
      remindersEnabled = initial?.remindersEnabled ?? true,
      imageBase64 = initial?.imageBase64 ?? '';

  static const int maxTimes = 6;

  /// The medicine being edited, or a seed with a blank id when duplicating.
  /// Null when adding a brand-new medicine from scratch.
  final Medicine? initial;

  String unit;
  final List<String> times;
  final Set<int> days;
  bool remindersEnabled;
  String imageBase64;

  /// True only when editing a medicine that already exists (has an id).
  /// A duplicated medicine is passed in as [initial] too, but with an empty
  /// id, so it's treated as "adding new" here.
  bool get isEditing => initial != null && initial!.id.isNotEmpty;

  /// Null when the schedule is valid.
  String? get scheduleError {
    if (times.isNotEmpty && days.isEmpty) {
      return 'Pick at least one day for the schedule.';
    }
    return null;
  }

  void setUnit(String value) {
    unit = value;
    notifyListeners();
  }

  /// Returns false if the time is a duplicate or the limit is reached.
  bool addTime(String hhmm) {
    if (times.contains(hhmm) || times.length >= maxTimes) return false;
    times
      ..add(hhmm)
      ..sort();
    notifyListeners();
    return true;
  }

  void removeTime(String hhmm) {
    times.remove(hhmm);
    notifyListeners();
  }

  void toggleDay(int weekday, bool selected) {
    selected ? days.add(weekday) : days.remove(weekday);
    notifyListeners();
  }

  void setRemindersEnabled(bool value) {
    remindersEnabled = value;
    notifyListeners();
  }

  void setImage(String base64) {
    imageBase64 = base64;
    notifyListeners();
  }

  void clearImage() {
    imageBase64 = '';
    notifyListeners();
  }

  Medicine buildMedicine({
    required String name,
    required String strength,
    required double dose,
    required double quantity,
    required double lowStock,
    required String notes,
  }) {
    final sortedDays = days.toList()..sort();
    final existing = initial;
    if (existing != null) {
      return existing.copyWith(
        name: name,
        strength: strength,
        unit: unit,
        dosePerIntake: dose,
        quantity: quantity,
        lowStockThreshold: lowStock,
        scheduleTimes: List.of(times),
        days: sortedDays,
        remindersEnabled: remindersEnabled && times.isNotEmpty,
        notes: notes,
        imageBase64: imageBase64,
      );
    }
    return Medicine(
      id: '',
      name: name,
      strength: strength,
      unit: unit,
      dosePerIntake: dose,
      quantity: quantity,
      lowStockThreshold: lowStock,
      scheduleTimes: List.of(times),
      days: sortedDays,
      remindersEnabled: remindersEnabled && times.isNotEmpty,
      notes: notes,
      imageBase64: imageBase64,
      notificationBase: Random().nextInt(1000000) + 1,
      createdAt: DateTime.now(),
    );
  }
}
