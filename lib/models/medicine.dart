import 'package:cloud_firestore/cloud_firestore.dart';

/// A medicine the user takes: what it is, how much they have left, and when
/// they should take it.
class Medicine {
  const Medicine({
    required this.id,
    required this.name,
    this.strength = '',
    required this.unit,
    required this.dosePerIntake,
    required this.quantity,
    required this.lowStockThreshold,
    this.scheduleTimes = const [],
    this.days = const [1, 2, 3, 4, 5, 6, 7],
    this.remindersEnabled = true,
    this.notes = '',
    this.imageBase64 = '',
    required this.notificationBase,
    required this.createdAt,
  });

  final String id;
  final String name;

  /// Free text such as "500 mg".
  final String strength;

  /// tablet, capsule, ml, ...
  final String unit;

  /// How much is consumed each time (supports halves, e.g. 0.5 tablet).
  final double dosePerIntake;

  /// Amount remaining in stock, in [unit]s.
  final double quantity;
  final double lowStockThreshold;

  /// "HH:mm" strings. Empty means "as needed".
  final List<String> scheduleTimes;

  /// DateTime weekday numbers, 1 = Monday ... 7 = Sunday.
  final List<int> days;
  final bool remindersEnabled;
  final String notes;

  /// Base64-encoded photo of the medicine/pill, picked from the device.
  /// Empty means no photo was set. Kept small (see the form's size check)
  /// to stay well under Firestore's 1 MiB document limit.
  final String imageBase64;

  /// Base number used to derive unique local-notification ids.
  final int notificationBase;
  final DateTime createdAt;

  bool get hasSchedule => scheduleTimes.isNotEmpty;
  bool get hasImage => imageBase64.isNotEmpty;
  bool get isLowStock => quantity <= lowStockThreshold;
  bool get isOutOfStock => quantity <= 0;

  /// Rough number of days the current stock will last, or null if as-needed.
  double? get daysRemaining {
    if (!hasSchedule || days.isEmpty || dosePerIntake <= 0) return null;
    final perWeek = dosePerIntake * scheduleTimes.length * days.length;
    if (perWeek <= 0) return null;
    return quantity / (perWeek / 7);
  }

  Medicine copyWith({
    String? id,
    String? name,
    String? strength,
    String? unit,
    double? dosePerIntake,
    double? quantity,
    double? lowStockThreshold,
    List<String>? scheduleTimes,
    List<int>? days,
    bool? remindersEnabled,
    String? notes,
    String? imageBase64,
    int? notificationBase,
    DateTime? createdAt,
  }) {
    return Medicine(
      id: id ?? this.id,
      name: name ?? this.name,
      strength: strength ?? this.strength,
      unit: unit ?? this.unit,
      dosePerIntake: dosePerIntake ?? this.dosePerIntake,
      quantity: quantity ?? this.quantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      scheduleTimes: scheduleTimes ?? this.scheduleTimes,
      days: days ?? this.days,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      notes: notes ?? this.notes,
      imageBase64: imageBase64 ?? this.imageBase64,
      notificationBase: notificationBase ?? this.notificationBase,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'strength': strength,
    'unit': unit,
    'dosePerIntake': dosePerIntake,
    'quantity': quantity,
    'lowStockThreshold': lowStockThreshold,
    'scheduleTimes': scheduleTimes,
    'days': days,
    'remindersEnabled': remindersEnabled,
    'notes': notes,
    'imageBase64': imageBase64,
    'notificationBase': notificationBase,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory Medicine.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Medicine(
      id: doc.id,
      name: d['name'] as String? ?? '',
      strength: d['strength'] as String? ?? '',
      unit: d['unit'] as String? ?? 'tablet',
      dosePerIntake: (d['dosePerIntake'] as num?)?.toDouble() ?? 1,
      quantity: (d['quantity'] as num?)?.toDouble() ?? 0,
      lowStockThreshold: (d['lowStockThreshold'] as num?)?.toDouble() ?? 0,
      scheduleTimes: List<String>.from(d['scheduleTimes'] as List? ?? const []),
      days: List<int>.from(d['days'] as List? ?? const [1, 2, 3, 4, 5, 6, 7]),
      remindersEnabled: d['remindersEnabled'] as bool? ?? true,
      notes: d['notes'] as String? ?? '',
      imageBase64: d['imageBase64'] as String? ?? '',
      notificationBase: (d['notificationBase'] as num?)?.toInt() ?? 1,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
