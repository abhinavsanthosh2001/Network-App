import 'package:dio/dio.dart';
import '../models/test_server.dart';
import 'speed_test_helpers.dart';

/// Executes parallel downloads to saturate bandwidth.
class ParallelDownloadExecutor {
  final Dio _dio;

  ParallelDownloadExecutor(this._dio);

  /// Performs a parallel download test with multiple connections.
  Future<double> execute(
    TestServer server,
    int sizeBytes, {
    required int connectionCount,
  }) async {
    final int sizePerConnection = sizeBytes ~/ connectionCount;
    int totalBytesReceived = 0;
    int warmupBytesReceived = 0;
    
    final stopwatch = Stopwatch();
    bool timingStarted = false;
    bool warmupComplete = false;

    try {
      final downloadTasks = List.generate(connectionCount, (index) async {
        return await _downloadChunk(
          server,
          sizePerConnection,
          stopwatch,
          () => timingStarted,
          (started) => timingStarted = started,
          () => warmupComplete,
          (complete) => warmupComplete = complete,
        );
      });

      final results = await Future.wait(downloadTasks);
      totalBytesReceived = results.fold<int>(0, (sum, r) => sum + (r['total'] as int));
      warmupBytesReceived = results.fold<int>(0, (sum, r) => sum + (r['warmup'] as int));

      if (timingStarted) stopwatch.stop();

      // Exclude warmup period for more accurate measurement
      final totalSeconds = stopwatch.elapsedMilliseconds / 1000.0;
      final measuredSeconds = totalSeconds - 2.0;
      final measuredBytes = totalBytesReceived - warmupBytesReceived;

      if (measuredSeconds > 3.0 && measuredBytes > 0) {
        return SpeedTestHelpers.calculateSpeed(measuredBytes, measuredSeconds);
      } else {
        return SpeedTestHelpers.calculateSpeed(totalBytesReceived, totalSeconds);
      }
    } catch (e) {
      if (timingStarted && stopwatch.isRunning) stopwatch.stop();
      rethrow;
    }
  }

  Future<Map<String, int>> _downloadChunk(
    TestServer server,
    int sizeBytes,
    Stopwatch stopwatch,
    bool Function() isTimingStarted,
    void Function(bool) setTimingStarted,
    bool Function() isWarmupComplete,
    void Function(bool) setWarmupComplete,
  ) async {
    final url = server.getDownloadUrl(sizeBytes);
    int connectionBytes = 0;
    int connectionWarmupBytes = 0;

    try {
      final response = await _dio.get<ResponseBody>(
        url,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: Duration(milliseconds: 120000),
          headers: {
            'Accept-Encoding': 'identity',
            'Cache-Control': 'no-cache',
          },
        ),
      );

      await for (final chunk in response.data!.stream) {
        if (!isTimingStarted()) {
          stopwatch.start();
          setTimingStarted(true);
        }

        connectionBytes += chunk.length;

        // Track warmup bytes (first 2 seconds)
        if (!isWarmupComplete() && stopwatch.elapsed.inSeconds < 2) {
          connectionWarmupBytes += chunk.length;
        } else if (!isWarmupComplete()) {
          setWarmupComplete(true);
        }
      }
    } catch (e) {
      // Connection failed, but continue with others
    }

    return {'total': connectionBytes, 'warmup': connectionWarmupBytes};
  }
}
