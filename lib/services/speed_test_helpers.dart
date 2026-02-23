import '../models/speed_test_config.dart';

/// Helper utilities for speed test calculations and adaptive sizing.
class SpeedTestHelpers {
  /// Calculates the median of a list of numeric values.
  static double calculateMedian(List<num> values) {
    if (values.isEmpty) {
      throw ArgumentError('Cannot calculate median of empty list');
    }

    if (values.length == 1) {
      return values[0].toDouble();
    }

    final sorted = List<num>.from(values)..sort();
    final middle = sorted.length ~/ 2;

    if (sorted.length.isOdd) {
      return sorted[middle].toDouble();
    } else {
      return (sorted[middle - 1] + sorted[middle]) / 2;
    }
  }

  /// Determines if additional samples are needed based on variance.
  static bool needsAdditionalSamples(List<double> samples, double threshold) {
    if (samples.length < 2) return false;

    final mean = samples.reduce((a, b) => a + b) / samples.length;
    double maxDeviation = 0.0;
    
    for (final sample in samples) {
      final deviation = (sample - mean).abs();
      if (deviation > maxDeviation) {
        maxDeviation = deviation;
      }
    }

    final variance = maxDeviation / mean;
    return variance > threshold;
  }

  /// Calculates network speed in Mbps from bytes transferred and elapsed time.
  static double calculateSpeed(int bytes, double seconds) {
    return (bytes * 8) / (seconds * 1000000);
  }

  /// Calculates the next test file size for progressive sizing.
  static int calculateNextSize(double currentSpeed, int currentSize, int maxSize) {
    // Use shorter target for slow connections to keep total test time down
    final targetSeconds = currentSpeed < 5
        ? SpeedTestConfig.slowTargetTestDuration
        : SpeedTestConfig.targetTestDuration;
    final bytesPerSecond = (currentSpeed * 1000000) / 8;
    final idealSize = (bytesPerSecond * targetSeconds).toInt();

    // For very slow connections (<5 Mbps), cap aggressively
    if (currentSpeed < 5) {
      const slowMaxSize = 2 * 1024 * 1024; // 2MB cap
      final nextSize = idealSize > currentSize ? idealSize : currentSize;
      return nextSize > slowMaxSize ? slowMaxSize : nextSize;
    }

    // For slow connections (5-20 Mbps), use moderate scaling
    if (currentSpeed < 20) {
      const moderateMaxSize = 20 * 1024 * 1024;
      final nextSize = idealSize > currentSize * 2 ? idealSize : currentSize * 2;
      return nextSize > moderateMaxSize ? moderateMaxSize : nextSize;
    }

    // For high-speed connections, use aggressive scaling
    int minNextSize;
    if (currentSpeed > 100) {
      minNextSize = currentSize * 8;
    } else if (currentSpeed > 50) {
      minNextSize = currentSize * 5;
    } else {
      minNextSize = currentSize * 3;
    }

    final nextSize = idealSize > minNextSize ? idealSize : minNextSize;
    return nextSize > maxSize ? maxSize : nextSize;
  }

  /// Determines the optimal number of parallel connections based on speed.
  static int getOptimalConnectionCount(double speedMbps) {
    if (speedMbps < 5) return 2;
    if (speedMbps < 20) return 4;
    if (speedMbps < 50) return 6;
    if (speedMbps < 100) return 10;
    return 16;
  }
}
