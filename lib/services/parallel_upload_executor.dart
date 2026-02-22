import 'package:dio/dio.dart';
import '../models/test_server.dart';
import 'speed_test_helpers.dart';

/// Executes parallel uploads to saturate bandwidth.
class ParallelUploadExecutor {
  final Dio _dio;

  ParallelUploadExecutor(this._dio);

  /// Performs a parallel upload test with multiple connections.
  Future<double> execute(
    TestServer server,
    int sizeBytes, {
    required int connectionCount,
  }) async {
    final int sizePerConnection = sizeBytes ~/ connectionCount;
    final stopwatch = Stopwatch();
    bool timingStarted = false;
    int totalBytesSent = 0;

    try {
      final uploadTasks = List.generate(connectionCount, (index) async {
        return await _uploadChunk(
          server,
          sizePerConnection,
          stopwatch,
          () => timingStarted,
          (started) => timingStarted = started,
        );
      });

      final results = await Future.wait(uploadTasks);
      totalBytesSent = results.reduce((a, b) => a + b);

      if (timingStarted) stopwatch.stop();

      final seconds = stopwatch.elapsedMilliseconds / 1000.0;
      return SpeedTestHelpers.calculateSpeed(totalBytesSent, seconds);
    } catch (e) {
      if (stopwatch.isRunning) stopwatch.stop();
      rethrow;
    }
  }

  Future<int> _uploadChunk(
    TestServer server,
    int sizeBytes,
    Stopwatch stopwatch,
    bool Function() isTimingStarted,
    void Function(bool) setTimingStarted,
  ) async {
    final url = server.getUploadUrl();
    final random = List.generate(sizeBytes, (i) => i % 256);
    int connectionBytes = 0;

    try {
      await _dio.put(
        url,
        data: Stream.fromIterable([random]),
        options: Options(
          contentType: 'application/octet-stream',
          headers: {'Content-Length': sizeBytes.toString()},
          sendTimeout: Duration(milliseconds: 120000),
        ),
        onSendProgress: (sent, total) {
          if (!isTimingStarted() && sent > 0) {
            stopwatch.start();
            setTimingStarted(true);
          }
          connectionBytes = sent;
        },
      );
    } catch (e) {
      // Connection failed, but continue with others
    }

    return connectionBytes > 0 ? connectionBytes : sizeBytes;
  }
}
