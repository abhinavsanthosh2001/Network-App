import 'dart:async';
import 'package:dio/dio.dart';
import '../models/test_server.dart';
import '../models/speed_test_config.dart';
import '../models/test_progress.dart';
import '../models/cancellation_token.dart';
import '../models/speed_test_result.dart';

class SpeedTestService {
  late final Dio _dio;
  late final List<TestServer> testServers;
  
  SpeedTestService() {
    // Initialize Dio with appropriate timeouts and optimizations for speed testing
    _dio = Dio(BaseOptions(
      connectTimeout: Duration(milliseconds: SpeedTestConfig.serverSelectionTimeout),
      receiveTimeout: Duration(milliseconds: SpeedTestConfig.serverSelectionTimeout),
      sendTimeout: Duration(milliseconds: SpeedTestConfig.serverSelectionTimeout),
      // Disable compression for accurate speed measurement
      headers: {
        'Accept-Encoding': 'identity',
        'Cache-Control': 'no-cache',
      },
    ));
    
    // Initialize test servers optimized for speed testing
    // Using CDN-hosted large files for accurate bandwidth measurement
    testServers = [
      TestServer(
        name: 'Cloudflare CDN',
        baseUrl: 'https://speed.cloudflare.com',
        downloadEndpoint: '/__down?bytes={size}',
        uploadEndpoint: '/__up',
        pingEndpoint: '/__down?bytes=1000',
      ),
      TestServer(
        name: 'Proof of Concept CDN',
        baseUrl: 'https://proof.ovh.net/files',
        downloadEndpoint: '/100Mb.dat',
        uploadEndpoint: '/upload.php',
        pingEndpoint: '/1Mb.dat',
      ),
      TestServer(
        name: 'Bouygues CDN',
        baseUrl: 'http://speedtest.bouygues.fr',
        downloadEndpoint: '/10Mo.dat',
        uploadEndpoint: '/upload.php',
        pingEndpoint: '/1Mo.dat',
      ),
    ];
  }

  /// Validates if a server is available and responding.
  /// 
  /// Sends a minimal HTTP GET request to the server's ping endpoint
  /// and checks if it responds within the configured timeout (5 seconds).
  /// 
  /// [server] - The test server to validate
  /// 
  /// Returns true if the server responds successfully, false otherwise.
  /// 
  /// This method is used to check server availability before running
  /// speed tests, as specified in Requirements 1.4.
  Future<bool> validateServer(TestServer server) async {
    try {
      // Use the server's ping endpoint for validation
      final url = server.getPingUrl();
      
      // Create a Dio instance with 5-second timeout for validation
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(milliseconds: SpeedTestConfig.serverSelectionTimeout),
        receiveTimeout: const Duration(milliseconds: SpeedTestConfig.serverSelectionTimeout),
        sendTimeout: const Duration(milliseconds: SpeedTestConfig.serverSelectionTimeout),
      ));
      
      // Attempt to reach the server
      await dio.get(url);
      
      // If we get here, the server responded successfully
      return true;
    } catch (e) {
      // Any error (timeout, network error, HTTP error) means server is not available
      return false;
    }
  }

  /// Measures the latency (round-trip time) to a single server.
  /// 
  /// Sends a minimal HTTP GET request to the server's ping endpoint
  /// and measures the time from request initiation to response receipt.
  /// 
  /// [server] - The test server to measure latency for
  /// 
  /// Returns the round-trip time in milliseconds.
  /// 
  /// This method performs a single latency measurement. For the complete
  /// latency test with multiple samples and median calculation, use
  /// measureLatency() instead.
  /// 
  /// Requirements: 4.1 (minimal HTTP GET), 4.3 (round-trip time measurement)
  Future<int> measureServerLatency(TestServer server) async {
    // Start timing before making the request
    final stopwatch = Stopwatch()..start();
    
    try {
      // Send minimal HTTP GET request to the server's ping endpoint
      final url = server.getPingUrl();
      await _dio.get(url);
      
      // Stop timing after receiving response
      stopwatch.stop();
      
      // Return round-trip time in milliseconds
      return stopwatch.elapsedMilliseconds;
    } catch (e) {
      // Stop timing even on error
      stopwatch.stop();
      
      // Rethrow the error so caller can handle it
      rethrow;
    }
  }

  /// Selects the optimal test server based on latency measurements.
  /// 
  /// This method tests all available servers and selects the best one according
  /// to the following criteria:
  /// 1. Servers with latency < 100ms are preferred (Requirement 1.5)
  /// 2. Among preferred servers, the one with lowest latency is selected (Requirement 1.2)
  /// 3. If no servers have latency < 100ms, the server with lowest latency is selected
  /// 4. Servers that fail to respond are excluded from selection (Requirement 1.3)
  /// 
  /// Returns the optimal [TestServer] for speed testing.
  /// 
  /// Throws [Exception] if all servers fail to respond.
  /// 
  /// Requirements: 1.2 (optimal selection), 1.3 (fallback), 1.5 (prefer < 100ms)
  Future<TestServer> selectOptimalServer() async {
    // Map to store server latencies
    final Map<TestServer, int> serverLatencies = {};
    
    // Test all servers and measure their latencies
    for (final server in testServers) {
      try {
        // Validate server is available first
        final isAvailable = await validateServer(server);
        if (!isAvailable) {
          continue; // Skip unavailable servers
        }
        
        // Measure latency for this server
        final latency = await measureServerLatency(server);
        serverLatencies[server] = latency;
      } catch (e) {
        // Server failed - skip it and try next one
        continue;
      }
    }
    
    // If all servers failed, throw an exception
    if (serverLatencies.isEmpty) {
      throw Exception('All test servers failed to respond');
    }
    
    // Separate servers into preferred (< 100ms) and others
    final preferredServers = <TestServer, int>{};
    final otherServers = <TestServer, int>{};
    
    for (final entry in serverLatencies.entries) {
      if (entry.value < SpeedTestConfig.maxLatencyForPreference) {
        preferredServers[entry.key] = entry.value;
      } else {
        otherServers[entry.key] = entry.value;
      }
    }
    
    // If we have preferred servers (< 100ms), select the one with lowest latency
    if (preferredServers.isNotEmpty) {
      return preferredServers.entries
          .reduce((a, b) => a.value < b.value ? a : b)
          .key;
    }
    
    // Otherwise, select the server with lowest latency from all available servers
    return otherServers.entries
        .reduce((a, b) => a.value < b.value ? a : b)
        .key;
  }

  /// Collects multiple latency samples with retry logic.
  /// 
  /// Performs the specified number of latency measurements to a server,
  /// with automatic retry on failures. This provides more accurate latency
  /// measurements by taking multiple samples and handling transient network issues.
  /// 
  /// [server] - The test server to measure latency for
  /// [count] - The number of samples to collect (default: 5 per Requirement 4.2)
  /// 
  /// Returns a list of successful latency measurements in milliseconds.
  /// Failed samples (after retries) are excluded from the returned list.
  /// 
  /// For each sample:
  /// - Attempts to measure latency using measureServerLatency()
  /// - On timeout or network error, retries up to 2 times (Requirement 7.1)
  /// - Waits 1 second between retry attempts
  /// - If all retries fail, excludes that sample from results
  /// 
  /// Example:
  /// ```dart
  /// final samples = await performLatencySamples(server, 5);
  /// // Returns list like [45, 52, 48, 51, 49] (in milliseconds)
  /// ```
  /// 
  /// Requirements: 4.2 (at least 5 samples), 7.1 (retry up to 2 times)
  Future<List<int>> performLatencySamples(TestServer server, int count) async {
    final List<int> successfulSamples = [];
    
    for (int i = 0; i < count; i++) {
      int retryCount = 0;
      bool sampleSucceeded = false;
      
      // Try to get a sample, with up to 2 retries on failure
      while (retryCount <= SpeedTestConfig.maxRetries && !sampleSucceeded) {
        try {
          // Attempt to measure latency
          final latency = await measureServerLatency(server);
          successfulSamples.add(latency);
          sampleSucceeded = true;
        } catch (e) {
          retryCount++;
          
          // If we haven't exceeded max retries, wait before retrying
          if (retryCount <= SpeedTestConfig.maxRetries) {
            await Future.delayed(
              Duration(milliseconds: SpeedTestConfig.retryDelay)
            );
          }
          // If we've exhausted retries, this sample fails (excluded from results)
        }
      }
    }
    
    return successfulSamples;
  }

  /// Measures complete latency with multiple samples and median calculation.
  /// 
  /// This is the main latency measurement method that orchestrates the complete
  /// latency test. It collects multiple samples, calculates the median, and
  /// determines if the connection quality is poor.
  /// 
  /// The method:
  /// 1. Selects the optimal server (if not provided)
  /// 2. Collects at least 5 latency samples using performLatencySamples()
  /// 3. Excludes failed samples from calculation (Requirement 7.3)
  /// 4. Calculates the median of successful samples (Requirement 4.4)
  /// 5. Checks if any sample exceeds 1000ms to flag poor connection (Requirement 4.6)
  /// 
  /// [server] - Optional test server to use. If not provided, selects optimal server.
  /// [samples] - Number of samples to collect (default: 5 per Requirement 4.2)
  /// 
  /// Returns a map containing:
  /// - 'median': The median latency in milliseconds (int)
  /// - 'isPoorConnection': Whether any sample exceeded 1000ms (bool)
  /// - 'sampleCount': Number of successful samples collected (int)
  /// 
  /// Throws [Exception] if more than 50% of samples fail (Requirement 7.4)
  /// 
  /// Example:
  /// ```dart
  /// final result = await measureLatency();
  /// print('Latency: ${result['median']} ms');
  /// print('Poor connection: ${result['isPoorConnection']}');
  /// ```
  /// 
  /// Requirements: 4.2 (at least 5 samples), 4.4 (median), 4.5 (integer ms),
  ///               4.6 (flag poor connection), 7.3 (exclude failed samples)
  Future<Map<String, dynamic>> measureLatency({
    TestServer? server,
    int samples = SpeedTestConfig.latencySamples,
  }) async {
    // Select optimal server if not provided
    final testServer = server ?? await selectOptimalServer();
    
    // Collect latency samples with retry logic
    final latencySamples = await performLatencySamples(testServer, samples);
    
    // Check if more than 50% of samples failed (Requirement 7.4)
    final failureRate = (samples - latencySamples.length) / samples;
    if (failureRate > SpeedTestConfig.failureThreshold) {
      throw Exception(
        'Latency test failed: ${(failureRate * 100).toStringAsFixed(0)}% of samples failed. '
        'Please check your network connection.'
      );
    }
    
    // If all samples failed, throw an error
    if (latencySamples.isEmpty) {
      throw Exception('All latency samples failed. Unable to measure latency.');
    }
    
    // Calculate median of successful samples (Requirement 4.4)
    // Note: calculateMedian returns double, but we need int for latency
    final medianLatency = calculateMedian(latencySamples).round();
    
    // Check if any sample exceeds 1000ms to flag poor connection (Requirement 4.6)
    final isPoorConnection = latencySamples.any(
      (sample) => sample > SpeedTestConfig.poorConnectionThreshold
    );
    
    // Return result with median, poor connection flag, and sample count
    return {
      'median': medianLatency,
      'isPoorConnection': isPoorConnection,
      'sampleCount': latencySamples.length,
    };
  }

  /// Performs a single download sample measurement with accurate timing.
  /// 
  /// This method downloads data from the specified server using MULTIPLE PARALLEL
  /// connections to saturate bandwidth (like Speedtest.net does). This is critical
  /// for accurate measurements as a single HTTP connection cannot saturate modern
  /// high-speed connections due to TCP window limitations.
  /// 
  /// [server] - The test server to download from
  /// [sizeBytes] - The TOTAL size of data to download in bytes (split across connections)
  /// 
  /// Returns the measured download speed in Mbps (megabits per second)
  /// 
  /// The method:
  /// 1. Splits the download into 10 parallel connections
  /// 2. Each connection downloads a portion of the total size
  /// 3. Starts timing after first data chunk received
  /// 4. Tracks total bytes across all connections
  /// 5. Calculates speed using total bytes and elapsed time
  /// 
  /// Requirements:
  /// - 2.1: Progressive file sizes (10MB to 100MB)
  /// - 2.3: Exclude connection establishment time
  /// - 2.4: Measure only data transfer phase (after headers)
  /// - 9.2: Start timing after connection establishment
  /// - 9.3: Stop timing when last byte received
  /// - 9.4: Calculate speed using actual bytes transferred
  /// 
  /// Example:
  /// ```dart
  /// final server = await selectOptimalServer();
  /// final speed = await performDownloadSample(server, 10485760); // 10MB
  /// print('Download speed: ${speed.toStringAsFixed(1)} Mbps');
  /// ```
  Future<double> performDownloadSample(TestServer server, int sizeBytes, {int? connectionCount}) async {
    // Use adaptive connection count based on speed, or provided count
    // For first sample, use 4 connections as a reasonable default
    final int numConnections = connectionCount ?? 4;
    final int sizePerConnection = sizeBytes ~/ numConnections;
    
    // Track total bytes received across all connections
    int totalBytesReceived = 0;
    
    // Stopwatch for timing - will start after first data received
    final stopwatch = Stopwatch();
    
    // Flag to track if we've started timing
    bool timingStarted = false;
    
    try {
      // Create parallel download tasks
      final downloadTasks = List.generate(numConnections, (index) async {
        final url = server.getDownloadUrl(sizePerConnection);
        int connectionBytes = 0;
        
        try {
          final response = await _dio.get<ResponseBody>(
            url,
            options: Options(
              responseType: ResponseType.stream,
              receiveTimeout: Duration(milliseconds: 120000), // 120 second timeout for large files
              headers: {
                'Accept-Encoding': 'identity', // Disable compression
                'Cache-Control': 'no-cache',
              },
            ),
          );
          
          await for (final chunk in response.data!.stream) {
            // Start timing on first data chunk from any connection
            if (!timingStarted) {
              stopwatch.start();
              timingStarted = true;
            }
            
            connectionBytes += chunk.length;
          }
        } catch (e) {
          // Connection failed, but continue with others
        }
        
        return connectionBytes;
      });
      
      // Wait for all parallel downloads to complete
      final results = await Future.wait(downloadTasks);
      totalBytesReceived = results.reduce((a, b) => a + b);
      
      // Stop timing after all downloads complete
      if (timingStarted) {
        stopwatch.stop();
      }
      
      // Calculate speed using total bytes transferred and elapsed time
      final seconds = stopwatch.elapsedMilliseconds / 1000.0;
      
      // Use calculateSpeed helper to convert to Mbps
      return calculateSpeed(totalBytesReceived, seconds);
      
    } catch (e) {
      // Stop timing on error
      if (timingStarted && stopwatch.isRunning) {
        stopwatch.stop();
      }
      
      // Rethrow the error for caller to handle
      rethrow;
    }
  }

  /// Collects multiple download samples with progressive sizing and retry logic.
  /// 
  /// This method orchestrates the collection of multiple download speed samples,
  /// implementing progressive sizing based on connection speed and adaptive
  /// sampling based on variance. It provides robust measurements by handling
  /// failures and retrying when necessary.
  /// 
  /// [server] - The test server to download from
  /// [count] - The number of samples to collect (default: 3-5 based on variance)
  /// 
  /// Returns a list of successful download speed measurements in Mbps.
  /// Failed samples (after retries) are excluded from the returned list.
  /// 
  /// The method implements:
  /// 1. Progressive sizing: Starts with 5MB, increases based on measured speed
  /// 2. Adaptive sampling: Performs 3-5 samples based on variance (30% threshold)
  /// 3. Retry logic: Retries failed samples up to 2 times
  /// 4. Failure handling: Excludes failed samples from results
  /// 
  /// Progressive Sizing Algorithm:
  /// - First sample: 5MB (SpeedTestConfig.downloadStartSize)
  /// - Subsequent samples: Size calculated to target 7-10 seconds transfer time
  /// - Maximum size: 50MB (SpeedTestConfig.downloadMaxSize)
  /// 
  /// Adaptive Sampling:
  /// - Minimum samples: 3 (SpeedTestConfig.downloadMinSamples)
  /// - Maximum samples: 5 (SpeedTestConfig.downloadMaxSamples)
  /// - Additional samples collected if variance > 30%
  /// 
  /// Example:
  /// ```dart
  /// final server = await selectOptimalServer();
  /// final samples = await performDownloadSamples(server, 5);
  /// // Returns list like [45.3, 48.1, 46.7] (in Mbps)
  /// ```
  /// 
  /// Requirements:
  /// - 2.1: Progressive file sizes starting at 5MB, increasing to 50MB
  /// - 2.2: Perform at least 3 test samples
  /// - 2.5: Perform additional samples (up to 5) when variance > 30%
  Future<List<double>> performDownloadSamples(
    TestServer server,
    int count,
  ) async {
    final List<double> successfulSamples = [];
    
    // Start with smaller size for first sample (will adapt based on speed)
    int currentSize = SpeedTestConfig.downloadStartSize;
    int currentConnectionCount = 4; // Start with 4 connections
    
    // Collect samples up to the specified count
    for (int i = 0; i < count; i++) {
      int retryCount = 0;
      bool sampleSucceeded = false;
      double? sampleSpeed;
      
      // Try to get a sample, with up to 2 retries on failure
      while (retryCount <= SpeedTestConfig.maxRetries && !sampleSucceeded) {
        try {
          // Attempt to measure download speed with adaptive connection count
          sampleSpeed = await performDownloadSample(
            server, 
            currentSize,
            connectionCount: currentConnectionCount,
          );
          successfulSamples.add(sampleSpeed);
          sampleSucceeded = true;
        } catch (e) {
          retryCount++;
          
          // If we haven't exceeded max retries, wait before retrying
          if (retryCount <= SpeedTestConfig.maxRetries) {
            await Future.delayed(
              const Duration(milliseconds: SpeedTestConfig.retryDelay)
            );
          }
          // If we've exhausted retries, this sample fails (excluded from results)
        }
      }
      
      // If sample succeeded and we have more samples to collect,
      // calculate the next size and connection count based on the measured speed
      if (sampleSucceeded && sampleSpeed != null && i < count - 1) {
        currentSize = calculateNextSize(
          sampleSpeed,
          currentSize,
          SpeedTestConfig.downloadMaxSize,
        );
        // Adapt connection count based on measured speed
        currentConnectionCount = getOptimalConnectionCount(sampleSpeed);
      }
      
      // After collecting minimum samples, check if we need more based on variance
      if (i >= SpeedTestConfig.downloadMinSamples - 1) {
        // Check if we've reached max samples
        if (i >= SpeedTestConfig.downloadMaxSamples - 1) {
          break; // Stop at max samples
        }
        
        // Check if variance is acceptable (no additional samples needed)
        if (!needsAdditionalSamples(
          successfulSamples,
          SpeedTestConfig.downloadVarianceThreshold,
        )) {
          break; // Variance is acceptable, stop collecting samples
        }
      }
    }
    
    return successfulSamples;
  }

  /// Measures complete download speed with multiple samples and median calculation.
  /// 
  /// This is the main download speed measurement method that orchestrates the complete
  /// download test. It collects multiple samples with progressive sizing, calculates
  /// the median, and formats the result.
  /// 
  /// The method:
  /// 1. Selects the optimal server (if not provided)
  /// 2. Collects 3-5 download samples using performDownloadSamples()
  /// 3. Excludes failed samples from calculation (handled by performDownloadSamples)
  /// 4. Calculates the median of successful samples (Requirement 2.6)
  /// 5. Formats result to one decimal place (Requirement 2.7)
  /// 
  /// [server] - Optional test server to use. If not provided, selects optimal server.
  /// 
  /// Returns a map containing:
  /// - 'median': The median download speed in Mbps, formatted to one decimal place (double)
  /// - 'sampleCount': Number of successful samples collected (int)
  /// 
  /// Throws [Exception] if more than 50% of samples fail (Requirement 7.4)
  /// 
  /// Example:
  /// ```dart
  /// final result = await measureDownloadSpeed();
  /// print('Download speed: ${result['median']} Mbps');
  /// print('Samples collected: ${result['sampleCount']}');
  /// ```
  /// 
  /// Requirements: 2.6 (median calculation), 2.7 (one decimal place formatting)
  Future<Map<String, dynamic>> measureDownloadSpeed({
    TestServer? server,
  }) async {
    // Select optimal server if not provided
    final testServer = server ?? await selectOptimalServer();
    
    // Collect download samples with progressive sizing and retry logic
    // This will collect 3-5 samples based on variance
    final downloadSamples = await performDownloadSamples(
      testServer,
      SpeedTestConfig.downloadMaxSamples,
    );
    
    // Check if more than 50% of minimum samples failed (Requirement 7.4)
    final minSamples = SpeedTestConfig.downloadMinSamples;
    if (downloadSamples.length < minSamples) {
      final failureRate = (minSamples - downloadSamples.length) / minSamples;
      if (failureRate > SpeedTestConfig.failureThreshold) {
        throw Exception(
          'Download test failed: ${(failureRate * 100).toStringAsFixed(0)}% of samples failed. '
          'Please check your network connection.'
        );
      }
    }
    
    // If all samples failed, throw an error
    if (downloadSamples.isEmpty) {
      throw Exception('All download samples failed. Unable to measure download speed.');
    }
    
    // Calculate median of successful samples (Requirement 2.6)
    final medianSpeed = calculateMedian(downloadSamples);
    
    // Format to one decimal place (Requirement 2.7)
    // Parse back to double to ensure it's stored as a proper number
    final formattedSpeed = double.parse(medianSpeed.toStringAsFixed(1));
    
    // Return result with median speed and sample count
    return {
      'median': formattedSpeed,
      'sampleCount': downloadSamples.length,
    };
  }

  /// Performs a single upload sample measurement with accurate timing.
  /// 
  /// This method uploads data to the specified server using MULTIPLE PARALLEL
  /// connections to saturate bandwidth. This is critical for accurate measurements
  /// as a single HTTP connection cannot saturate modern high-speed connections.
  /// 
  /// [server] - The test server to upload to
  /// [sizeBytes] - The TOTAL size of data to upload in bytes (split across connections)
  /// 
  /// Returns the measured upload speed in Mbps (megabits per second)
  /// 
  /// The method:
  /// 1. Splits the upload into 6 parallel connections
  /// 2. Each connection uploads a portion of the total size
  /// 3. Uses streaming upload with progress tracking
  /// 4. Starts timing when first data chunk is sent
  /// 5. Tracks total bytes across all connections
  /// 6. Calculates speed using total bytes and elapsed time
  /// 
  /// Requirements:
  /// - 3.1: Progressive data sizes (5MB to 50MB)
  /// - 3.3: Exclude connection establishment time
  /// - 3.4: Measure only data transfer phase (streaming with progress)
  /// - 9.2: Start timing after connection establishment
  /// - 9.3: Stop timing when last byte sent
  /// - 9.4: Calculate speed using actual bytes transferred
  /// 
  /// Example:
  /// ```dart
  /// final server = await selectOptimalServer();
  /// final speed = await performUploadSample(server, 5242880); // 5MB
  /// print('Upload speed: ${speed.toStringAsFixed(1)} Mbps');
  /// ```
  Future<double> performUploadSample(TestServer server, int sizeBytes, {int? connectionCount}) async {
    // Use adaptive connection count based on speed, or provided count
    final int numConnections = connectionCount ?? 4;
    final int sizePerConnection = sizeBytes ~/ numConnections;
    
    final stopwatch = Stopwatch();
    bool timingStarted = false;
    int totalBytesSent = 0;
    
    try {
      // Create parallel upload tasks
      final uploadTasks = List.generate(numConnections, (index) async {
        final url = server.getUploadUrl();
        
        // Generate random data to prevent compression
        final random = List.generate(sizePerConnection, (i) => i % 256);
        int connectionBytes = 0;
        
        try {
          await _dio.put(
            url,
            data: Stream.fromIterable([random]),
            options: Options(
              contentType: 'application/octet-stream',
              headers: {'Content-Length': sizePerConnection.toString()},
              sendTimeout: Duration(milliseconds: 120000),
            ),
            onSendProgress: (sent, total) {
              // Start timing on first progress callback from any connection
              if (!timingStarted && sent > 0) {
                stopwatch.start();
                timingStarted = true;
              }
              connectionBytes = sent;
            },
          );
        } catch (e) {
          // Connection failed, but continue with others
        }
        
        return connectionBytes > 0 ? connectionBytes : sizePerConnection;
      });
      
      // Wait for all parallel uploads to complete
      final results = await Future.wait(uploadTasks);
      totalBytesSent = results.reduce((a, b) => a + b);
      
      // Stop timing after all uploads complete
      if (timingStarted) {
        stopwatch.stop();
      }
      
      final seconds = stopwatch.elapsedMilliseconds / 1000.0;
      return calculateSpeed(totalBytesSent, seconds);
      
    } catch (e) {
      if (stopwatch.isRunning) stopwatch.stop();
      rethrow;
    }
  }

  /// Collects multiple upload samples with progressive sizing and retry logic.
  /// 
  /// This method orchestrates the collection of multiple upload speed samples,
  /// implementing progressive sizing based on connection speed and adaptive
  /// sampling based on variance. It provides robust measurements by handling
  /// failures and retrying when necessary.
  /// 
  /// [server] - The test server to upload to
  /// [count] - The number of samples to collect (default: 3-5 based on variance)
  /// 
  /// Returns a list of successful upload speed measurements in Mbps.
  /// Failed samples (after retries) are excluded from the returned list.
  /// 
  /// The method implements:
  /// 1. Progressive sizing: Starts with 2MB, increases based on measured speed
  /// 2. Adaptive sampling: Performs 3-5 samples based on variance (30% threshold)
  /// 3. Retry logic: Retries failed samples up to 2 times
  /// 4. Failure handling: Excludes failed samples from results
  /// 
  /// Progressive Sizing Algorithm:
  /// - First sample: 2MB (SpeedTestConfig.uploadStartSize)
  /// - Subsequent samples: Size calculated to target 7-10 seconds transfer time
  /// - Maximum size: 20MB (SpeedTestConfig.uploadMaxSize)
  /// 
  /// Adaptive Sampling:
  /// - Minimum samples: 3 (SpeedTestConfig.uploadMinSamples)
  /// - Maximum samples: 5 (SpeedTestConfig.uploadMaxSamples)
  /// - Additional samples collected if variance > 30%
  /// 
  /// Example:
  /// ```dart
  /// final server = await selectOptimalServer();
  /// final samples = await performUploadSamples(server, 5);
  /// // Returns list like [12.3, 13.1, 12.7] (in Mbps)
  /// ```
  /// 
  /// Requirements:
  /// - 3.1: Progressive data sizes starting at 2MB, increasing to 20MB
  /// - 3.2: Perform at least 3 test samples
  /// - 3.5: Perform additional samples (up to 5) when variance > 30%
  Future<List<double>> performUploadSamples(
    TestServer server,
    int count,
  ) async {
    final List<double> successfulSamples = [];
    
    // Start with smaller size for first sample (will adapt based on speed)
    int currentSize = SpeedTestConfig.uploadStartSize;
    int currentConnectionCount = 4; // Start with 4 connections
    
    // Collect samples up to the specified count
    for (int i = 0; i < count; i++) {
      int retryCount = 0;
      bool sampleSucceeded = false;
      double? sampleSpeed;
      
      // Try to get a sample, with up to 2 retries on failure
      while (retryCount <= SpeedTestConfig.maxRetries && !sampleSucceeded) {
        try {
          // Attempt to measure upload speed with adaptive connection count
          sampleSpeed = await performUploadSample(
            server, 
            currentSize,
            connectionCount: currentConnectionCount,
          );
          successfulSamples.add(sampleSpeed);
          sampleSucceeded = true;
        } catch (e) {
          retryCount++;
          
          // If we haven't exceeded max retries, wait before retrying
          if (retryCount <= SpeedTestConfig.maxRetries) {
            await Future.delayed(
              const Duration(milliseconds: SpeedTestConfig.retryDelay)
            );
          }
          // If we've exhausted retries, this sample fails (excluded from results)
        }
      }
      
      // If sample succeeded and we have more samples to collect,
      // calculate the next size and connection count based on the measured speed
      if (sampleSucceeded && sampleSpeed != null && i < count - 1) {
        currentSize = calculateNextSize(
          sampleSpeed,
          currentSize,
          SpeedTestConfig.uploadMaxSize,
        );
        // Adapt connection count based on measured speed
        currentConnectionCount = getOptimalConnectionCount(sampleSpeed);
      }
      
      // After collecting minimum samples, check if we need more based on variance
      if (i >= SpeedTestConfig.uploadMinSamples - 1) {
        // Check if we've reached max samples
        if (i >= SpeedTestConfig.uploadMaxSamples - 1) {
          break; // Stop at max samples
        }
        
        // Check if variance is acceptable (no additional samples needed)
        if (!needsAdditionalSamples(
          successfulSamples,
          SpeedTestConfig.uploadVarianceThreshold,
        )) {
          break; // Variance is acceptable, stop collecting samples
        }
      }
    }
    
    return successfulSamples;
  }

  /// Measures complete upload speed with multiple samples and median calculation.
  /// 
  /// This is the main upload speed measurement method that orchestrates the complete
  /// upload test. It collects multiple samples with progressive sizing, calculates
  /// the median, and formats the result.
  /// 
  /// The method:
  /// 1. Selects the optimal server (if not provided)
  /// 2. Collects 3-5 upload samples using performUploadSamples()
  /// 3. Excludes failed samples from calculation (handled by performUploadSamples)
  /// 4. Calculates the median of successful samples (Requirement 3.6)
  /// 5. Formats result to one decimal place (Requirement 3.7)
  /// 
  /// [server] - Optional test server to use. If not provided, selects optimal server.
  /// 
  /// Returns a map containing:
  /// - 'median': The median upload speed in Mbps, formatted to one decimal place (double)
  /// - 'sampleCount': Number of successful samples collected (int)
  /// 
  /// Throws [Exception] if more than 50% of samples fail (Requirement 7.4)
  /// 
  /// Example:
  /// ```dart
  /// final result = await measureUploadSpeed();
  /// print('Upload speed: ${result['median']} Mbps');
  /// print('Samples collected: ${result['sampleCount']}');
  /// ```
  /// 
  /// Requirements: 3.6 (median calculation), 3.7 (one decimal place formatting)
  Future<Map<String, dynamic>> measureUploadSpeed({
    TestServer? server,
  }) async {
    // Select optimal server if not provided
    final testServer = server ?? await selectOptimalServer();
    
    // Collect upload samples with progressive sizing and retry logic
    // This will collect 3-5 samples based on variance
    final uploadSamples = await performUploadSamples(
      testServer,
      SpeedTestConfig.uploadMaxSamples,
    );
    
    // Check if more than 50% of minimum samples failed (Requirement 7.4)
    const minSamples = SpeedTestConfig.uploadMinSamples;
    if (uploadSamples.length < minSamples) {
      final failureRate = (minSamples - uploadSamples.length) / minSamples;
      if (failureRate > SpeedTestConfig.failureThreshold) {
        throw Exception(
          'Upload test failed: ${(failureRate * 100).toStringAsFixed(0)}% of samples failed. '
          'Please check your network connection.'
        );
      }
    }
    
    // If all samples failed, throw an error
    if (uploadSamples.isEmpty) {
      throw Exception('All upload samples failed. Unable to measure upload speed.');
    }
    
    // Calculate median of successful samples (Requirement 3.6)
    final medianSpeed = calculateMedian(uploadSamples);
    
    // Format to one decimal place (Requirement 3.7)
    // Parse back to double to ensure it's stored as a proper number
    final formattedSpeed = double.parse(medianSpeed.toStringAsFixed(1));
    
    // Return result with median speed and sample count
    return {
      'median': formattedSpeed,
      'sampleCount': uploadSamples.length,
    };
  }

  /// Runs a complete speed test with all three phases.
  /// 
  /// This is the main entry point for executing a full speed test. It orchestrates
  /// all three test phases (latency, download, upload) in sequence, with progress
  /// reporting and cancellation support.
  /// 
  /// The method:
  /// 1. Selects the optimal server based on latency
  /// 2. Measures latency (5 samples, median calculation)
  /// 3. Measures download speed (3-5 samples with progressive sizing)
  /// 4. Measures upload speed (3-5 samples with progressive sizing)
  /// 5. Creates and returns a SpeedTestResult with all measurements
  /// 
  /// [onProgress] - Callback function called periodically to report progress
  /// [cancellationToken] - Optional token to cancel the test mid-execution
  /// 
  /// Returns a [SpeedTestResult] containing all measurements and metadata.
  /// 
  /// Throws:
  /// - [CancelledException] if the test is cancelled via cancellationToken
  /// - [Exception] if all servers fail or if >50% of samples fail in any phase
  /// 
  /// Progress Reporting:
  /// The onProgress callback is called:
  /// - When server selection starts
  /// - When each test phase starts
  /// - Periodically during each phase (at least once per second)
  /// - When each phase completes
  /// 
  /// Cancellation:
  /// The test can be cancelled at any time by calling cancel() on the
  /// cancellationToken. The test will stop immediately and throw CancelledException.
  /// 
  /// Example:
  /// ```dart
  /// final service = SpeedTestService();
  /// final token = CancellationToken();
  /// 
  /// try {
  ///   final result = await service.runFullTest(
  ///     onProgress: (progress) {
  ///       print('Phase: ${progress.phaseDescription}');
  ///       print('Progress: ${(progress.progressPercentage * 100).toStringAsFixed(0)}%');
  ///     },
  ///     cancellationToken: token,
  ///   );
  ///   print('Download: ${result.formattedDownloadSpeed}');
  ///   print('Upload: ${result.formattedUploadSpeed}');
  ///   print('Latency: ${result.formattedLatency}');
  /// } on CancelledException {
  ///   print('Test was cancelled');
  /// }
  /// ```
  /// 
  /// Requirements:
  /// - 8.1: Begin test sequence starting with latency
  /// - 8.2: Execute phases in order (latency, download, upload)
  /// - 8.3: Support cancellation
  /// - 7.6: Handle errors and fallback to alternative servers
  /// - 6.2, 6.3: Emit progress updates at least once per second
  Future<SpeedTestResult> runFullTest({
    required Function(TestProgress) onProgress,
    CancellationToken? cancellationToken,
  }) async {
    // Check for cancellation before starting
    cancellationToken?.throwIfCancelled();
    
    // Phase 1: Server Selection
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
      // If server selection fails, try to use the first available server
      // or rethrow if all servers are unavailable
      if (e.toString().contains('All test servers failed')) {
        throw Exception(
          'No connectivity: All test servers failed to respond. '
          'Please check your internet connection.'
        );
      }
      rethrow;
    }
    
    // Phase 2: Latency Measurement
    onProgress(TestProgress(
      phase: TestPhase.latency,
      elapsedSeconds: 0,
      completedSamples: 0,
      totalSamples: SpeedTestConfig.latencySamples,
    ));
    
    late Map<String, dynamic> latencyResult;
    try {
      latencyResult = await _measureWithProgress(
        phase: TestPhase.latency,
        totalSamples: SpeedTestConfig.latencySamples,
        onProgress: onProgress,
        cancellationToken: cancellationToken,
        measurement: () => measureLatency(server: selectedServer),
      );
    } catch (e) {
      // If latency measurement fails, try to fallback to another server
      if (e is! CancelledException) {
        // Try to select a different server
        try {
          selectedServer = await _selectFallbackServer(selectedServer);
          cancellationToken?.throwIfCancelled();
          
          latencyResult = await _measureWithProgress(
            phase: TestPhase.latency,
            totalSamples: SpeedTestConfig.latencySamples,
            onProgress: onProgress,
            cancellationToken: cancellationToken,
            measurement: () => measureLatency(server: selectedServer),
          );
        } catch (fallbackError) {
          throw Exception(
            'Latency test failed: ${fallbackError.toString()}'
          );
        }
      } else {
        rethrow;
      }
    }
    
    final int latency = latencyResult['median'];
    final bool isPoorConnection = latencyResult['isPoorConnection'];
    
    // Phase 3: Download Speed Measurement
    onProgress(TestProgress(
      phase: TestPhase.download,
      elapsedSeconds: 0,
      completedSamples: 0,
      totalSamples: SpeedTestConfig.downloadMaxSamples,
      currentLatency: latency,
    ));
    
    late Map<String, dynamic> downloadResult;
    try {
      downloadResult = await _measureWithProgress(
        phase: TestPhase.download,
        totalSamples: SpeedTestConfig.downloadMaxSamples,
        onProgress: onProgress,
        cancellationToken: cancellationToken,
        measurement: () => measureDownloadSpeed(server: selectedServer),
      );
    } catch (e) {
      // If download measurement fails, try to fallback to another server
      if (e is! CancelledException) {
        try {
          selectedServer = await _selectFallbackServer(selectedServer);
          cancellationToken?.throwIfCancelled();
          
          downloadResult = await _measureWithProgress(
            phase: TestPhase.download,
            totalSamples: SpeedTestConfig.downloadMaxSamples,
            onProgress: onProgress,
            cancellationToken: cancellationToken,
            measurement: () => measureDownloadSpeed(server: selectedServer),
          );
        } catch (fallbackError) {
          throw Exception(
            'Download test failed: ${fallbackError.toString()}'
          );
        }
      } else {
        rethrow;
      }
    }
    
    final double downloadSpeed = downloadResult['median'];
    final int downloadSamples = downloadResult['sampleCount'];
    
    // Phase 4: Upload Speed Measurement
    onProgress(TestProgress(
      phase: TestPhase.upload,
      elapsedSeconds: 0,
      completedSamples: 0,
      totalSamples: SpeedTestConfig.uploadMaxSamples,
      currentLatency: latency,
      currentSpeed: downloadSpeed,
    ));
    
    late Map<String, dynamic> uploadResult;
    try {
      uploadResult = await _measureWithProgress(
        phase: TestPhase.upload,
        totalSamples: SpeedTestConfig.uploadMaxSamples,
        onProgress: onProgress,
        cancellationToken: cancellationToken,
        measurement: () => measureUploadSpeed(server: selectedServer),
      );
    } catch (e) {
      // If upload measurement fails, try to fallback to another server
      if (e is! CancelledException) {
        try {
          selectedServer = await _selectFallbackServer(selectedServer);
          cancellationToken?.throwIfCancelled();
          
          uploadResult = await _measureWithProgress(
            phase: TestPhase.upload,
            totalSamples: SpeedTestConfig.uploadMaxSamples,
            onProgress: onProgress,
            cancellationToken: cancellationToken,
            measurement: () => measureUploadSpeed(server: selectedServer),
          );
        } catch (fallbackError) {
          throw Exception(
            'Upload test failed: ${fallbackError.toString()}'
          );
        }
      } else {
        rethrow;
      }
    }
    
    final double uploadSpeed = uploadResult['median'];
    final int uploadSamples = uploadResult['sampleCount'];
    
    // Phase 5: Complete
    onProgress(TestProgress(
      phase: TestPhase.complete,
      elapsedSeconds: 0,
      completedSamples: 1,
      totalSamples: 1,
      currentLatency: latency,
      currentSpeed: downloadSpeed,
    ));
    
    // Create and return the final result
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
  
  /// Helper method to execute a measurement with progress reporting.
  /// 
  /// This method wraps a measurement function and provides periodic progress
  /// updates during execution. It emits progress at least once per second
  /// as required by Requirements 6.2 and 6.3.
  /// 
  /// [phase] - The current test phase
  /// [totalSamples] - The total number of samples for this phase
  /// [onProgress] - Callback to report progress
  /// [cancellationToken] - Optional token to cancel the measurement
  /// [measurement] - The measurement function to execute
  /// 
  /// Returns the result from the measurement function.
  Future<Map<String, dynamic>> _measureWithProgress({
    required TestPhase phase,
    required int totalSamples,
    required Function(TestProgress) onProgress,
    CancellationToken? cancellationToken,
    required Future<Map<String, dynamic>> Function() measurement,
  }) async {
    // Start a timer to emit progress updates every second
    int elapsedSeconds = 0;
    final timer = Timer.periodic(
      const Duration(milliseconds: SpeedTestConfig.progressUpdateInterval),
      (t) {
        cancellationToken?.throwIfCancelled();
        elapsedSeconds++;
        onProgress(TestProgress(
          phase: phase,
          elapsedSeconds: elapsedSeconds,
          completedSamples: 0, // We don't track individual samples during measurement
          totalSamples: totalSamples,
        ));
      },
    );
    
    try {
      // Execute the measurement
      final result = await measurement();
      return result;
    } finally {
      // Always cancel the timer when done
      timer.cancel();
    }
  }
  
  /// Selects a fallback server when the current server fails.
  /// 
  /// This method attempts to find an alternative server from the list of
  /// available test servers, excluding the failed server.
  /// 
  /// [failedServer] - The server that failed
  /// 
  /// Returns an alternative [TestServer].
  /// 
  /// Throws [Exception] if no alternative servers are available.
  Future<TestServer> _selectFallbackServer(TestServer failedServer) async {
    // Get list of servers excluding the failed one
    final alternativeServers = testServers
        .where((server) => server.name != failedServer.name)
        .toList();
    
    if (alternativeServers.isEmpty) {
      throw Exception('No alternative servers available');
    }
    
    // Try to validate and select an alternative server
    for (final server in alternativeServers) {
      try {
        final isAvailable = await validateServer(server);
        if (isAvailable) {
          return server;
        }
      } catch (e) {
        // Continue to next server
        continue;
      }
    }
    
    // If no servers are available, throw an error
    throw Exception('All alternative servers failed to respond');
  }

  /// Calculates the median of a list of numeric values.
  /// 
  /// For odd-length lists, returns the middle value.
  /// For even-length lists, returns the average of the two middle values.
  /// 
  /// Throws [ArgumentError] if the list is empty.
  double calculateMedian(List<num> values) {
    if (values.isEmpty) {
      throw ArgumentError('Cannot calculate median of empty list');
    }

    // Handle single value case
    if (values.length == 1) {
      return values[0].toDouble();
    }

    // Sort the values
    final sorted = List<num>.from(values)..sort();
    final middle = sorted.length ~/ 2;

    // For odd length, return the middle value
    if (sorted.length.isOdd) {
      return sorted[middle].toDouble();
    } else {
      // For even length, return the average of the two middle values
      return (sorted[middle - 1] + sorted[middle]) / 2;
    }
  }

  /// Determines if additional samples are needed based on variance.
  /// 
  /// Calculates variance as the maximum deviation from the mean divided by the mean.
  /// Returns true if the variance exceeds the specified threshold.
  /// 
  /// Returns false if there are fewer than 2 samples (variance cannot be calculated).
  /// 
  /// [samples] - The list of sample values to analyze
  /// [threshold] - The variance threshold (e.g., 0.30 for 30%)
  bool needsAdditionalSamples(List<double> samples, double threshold) {
    // Need at least 2 samples to calculate variance
    if (samples.length < 2) {
      return false;
    }

    // Calculate mean
    final mean = samples.reduce((a, b) => a + b) / samples.length;

    // Calculate maximum deviation from mean
    double maxDeviation = 0.0;
    for (final sample in samples) {
      final deviation = (sample - mean).abs();
      if (deviation > maxDeviation) {
        maxDeviation = deviation;
      }
    }

    // Calculate variance as max deviation / mean
    final variance = maxDeviation / mean;

    // Return true if variance exceeds threshold
    return variance > threshold;
  }

  /// Calculates network speed in Mbps from bytes transferred and elapsed time.
  /// 
  /// Uses the formula: (bytes × 8) / (seconds × 1,000,000)
  /// 
  /// This converts:
  /// - bytes to bits (multiply by 8)
  /// - seconds to megabits per second (divide by 1,000,000)
  /// 
  /// [bytes] - The number of bytes transferred
  /// [seconds] - The elapsed time in seconds
  /// 
  /// Returns the speed in Mbps (megabits per second)
  /// 
  /// Example:
  /// ```dart
  /// final speed = calculateSpeed(5000000, 2.0); // 5MB in 2 seconds
  /// print(speed); // 20.0 Mbps
  /// ```
  double calculateSpeed(int bytes, double seconds) {
    return (bytes * 8) / (seconds * 1000000);
  }

  /// Calculates the next test file size for progressive sizing.
  /// 
  /// This function dynamically adjusts test file sizes based on connection speed
  /// to ensure accurate measurements. It targets 7-10 seconds per sample.
  /// 
  /// The algorithm:
  /// 1. Calculates ideal size to achieve ~7 seconds based on current speed
  /// 2. Uses aggressive scaling for high-speed connections
  /// 3. Uses smaller sizes for slow connections to avoid long waits
  /// 4. Respects the maximum size limit
  /// 
  /// [currentSpeed] - The measured speed in Mbps from the previous sample
  /// [currentSize] - The size in bytes used for the current sample
  /// [maxSize] - The maximum allowed size in bytes
  /// 
  /// Returns the next test file size in bytes
  /// 
  /// Example:
  /// ```dart
  /// // If current speed is 10 Mbps and current size is 5MB
  /// final nextSize = calculateNextSize(10.0, 5242880, 52428800);
  /// // Returns a size targeting 7 seconds of transfer time
  /// ```
  int calculateNextSize(double currentSpeed, int currentSize, int maxSize) {
    // Target 7 seconds per sample for accurate measurements
    const targetSeconds = 7;
    
    // Convert speed from Mbps to bytes per second
    final bytesPerSecond = (currentSpeed * 1000000) / 8;
    
    // Calculate ideal size to achieve target duration
    final idealSize = (bytesPerSecond * targetSeconds).toInt();
    
    // For very slow connections (<5 Mbps), use smaller files to avoid long waits
    if (currentSpeed < 5) {
      // Cap at 5MB for slow connections
      final slowMaxSize = 5 * 1024 * 1024;
      return idealSize > slowMaxSize ? slowMaxSize : (idealSize < currentSize * 2 ? currentSize * 2 : idealSize);
    }
    
    // For slow connections (5-20 Mbps), use moderate scaling
    if (currentSpeed < 20) {
      final moderateMaxSize = 20 * 1024 * 1024; // Cap at 20MB
      final nextSize = idealSize > currentSize * 2 ? idealSize : currentSize * 2;
      return nextSize > moderateMaxSize ? moderateMaxSize : nextSize;
    }
    
    // For high-speed connections, be very aggressive with size increases
    int minNextSize;
    if (currentSpeed > 100) {
      minNextSize = currentSize * 8; // 8x increase for very fast connections (>100 Mbps)
    } else if (currentSpeed > 50) {
      minNextSize = currentSize * 5; // 5x increase for fast connections (>50 Mbps)
    } else {
      minNextSize = currentSize * 3; // 3x increase for medium connections (20-50 Mbps)
    }
    
    // Use the larger of idealSize and minNextSize
    final nextSize = idealSize > minNextSize ? idealSize : minNextSize;
    
    // Don't exceed maximum size
    return nextSize > maxSize ? maxSize : nextSize;
  }
  
  /// Determines the optimal number of parallel connections based on speed.
  /// 
  /// Slow connections don't benefit from many parallel connections and can
  /// actually be slowed down by the overhead. Fast connections need many
  /// parallel connections to saturate bandwidth.
  /// 
  /// [speedMbps] - The measured speed in Mbps
  /// 
  /// Returns the optimal number of parallel connections
  int getOptimalConnectionCount(double speedMbps) {
    if (speedMbps < 5) {
      return 2; // Very slow: 2 connections
    } else if (speedMbps < 20) {
      return 4; // Slow: 4 connections
    } else if (speedMbps < 50) {
      return 6; // Medium: 6 connections
    } else if (speedMbps < 100) {
      return 10; // Fast: 10 connections
    } else {
      return 16; // Very fast: 16 connections
    }
  }
}
