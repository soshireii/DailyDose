import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/medicine.dart';
import '../repositories/medicine_repository.dart';
import '../services/notification_service.dart';

/// Holds the user's medicine list, and keeps scheduled reminders in step with it.
class MedicineViewModel extends ChangeNotifier {
  MedicineViewModel(this._repo, this._notifications);

  final MedicineRepository _repo;
  final NotificationService _notifications;

  String? _uid;
  StreamSubscription<List<Medicine>>? _sub;
  List<Medicine> _medicines = const [];
  bool _loading = false;
  String? _error;
  String _query = '';
  String _lastScheduleSignature = '';

  List<Medicine> get medicines => _medicines;
  bool get isLoading => _loading;
  String? get error => _error;

  /// Medicines matching the search box.
  List<Medicine> get filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _medicines;
    return _medicines
        .where(
          (m) =>
              m.name.toLowerCase().contains(q) ||
              m.strength.toLowerCase().contains(q),
        )
        .toList();
  }

  List<Medicine> get lowStock => _medicines.where((m) => m.isLowStock).toList();

  Medicine? byId(String id) {
    for (final m in _medicines) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Called by the ProxyProvider whenever the signed-in user changes.
  /// Deliberately does not notify: it runs during the widget build phase.
  void bindUser(String? uid) {
    if (uid == _uid) return;
    _uid = uid;
    _sub?.cancel();
    _sub = null;
    _medicines = const [];
    _lastScheduleSignature = '';
    _error = null;
    _query = '';

    if (uid == null) {
      _loading = false;
      _notifications.cancelAll();
      return;
    }

    _loading = true;
    _sub = _repo
        .watchMedicines(uid)
        .listen(
          _onData,
          onError: (Object _) {
            _loading = false;
            _error = 'Could not load your medicines. Check your connection.';
            notifyListeners();
          },
        );
    _notifications.requestNotificationPermission();
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> saveMedicine(Medicine medicine) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await _repo.save(uid, medicine);
      if (medicine.remindersEnabled && medicine.hasSchedule) {
        await _notifications.ensureExactAlarmPermission();
      }
      return true;
    } catch (_) {
      _error = 'Could not save this medicine. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteMedicine(Medicine medicine) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await _repo.delete(uid, medicine.id);
      return true;
    } catch (_) {
      _error = 'Could not delete ${medicine.name}. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Adds newly bought stock to the counter.
  Future<bool> refill(Medicine medicine, double amount) async {
    final uid = _uid;
    if (uid == null || amount <= 0) return false;
    try {
      await _repo.adjustQuantity(uid, medicine.id, amount);
      return true;
    } catch (_) {
      _error = 'Could not update the stock. Please try again.';
      notifyListeners();
      return false;
    }
  }

  void _onData(List<Medicine> list) {
    _medicines = list;
    _loading = false;
    _error = null;
    notifyListeners();
    _syncReminders(list);
  }

  /// Only touches the notification schedule when something that affects it
  /// changed. Quantity (rounded to whole units) is included because the
  /// refill reminder's projected "run out" date depends on it; the rounding
  /// keeps a single dose deduction from re-triggering a full resync.
  void _syncReminders(List<Medicine> list) {
    final signature = list
        .map(
          (m) => [
            m.id,
            m.name,
            m.strength,
            m.unit,
            m.dosePerIntake,
            m.remindersEnabled,
            m.notificationBase,
            m.scheduleTimes.join(','),
            m.days.join(','),
            m.quantity.round(),
          ].join('|'),
        )
        .join(';');
    if (signature == _lastScheduleSignature) return;
    _lastScheduleSignature = signature;
    _notifications.syncAll(list);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
