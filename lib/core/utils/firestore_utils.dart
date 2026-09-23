import 'dart:async';

/// Firestore write futures only complete once the server acknowledges the
/// write, which never happens while the phone is offline. The write is already
/// saved locally (and will sync later), so after a short wait we stop blocking
/// the UI and treat it as done. Real errors (e.g. permission denied) still
/// throw before the timeout.
Future<void> settleWrite(Future<void> write) async {
  try {
    await write.timeout(const Duration(seconds: 5));
  } on TimeoutException {
    // Queued locally; will be synced when the connection returns.
  }
}
