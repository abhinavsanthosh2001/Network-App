/// Types of errors that can occur during speed testing.
enum SpeedTestErrorType {
  noConnectivity,
  allServersFailed,
  testAborted,
  timeout,
  cancelled,
  persistenceError,
}

/// Represents an error that occurred during speed testing.
class SpeedTestError implements Exception {
  final SpeedTestErrorType type;
  final String message;
  final String? suggestion;
  final bool isRetryable;

  SpeedTestError({
    required this.type,
    required this.message,
    this.suggestion,
    this.isRetryable = false,
  });

  @override
  String toString() => message;
}
