import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/firestore_utils.dart';
import '../models/intake_log.dart';

/// Firestore layout: users/{uid}/intake_logs/{logId}
///
/// Logging an intake and updating the medicine's remaining quantity happen in
/// one atomic batch, so the log and the counter can never disagree. Batches
/// (unlike transactions) also work while offline.
class IntakeRepository {
  IntakeRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const int logLimit = 500;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  Stream<List<IntakeLog>> watchLogs(String uid) {
    return _user(uid)
        .collection('intake_logs')
        .orderBy('takenAt', descending: true)
        .limit(logLimit)
        .snapshots()
        .map((s) => s.docs.map(IntakeLog.fromDoc).toList());
  }

  /// Saves the log and subtracts [IntakeLog.deducted] from the medicine stock.
  Future<IntakeLog> recordIntake(String uid, IntakeLog log) async {
    final logRef = _user(uid).collection('intake_logs').doc();
    final saved = log.copyWith(id: logRef.id);

    final batch = _db.batch();
    batch.set(logRef, saved.toMap());
    if (saved.deducted > 0) {
      batch.update(
        _user(uid).collection('medicines').doc(saved.medicineId),
        {'quantity': FieldValue.increment(-saved.deducted)},
      );
    }
    await settleWrite(batch.commit());
    return saved;
  }

  /// Removes a log entry and, when [restoreStock] is true, puts the deducted
  /// amount back into the medicine's stock.
  Future<void> deleteLog(
    String uid,
    IntakeLog log, {
    required bool restoreStock,
  }) async {
    final batch = _db.batch();
    batch.delete(_user(uid).collection('intake_logs').doc(log.id));
    if (restoreStock && log.deducted > 0) {
      batch.update(
        _user(uid).collection('medicines').doc(log.medicineId),
        {'quantity': FieldValue.increment(log.deducted)},
      );
    }
    await settleWrite(batch.commit());
  }
}
