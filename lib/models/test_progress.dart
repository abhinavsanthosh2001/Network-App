/// Represents the current phase of a speed test.
enum TestPhase {
  serverSelection,
  latency,
  download,
  upload,
  complete,
}

/// Represents real-time progress during test execution.
class TestProgress {
  final TestPhase phase;
  final double? currentSpeed;
  final int? currentLatency;
  final int elapsedSeconds;
  final int completedSamples;
  final int totalSamples;

  TestProgress({
    required this.phase,
    this.currentSpeed,
    this.currentLatency,
    required this.elapsedSeconds,
    required this.completedSamples,
    required this.totalSamples,
  });

  /// Returns the progress as a percentage (0.0 to 1.0).
  double get progressPercentage =>
      totalSamples > 0 ? (completedSamples / totalSamples) : 0.0;

  /// Returns a human-readable description of the current phase.
  String get phaseDescription {
    switch (phase) {
      case TestPhase.serverSelection:
        return 'Selecting optimal server...';
      case TestPhase.latency:
        return 'Measuring latency...';
      case TestPhase.download:
        return 'Testing download speed...';
      case TestPhase.upload:
        return 'Testing upload speed...';
      case TestPhase.complete:
        return 'Test complete';
    }
  }
}
