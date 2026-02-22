/// Exception thrown when an operation is cancelled.
class CancelledException implements Exception {
  @override
  String toString() => 'Operation was cancelled';
}

/// Token used to cancel ongoing speed test operations.
class CancellationToken {
  bool _isCancelled = false;

  /// Returns true if cancellation has been requested.
  bool get isCancelled => _isCancelled;

  /// Requests cancellation of the operation.
  void cancel() {
    _isCancelled = true;
  }

  /// Throws [CancelledException] if cancellation has been requested.
  void throwIfCancelled() {
    if (_isCancelled) {
      throw CancelledException();
    }
  }
}
