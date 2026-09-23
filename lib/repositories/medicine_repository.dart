import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/firestore_utils.dart';
import '../models/medicine.dart';

/// Firestore layout: users/{uid}/medicines/{medicineId}
class MedicineRepository {
  MedicineRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('medicines');

  Stream<List<Medicine>> watchMedicines(String uid) {
    return _col(uid).snapshots().map((snapshot) {
      final list = snapshot.docs.map(Medicine.fromDoc).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  /// Creates the medicine when [medicine.id] is empty, otherwise overwrites it.
  Future<Medicine> save(String uid, Medicine medicine) async {
    if (medicine.id.isEmpty) {
      final ref = _col(uid).doc();
      final saved = medicine.copyWith(id: ref.id);
      await settleWrite(ref.set(saved.toMap()));
      return saved;
    }
    await settleWrite(_col(uid).doc(medicine.id).set(medicine.toMap()));
    return medicine;
  }

  Future<void> delete(String uid, String medicineId) =>
      settleWrite(_col(uid).doc(medicineId).delete());

  /// Adds [amount] to the stock (use a negative number to remove).
  Future<void> adjustQuantity(String uid, String medicineId, double amount) {
    return settleWrite(
      _col(uid).doc(medicineId).update({'quantity': FieldValue.increment(amount)}),
    );
  }
}
