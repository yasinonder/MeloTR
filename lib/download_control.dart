import 'dart:async';

/// Signals that the user explicitly aborted a download/conversion.
/// It must not be mistaken for a connection or media failure.
class DownloadCancelled implements Exception {
  const DownloadCancelled();
  @override
  String toString() => 'İndirme kullanıcı tarafından iptal edildi.';
}

/// A per-download control; cancel closes the currently active operation.
/// Saving a verified MP3 to Android MediaStore is a non-cancellable final step.
class DownloadControl {
  final Completer<void> _cancelledSignal = Completer<void>();
  Future<void> Function()? _stop;
  Future<void>? _cancellation;
  bool _cancelled = false;
  bool _finalizing = false;

  bool get isCancelled => _cancelled;
  bool get isFinalizing => _finalizing;

  void check() {
    if (_cancelled) throw const DownloadCancelled();
  }

  void registerStop(Future<void> Function()? stop) {
    _stop = stop;
    if (_cancelled && stop != null) unawaited(stop());
  }

  Future<void> cancel() {
    if (_finalizing) return Future<void>.value();
    if (_cancellation != null) return _cancellation!;
    _cancelled = true;
    _cancellation = _performCancel();
    return _cancellation!;
  }

  Future<void> _performCancel() async {
    try {
      final stop = _stop;
      if (stop != null) await stop().timeout(const Duration(seconds:8));
    } catch (_) {
      // The signal is still delivered, even if a network cleanup misbehaves.
    } finally {
      if (!_cancelledSignal.isCompleted) _cancelledSignal.complete();
    }
  }

  Future<T> untilCancelled<T>(Future<T> task) {
    check();
    return Future.any<T>([
      task,
      _cancelledSignal.future.then<T>(
        (_) => throw const DownloadCancelled(),
      ),
    ]);
  }

  void startFinalizing() {
    check();
    _finalizing = true;
    _stop = null;
  }
}
