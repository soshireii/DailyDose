import 'package:cloud_firestore/cloud_firestore.dart';

enum IntakeStatus { taken, skipped }

/// One entry in the intake history. Medicine name and unit are copied in so
/// the history stays readable even after a medicine is deleted.
class IntakeLog {
  const IntakeLog({
    required this.id,
    required this.medicineId,
    required this.medicineName,
    required this.unit,
    required this.amount,
    required this.status,
    required this.takenAt,
    this.scheduledFor,
    this.deducted = 0,
  });

  final String id;
  final String medicineId;
  final String medicineName;
  final String unit;

  /// Dose that was taken (or would have been taken if skipped).
  final double amount;
  final IntakeStatus status;

  /// When the user pressed "Take"/"Skip".
  final DateTime takenAt;

  /// The schedule slot this entry answers. Null for "take now" entries.
  final DateTime? scheduledFor;

  /// How much stock was actually removed from inventory (used by undo).
  final double deducted;

  IntakeLog copyWith({String? id}) => IntakeLog(
        id: id ?? this.id,
        medicineId: medicineId,
        medicineName: medicineName,
        unit: unit,
        amount: amount,
        status: status,
        takenAt: takenAt,
        scheduledFor: scheduledFor,
        deducted: deducted,
      );

  Map<String, dynamic> toMap() => {
        'medicineId': medicineId,
        'medicineName': medicineName,
        'unit': unit,
        'amount': amount,
        'status': status.name,
        'takenAt': Timestamp.fromDate(takenAt),
        'scheduledFor':
            scheduledFor == null ? null : Timestamp.fromDate(scheduledFor!),
        'deducted': deducted,
      };

  factory IntakeLog.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return IntakeLog(
      id: doc.id,
      medicineId: d['medicineId'] as String? ?? '',
      medicineName: d['medicineName'] as String? ?? 'Unknown medicine',
      unit: d['unit'] as String? ?? 'tablet',
      amount: (d['amount'] as num?)?.toDouble() ?? 0,
      status: IntakeStatus.values.firstWhere(
        (s) => s.name == d['status'],
        orElse: () => IntakeStatus.taken,
      ),
      takenAt: (d['takenAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      scheduledFor: (d['scheduledFor'] as Timestamp?)?.toDate(),
      deducted: (d['deducted'] as num?)?.toDouble() ?? 0,
    );
  }
}
