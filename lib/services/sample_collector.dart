import '../models/test_server.dart';
import '../models/speed_test_config.dart';
import 'speed_test_helpers.dart';

/// Collects multiple test samples with adaptive sizing and retry logic.
class SampleCollector {
  final Future<double> Function(TestServer, int, {int connectionCount}) _performSample;

  SampleCollector(this._performSample);

  /// Collects samples with progressive sizing and adaptive connections.
  Future<List<double>> collect(
    TestServer server,
    int maxSamples, {
    required int minSamples,
    required int startSize,
    required int maxSize,
    required double varianceThreshold,
  }) async {
    final List<double> successfulSamples = [];
    int currentSize = startSize;
    int currentConnectionCount = 4;

    for (int i = 0; i < maxSamples; i++) {
      final sampleSpeed = await _retrySample(
        server,
        currentSize,
        currentConnectionCount,
      );

      if (sampleSpeed != null) {
        successfulSamples.add(sampleSpeed);

        // Adapt for next sample
        if (i < maxSamples - 1) {
          currentSize = SpeedTestHelpers.calculateNextSize(
            sampleSpeed,
            currentSize,
            maxSize,
          );
          currentConnectionCount = SpeedTestHelpers.getOptimalConnectionCount(sampleSpeed);
        }
      }

      // Check if we can stop early
      if (i >= minSamples - 1) {
        if (i >= maxSamples - 1) break;
        if (!SpeedTestHelpers.needsAdditionalSamples(
          successfulSamples,
          varianceThreshold,
        )) break;
      }
    }

    return successfulSamples;
  }

  Future<double?> _retrySample(
    TestServer server,
    int size,
    int connectionCount,
  ) async {
    for (int retry = 0; retry <= SpeedTestConfig.maxRetries; retry++) {
      try {
        return await _performSample(
          server,
          size,
          connectionCount: connectionCount,
        );
      } catch (e) {
        if (retry < SpeedTestConfig.maxRetries) {
          await Future.delayed(
            Duration(milliseconds: SpeedTestConfig.retryDelay),
          );
        }
      }
    }
    return null;
  }
}
