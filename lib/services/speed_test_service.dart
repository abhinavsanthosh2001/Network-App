import 'dart:async';
import 'package:dio/dio.dart';
import '../models/test_server.dart';
import '../models/speed_test_config.dart';
import '../models/test_progress.dart';
import '../models/cancellation_token.dart';
import '../models/speed_test_result.dart';
import 'speed_test_helpers.dart';
import 'parallel_download_executor.dart';
import 'parallel_upload_executor.dart';
import 'sample_collector.dart';

class SpeedTestService {
  late final Dio _dio;
  late final List<TestServer> testServers;
  late final ParallelDownloadExecutor _downloadExecutor;
  late final ParallelUploadExecutor _uploadExecutor;

  SpeedTestService() {
    _dio = Dio(BaseOptions(
      connectTimeout: Duration(milliseconds: SpeedTestConfig.serverSelectionTimeout),
      receiveTimeout: Duration(milliseconds: SpeedTestConfig.serverSelectionTimeout),
      sendTimeout: Duration(milliseconds: SpeedTestConfig.serverSelectionTimeout),
      headers: {
        'Accept-Encoding': 'identity',
        'Cache-Control': 'no-cache',
      },
    ));

    _downloadExecutor = ParallelDownloadExecutor(_dio);
    _uploadExecutor = ParallelUploadExecutor(_dio);

    testServers = [
      TestServer(
        name: 'Cloudflare CDN',
        baseUrl: 'https://speed.cloudflare.com',
        downloadEndpoint: '/__down?bytes={size}',
        uploadEndpoint: '/__up',
        pingEndpoint: '/__down?bytes=1000',
      ),
      TestServer(
        name: 'Cachefly CDN',
        baseUrl: 'http://cachefly.cachefly.net',
        downloadEndpoint: '/100mb.test',
        uploadEndpoint: '/upload',
        pingEndpoint: '/10mb.test',
      ),
      TestServer(
        name: 'Proof OVH CDN',
        baseUrl: 'http://proof.ovh.net/files',
        downloadEndpoint: '/100Mb.dat',
        uploadEndpoint: '/upload.php',
        pingEndpoint: '/1Mb.dat',
      ),
    ];
  }

  // Server validation and selection
  Future<bool> validateServer(TestServer server) async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: Duration(milliseconds: SpeedTestConfig.serverSelectionTimeout),
        receiveTimeout: Duration(milliseconds: SpeedTestConfig.serverSelectionTimeout),
      ));
      await dio.get(server.getPingUrl());
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<int> measureServerLatency(TestServer server) async {
    final stopwatch = Stopwatch()..start();
    try {
      await _dio.get(server.getPingUrl());
      stopwatch.stop();
      return stopwatch.elapsedMilliseconds;
    } catch (e) {
      stopwatch.stop();
      rethrow;
    }
  }

  Future<TestServer> selectOptimalServer() async {
    final Map<TestServer, int> serverLatencies = {};

    for (final server in testServers) {
      try {
        if (await validateServer(server)) {
          serverLatencies[server] = await measureServerLatency(server);
        }
      } catch (e) {
        continue;
      }
    }

    if (serverLatencies.isEmpty) {
      throw Exception('All test servers failed to respond');
    }

    final preferredServers = serverLatencies.entries
        .where((e) => e.value < SpeedTestConfig.maxLatencyForPreference);

    if (preferredServers.isNotEmpty) {
      return preferredServers.reduce((a, b) => a.value < b.value ? a : b).key;
    }

    return serverLatencies.entries.reduce((a, b) => a.value < b.value ? a : b).key;
  }

  // Latency measurement
  Future<List<int>> performLatencySamples(
    TestServer server,
    int count, {
    Function(int)? onProgress,
  }) async {
    final List<int> successfulSamples = [];

    for (int i = 0; i < count; i++) {
      for (int retry = 0; retry <= SpeedTestConfig.maxRetries; retry++) {
        try {
          successfulSamples.add(await measureServerLatency(server));
          onProgress?.call(successfulSamples.length);
          break;
        } catch (e) {
          if (retry < SpeedTestConfig.maxRetries) {
            await Future.delayed(const Duration(milliseconds: SpeedTestConfig.retryDelay));
          }
        }
      }
    }

    return successfulSamples;
  }

  Future<Map<String, dynamic>> measureLatency({
    TestServer? server,
    int samples = SpeedTestConfig.latencySamples,
    Function(int)? onProgress,
  }) async {
    final testServer = server ?? await selectOptimalServer();
    final latencySamples = await performLatencySamples(
      testServer,
      samples,
      onProgress: onProgress,
    );

    final failureRate = (samples - latencySamples.length) / samples;
    if (failureRate > SpeedTestConfig.failureThreshold) {
      throw Exception(
        'Latency test failed: ${(failureRate * 100).toStringAsFixed(0)}% of samples failed.'
      );
    }

    if (latencySamples.isEmpty) {
      throw Exception('All latency samples failed.');
    }

    final medianLatency = SpeedTestHelpers.calculateMedian(latencySamples).round();
    final isPoorConnection = latencySamples.any(
      (sample) => sample > SpeedTestConfig.poorConnectionThreshold
    );

    return {
      'median': medianLatency,
      'isPoorConnection': isPoorConnection,
      'sampleCount': latencySamples.length,
    };
  }

  // Download speed measurement
  Future<double> performDownloadSample(
    TestServer server,
    int sizeBytes, {
    int? connectionCount,
  }) async {
    return await _downloadExecutor.execute(
      server,
      sizeBytes,
      connectionCount: connectionCount ?? 4,
    );
  }

  Future<List<double>> performDownloadSamples(
    TestServer server,
    int count, {
    Function(int)? onProgress,
    Function(double)? onSpeedUpdate,
  }) async {
    final collector = SampleCollector(performDownloadSample);
    return await collector.collect(
      server,
      count,
      minSamples: SpeedTestConfig.downloadMinSamples,
      startSize: SpeedTestConfig.downloadStartSize,
      maxSize: SpeedTestConfig.downloadMaxSize,
      varianceThreshold: SpeedTestConfig.downloadVarianceThreshold,
      onProgress: onProgress,
      onSpeedUpdate: onSpeedUpdate,
    );
  }

  Future<Map<String, dynamic>> measureDownloadSpeed({
    TestServer? server,
    Function(int)? onProgress,
    Function(double)? onSpeedUpdate,
  }) async {
    final testServer = server ?? await selectOptimalServer();
    final downloadSamples = await performDownloadSamples(
      testServer,
      SpeedTestConfig.downloadMaxSamples,
      onProgress: onProgress,
      onSpeedUpdate: onSpeedUpdate,
    );

    if (downloadSamples.length < SpeedTestConfig.downloadMinSamples) {
      throw Exception('Download test failed: insufficient samples.');
    }

    if (downloadSamples.isEmpty) {
      throw Exception('All download samples failed.');
    }

    final medianSpeed = SpeedTestHelpers.calculateMedian(downloadSamples);
    final formattedSpeed = double.parse(medianSpeed.toStringAsFixed(1));

    return {
      'median': formattedSpeed,
      'sampleCount': downloadSamples.length,
    };
  }

  // Upload speed measurement
  Future<double> performUploadSample(
    TestServer server,
    int sizeBytes, {
    int? connectionCount,
  }) async {
    return await _uploadExecutor.execute(
      server,
      sizeBytes,
      connectionCount: connectionCount ?? 4,
    );
  }

  Future<List<double>> performUploadSamples(
    TestServer server,
    int count, {
    Function(int)? onProgress,
    Function(double)? onSpeedUpdate,
  }) async {
    final collector = SampleCollector(performUploadSample);
    return await collector.collect(
      server,
      count,
      minSamples: SpeedTestConfig.uploadMinSamples,
      startSize: SpeedTestConfig.uploadStartSize,
      maxSize: SpeedTestConfig.uploadMaxSize,
      varianceThreshold: SpeedTestConfig.uploadVarianceThreshold,
      onProgress: onProgress,
      onSpeedUpdate: onSpeedUpdate,
    );
  }

  Future<Map<String, dynamic>> measureUploadSpeed({
    TestServer? server,
    Function(int)? onProgress,
    Function(double)? onSpeedUpdate,
  }) async {
    final testServer = server ?? await selectOptimalServer();
    final uploadSamples = await performUploadSamples(
      testServer,
      SpeedTestConfig.uploadMaxSamples,
      onProgress: onProgress,
      onSpeedUpdate: onSpeedUpdate,
    );

    if (uploadSamples.length < SpeedTestConfig.uploadMinSamples) {
      throw Exception('Upload test failed: insufficient samples.');
    }

    if (uploadSamples.isEmpty) {
      throw Exception('All upload samples failed.');
    }

    final medianSpeed = SpeedTestHelpers.calculateMedian(uploadSamples);
    final formattedSpeed = double.parse(medianSpeed.toStringAsFixed(1));

    return {
      'median': formattedSpeed,
      'sampleCount': uploadSamples.length,
    };
  }

  // Full test orchestration
  Future<SpeedTestResult> runFullTest({
    required Function(TestProgress) onProgress,
    CancellationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled();

    // Server selection
    onProgress(TestProgress(
      phase: TestPhase.serverSelection,
      elapsedSeconds: 0,
      completedSamples: 0,
      totalSamples: 1,
    ));

    TestServer? selectedServer;
    try {
      selectedServer = await selectOptimalServer();
      cancellationToken?.throwIfCancelled();
    } catch (e) {
      throw Exception('No connectivity: All test servers failed to respond.');
    }

    // Latency
    onProgress(TestProgress(
      phase: TestPhase.latency,
      elapsedSeconds: 0,
      completedSamples: 0,
      totalSamples: SpeedTestConfig.latencySamples,
    ));

    final latencyResult = await _measureWithProgress(
      phase: TestPhase.latency,
      totalSamples: SpeedTestConfig.latencySamples,
      onProgress: onProgress,
      cancellationToken: cancellationToken,
      measurement: (progressCallback, speedCallback) => measureLatency(
        server: selectedServer,
        onProgress: progressCallback,
      ),
    );

    final int latency = latencyResult['median'];
    final bool isPoorConnection = latencyResult['isPoorConnection'];

    // Detect slow connection and choose appropriate test parameters
    final bool isSlowConnection =
        latency > SpeedTestConfig.slowConnectionLatencyThreshold ||
        isPoorConnection;

    final int dlMinSamples = isSlowConnection
        ? SpeedTestConfig.slowDownloadMinSamples
        : SpeedTestConfig.downloadMinSamples;
    final int dlMaxSamples = isSlowConnection
        ? SpeedTestConfig.slowDownloadMaxSamples
        : SpeedTestConfig.downloadMaxSamples;
    final int dlStartSize = isSlowConnection
        ? SpeedTestConfig.slowDownloadStartSize
        : SpeedTestConfig.downloadStartSize;
    final int dlMaxSize = isSlowConnection
        ? SpeedTestConfig.slowDownloadMaxSize
        : SpeedTestConfig.downloadMaxSize;
    final int ulMinSamples = isSlowConnection
        ? SpeedTestConfig.slowUploadMinSamples
        : SpeedTestConfig.uploadMinSamples;
    final int ulMaxSamples = isSlowConnection
        ? SpeedTestConfig.slowUploadMaxSamples
        : SpeedTestConfig.uploadMaxSamples;
    final int ulStartSize = isSlowConnection
        ? SpeedTestConfig.slowUploadStartSize
        : SpeedTestConfig.uploadStartSize;
    final int ulMaxSize = isSlowConnection
        ? SpeedTestConfig.slowUploadMaxSize
        : SpeedTestConfig.uploadMaxSize;
    final double varianceThreshold = isSlowConnection
        ? SpeedTestConfig.slowVarianceThreshold
        : SpeedTestConfig.downloadVarianceThreshold;

    // Download
    onProgress(TestProgress(
      phase: TestPhase.download,
      elapsedSeconds: 0,
      completedSamples: 0,
      totalSamples: dlMaxSamples,
      currentLatency: latency,
    ));

    final downloadResult = await _measureWithProgress(
      phase: TestPhase.download,
      totalSamples: dlMaxSamples,
      onProgress: onProgress,
      cancellationToken: cancellationToken,
      measurement: (progressCallback, speedCallback) =>
          _measureDownloadWithParams(
        server: selectedServer!,
        maxSamples: dlMaxSamples,
        minSamples: dlMinSamples,
        startSize: dlStartSize,
        maxSize: dlMaxSize,
        varianceThreshold: varianceThreshold,
        onProgress: progressCallback,
        onSpeedUpdate: speedCallback,
      ),
    );

    final double downloadSpeed = downloadResult['median'];
    final int downloadSamples = downloadResult['sampleCount'];

    // Upload
    onProgress(TestProgress(
      phase: TestPhase.upload,
      elapsedSeconds: 0,
      completedSamples: 0,
      totalSamples: ulMaxSamples,
      currentLatency: latency,
      currentSpeed: downloadSpeed,
    ));

    final uploadResult = await _measureWithProgress(
      phase: TestPhase.upload,
      totalSamples: ulMaxSamples,
      onProgress: onProgress,
      cancellationToken: cancellationToken,
      measurement: (progressCallback, speedCallback) =>
          _measureUploadWithParams(
        server: selectedServer!,
        maxSamples: ulMaxSamples,
        minSamples: ulMinSamples,
        startSize: ulStartSize,
        maxSize: ulMaxSize,
        varianceThreshold: varianceThreshold,
        onProgress: progressCallback,
        onSpeedUpdate: speedCallback,
      ),
    );

    final double uploadSpeed = uploadResult['median'];
    final int uploadSamples = uploadResult['sampleCount'];

    // Complete
    onProgress(TestProgress(
      phase: TestPhase.complete,
      elapsedSeconds: 0,
      completedSamples: 1,
      totalSamples: 1,
      currentLatency: latency,
      currentSpeed: downloadSpeed,
    ));

    return SpeedTestResult(
      downloadSpeed: downloadSpeed,
      uploadSpeed: uploadSpeed,
      latency: latency,
      timestamp: DateTime.now(),
      serverName: selectedServer.name,
      downloadSamples: downloadSamples,
      uploadSamples: uploadSamples,
      isPoorConnection: isPoorConnection,
    );
  }

  Future<Map<String, dynamic>> _measureDownloadWithParams({
    required TestServer server,
    required int maxSamples,
    required int minSamples,
    required int startSize,
    required int maxSize,
    required double varianceThreshold,
    Function(int)? onProgress,
    Function(double)? onSpeedUpdate,
  }) async {
    final collector = SampleCollector(performDownloadSample);
    final samples = await collector.collect(
      server,
      maxSamples,
      minSamples: minSamples,
      startSize: startSize,
      maxSize: maxSize,
      varianceThreshold: varianceThreshold,
      onProgress: onProgress,
      onSpeedUpdate: onSpeedUpdate,
    );

    if (samples.length < minSamples) {
      throw Exception('Download test failed: insufficient samples.');
    }
    if (samples.isEmpty) {
      throw Exception('All download samples failed.');
    }

    final medianSpeed = SpeedTestHelpers.calculateMedian(samples);
    return {
      'median': double.parse(medianSpeed.toStringAsFixed(1)),
      'sampleCount': samples.length,
    };
  }

  Future<Map<String, dynamic>> _measureUploadWithParams({
    required TestServer server,
    required int maxSamples,
    required int minSamples,
    required int startSize,
    required int maxSize,
    required double varianceThreshold,
    Function(int)? onProgress,
    Function(double)? onSpeedUpdate,
  }) async {
    final collector = SampleCollector(performUploadSample);
    final samples = await collector.collect(
      server,
      maxSamples,
      minSamples: minSamples,
      startSize: startSize,
      maxSize: maxSize,
      varianceThreshold: varianceThreshold,
      onProgress: onProgress,
      onSpeedUpdate: onSpeedUpdate,
    );

    if (samples.length < minSamples) {
      throw Exception('Upload test failed: insufficient samples.');
    }
    if (samples.isEmpty) {
      throw Exception('All upload samples failed.');
    }

    final medianSpeed = SpeedTestHelpers.calculateMedian(samples);
    return {
      'median': double.parse(medianSpeed.toStringAsFixed(1)),
      'sampleCount': samples.length,
    };
  }

  Future<Map<String, dynamic>> _measureWithProgress({
    required TestPhase phase,
    required int totalSamples,
    required Function(TestProgress) onProgress,
    CancellationToken? cancellationToken,
    required Future<Map<String, dynamic>> Function(Function(int)?, Function(double)?) measurement,
  }) async {
    int elapsedSeconds = 0;
    int completedSamples = 0;
    double? currentSpeed;
    
    final timer = Timer.periodic(
      Duration(milliseconds: SpeedTestConfig.progressUpdateInterval),
      (t) {
        cancellationToken?.throwIfCancelled();
        elapsedSeconds++;
        onProgress(TestProgress(
          phase: phase,
          elapsedSeconds: elapsedSeconds,
          completedSamples: completedSamples,
          totalSamples: totalSamples,
          currentSpeed: currentSpeed,
        ));
      },
    );

    try {
      // Pass callbacks to update completed samples and current speed
      return await measurement(
        (samples) {
          completedSamples = samples;
        },
        (speed) {
          currentSpeed = speed;
        },
      );
    } finally {
      timer.cancel();
    }
  }

  // Helper methods (kept for backward compatibility)
  double calculateMedian(List<num> values) => SpeedTestHelpers.calculateMedian(values);
  bool needsAdditionalSamples(List<double> samples, double threshold) =>
      SpeedTestHelpers.needsAdditionalSamples(samples, threshold);
  double calculateSpeed(int bytes, double seconds) =>
      SpeedTestHelpers.calculateSpeed(bytes, seconds);
  int calculateNextSize(double currentSpeed, int currentSize, int maxSize) =>
      SpeedTestHelpers.calculateNextSize(currentSpeed, currentSize, maxSize);
  int getOptimalConnectionCount(double speedMbps) =>
      SpeedTestHelpers.getOptimalConnectionCount(speedMbps);
}
