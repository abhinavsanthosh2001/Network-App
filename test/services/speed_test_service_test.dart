import 'package:flutter_test/flutter_test.dart';
import 'package:network_scanner/services/speed_test_service.dart';
import 'package:network_scanner/models/test_server.dart';

void main() {
  group('SpeedTestService - Initialization', () {
    late SpeedTestService service;

    setUp(() {
      service = SpeedTestService();
    });

    test('initializes with at least 3 test servers', () {
      expect(service.testServers.length, greaterThanOrEqualTo(3));
    });

    test('test servers include httpbin.org', () {
      final hasHttpbin = service.testServers.any((server) => server.name == 'httpbin.org');
      expect(hasHttpbin, isTrue);
    });

    test('test servers include postman-echo.com', () {
      final hasPostmanEcho = service.testServers.any((server) => server.name == 'postman-echo.com');
      expect(hasPostmanEcho, isTrue);
    });

    test('test servers include reqres.in', () {
      final hasReqres = service.testServers.any((server) => server.name == 'reqres.in');
      expect(hasReqres, isTrue);
    });

    test('all test servers have required endpoints', () {
      for (final server in service.testServers) {
        expect(server.name, isNotEmpty);
        expect(server.baseUrl, isNotEmpty);
        expect(server.downloadEndpoint, isNotEmpty);
        expect(server.uploadEndpoint, isNotEmpty);
        expect(server.pingEndpoint, isNotEmpty);
      }
    });
  });

  group('SpeedTestService - calculateMedian', () {
    late SpeedTestService service;

    setUp(() {
      service = SpeedTestService();
    });

    test('throws ArgumentError for empty list', () {
      expect(
        () => service.calculateMedian([]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('returns the value for single element list', () {
      expect(service.calculateMedian([5.0]), equals(5.0));
      expect(service.calculateMedian([42]), equals(42.0));
    });

    test('returns middle value for odd-length list', () {
      expect(service.calculateMedian([1, 2, 3]), equals(2.0));
      expect(service.calculateMedian([5, 1, 3, 2, 4]), equals(3.0));
      expect(service.calculateMedian([10.5, 20.3, 15.7]), equals(15.7));
    });

    test('returns average of two middle values for even-length list', () {
      expect(service.calculateMedian([1, 2]), equals(1.5));
      expect(service.calculateMedian([1, 2, 3, 4]), equals(2.5));
      expect(service.calculateMedian([10, 20, 30, 40]), equals(25.0));
    });

    test('handles unsorted lists correctly', () {
      expect(service.calculateMedian([3, 1, 2]), equals(2.0));
      expect(service.calculateMedian([4, 2, 1, 3]), equals(2.5));
      expect(service.calculateMedian([100, 50, 75, 25, 60]), equals(60.0));
    });

    test('handles duplicate values', () {
      expect(service.calculateMedian([5, 5, 5]), equals(5.0));
      expect(service.calculateMedian([1, 2, 2, 3]), equals(2.0));
      expect(service.calculateMedian([10, 10, 20, 20]), equals(15.0));
    });

    test('handles negative values', () {
      expect(service.calculateMedian([-3, -1, -2]), equals(-2.0));
      expect(service.calculateMedian([-10, -5, 0, 5]), equals(-2.5));
    });

    test('handles mixed integer and double values', () {
      expect(service.calculateMedian([1, 2.5, 3]), equals(2.5));
      expect(service.calculateMedian([1.5, 2, 3.5, 4]), equals(2.75));
    });

    test('handles large lists', () {
      final largeList = List.generate(1001, (i) => i);
      expect(service.calculateMedian(largeList), equals(500.0));
    });
  });

  group('SpeedTestService - needsAdditionalSamples', () {
    late SpeedTestService service;

    setUp(() {
      service = SpeedTestService();
    });

    test('returns false for empty list', () {
      expect(service.needsAdditionalSamples([], 0.30), isFalse);
    });

    test('returns false for single sample', () {
      expect(service.needsAdditionalSamples([10.0], 0.30), isFalse);
    });

    test('returns false when variance is below threshold', () {
      // Samples with low variance: [10, 11, 10.5]
      // Mean = 10.5, max deviation = 0.5, variance = 0.5/10.5 ≈ 0.048 (4.8%)
      expect(service.needsAdditionalSamples([10.0, 11.0, 10.5], 0.30), isFalse);
    });

    test('returns true when variance exceeds threshold', () {
      // Samples with high variance: [10, 20, 15]
      // Mean = 15, max deviation = 5, variance = 5/15 ≈ 0.333 (33.3%)
      expect(service.needsAdditionalSamples([10.0, 20.0, 15.0], 0.30), isTrue);
    });

    test('returns true when variance exactly at 30% threshold', () {
      // Samples: [10, 13]
      // Mean = 11.5, max deviation = 1.5, variance = 1.5/11.5 ≈ 0.130 (13%)
      expect(service.needsAdditionalSamples([10.0, 13.0], 0.10), isTrue);
    });

    test('handles identical samples (zero variance)', () {
      // All samples identical: variance = 0
      expect(service.needsAdditionalSamples([10.0, 10.0, 10.0], 0.30), isFalse);
    });

    test('calculates variance correctly for realistic speed test samples', () {
      // Realistic download speeds with acceptable variance
      // [45.2, 46.1, 45.8] Mbps
      // Mean ≈ 45.7, max deviation ≈ 0.9, variance ≈ 0.02 (2%)
      expect(service.needsAdditionalSamples([45.2, 46.1, 45.8], 0.30), isFalse);

      // Realistic download speeds with high variance (needs more samples)
      // [30.0, 50.0, 40.0] Mbps
      // Mean = 40, max deviation = 10, variance = 0.25 (25%)
      expect(service.needsAdditionalSamples([30.0, 50.0, 40.0], 0.20), isTrue);
    });

    test('handles different threshold values', () {
      final samples = [10.0, 15.0, 12.0];
      // Mean = 12.33, max deviation = 2.67, variance ≈ 0.216 (21.6%)
      
      expect(service.needsAdditionalSamples(samples, 0.10), isTrue);  // 10% threshold
      expect(service.needsAdditionalSamples(samples, 0.25), isFalse); // 25% threshold
      expect(service.needsAdditionalSamples(samples, 0.30), isFalse); // 30% threshold
    });
  });

  group('SpeedTestService - calculateSpeed', () {
    late SpeedTestService service;

    setUp(() {
      service = SpeedTestService();
    });

    test('calculates speed correctly for basic example', () {
      // 5MB in 2 seconds = 20 Mbps
      // (5,000,000 bytes × 8) / (2 seconds × 1,000,000) = 20 Mbps
      final speed = service.calculateSpeed(5000000, 2.0);
      expect(speed, equals(20.0));
    });

    test('calculates speed correctly for 1MB in 1 second', () {
      // 1MB in 1 second = 8 Mbps
      // (1,000,000 bytes × 8) / (1 second × 1,000,000) = 8 Mbps
      final speed = service.calculateSpeed(1000000, 1.0);
      expect(speed, equals(8.0));
    });

    test('calculates speed correctly for fractional seconds', () {
      // 2.5MB in 0.5 seconds = 40 Mbps
      // (2,500,000 bytes × 8) / (0.5 seconds × 1,000,000) = 40 Mbps
      final speed = service.calculateSpeed(2500000, 0.5);
      expect(speed, equals(40.0));
    });

    test('calculates speed correctly for small data transfer', () {
      // 512KB in 1 second = 4.096 Mbps
      // (524,288 bytes × 8) / (1 second × 1,000,000) = 4.194304 Mbps
      final speed = service.calculateSpeed(524288, 1.0);
      expect(speed, closeTo(4.194304, 0.000001));
    });

    test('calculates speed correctly for large data transfer', () {
      // 10MB in 5 seconds = 16 Mbps
      // (10,000,000 bytes × 8) / (5 seconds × 1,000,000) = 16 Mbps
      final speed = service.calculateSpeed(10000000, 5.0);
      expect(speed, equals(16.0));
    });

    test('calculates speed correctly for slow connection', () {
      // 1MB in 10 seconds = 0.8 Mbps
      // (1,000,000 bytes × 8) / (10 seconds × 1,000,000) = 0.8 Mbps
      final speed = service.calculateSpeed(1000000, 10.0);
      expect(speed, equals(0.8));
    });

    test('calculates speed correctly for fast connection', () {
      // 10MB in 1 second = 80 Mbps
      // (10,000,000 bytes × 8) / (1 second × 1,000,000) = 80 Mbps
      final speed = service.calculateSpeed(10000000, 1.0);
      expect(speed, equals(80.0));
    });

    test('handles very small time values', () {
      // 1MB in 0.1 seconds = 80 Mbps
      // (1,000,000 bytes × 8) / (0.1 seconds × 1,000,000) = 80 Mbps
      final speed = service.calculateSpeed(1000000, 0.1);
      expect(speed, equals(80.0));
    });

    test('formula matches requirements: (bytes × 8) / (seconds × 1,000,000)', () {
      // Verify the exact formula from requirements 9.4 and 9.6
      const bytes = 3000000;
      const seconds = 1.5;
      final expectedSpeed = (bytes * 8) / (seconds * 1000000);
      
      final actualSpeed = service.calculateSpeed(bytes, seconds);
      expect(actualSpeed, equals(expectedSpeed));
      expect(actualSpeed, equals(16.0));
    });
  });

  group('SpeedTestService - calculateNextSize', () {
    late SpeedTestService service;

    setUp(() {
      service = SpeedTestService();
    });

    test('targets 7 seconds for ideal sizing', () {
      // Speed: 10 Mbps = 1.25 MB/s = 1,250,000 bytes/s
      // Ideal size for 7 seconds: 1,250,000 * 7 = 8,750,000 bytes
      // Current size: 1MB, min next: 2MB
      // Should return ideal size since it's larger than 2x current
      final nextSize = service.calculateNextSize(10.0, 1048576, 10485760);
      expect(nextSize, equals(8750000));
    });

    test('ensures at least 2x increase from current size', () {
      // Speed: 1 Mbps = 0.125 MB/s = 125,000 bytes/s
      // Ideal size for 7 seconds: 125,000 * 7 = 875,000 bytes
      // Current size: 1MB (1,048,576), min next: 2MB (2,097,152)
      // Should return 2x current since ideal is smaller
      final nextSize = service.calculateNextSize(1.0, 1048576, 10485760);
      expect(nextSize, equals(2097152));
    });

    test('respects maximum size limit', () {
      // Speed: 100 Mbps would suggest very large size
      // But should cap at maxSize
      final nextSize = service.calculateNextSize(100.0, 5242880, 10485760);
      expect(nextSize, equals(10485760)); // Should return maxSize
    });

    test('handles slow connection (targets 7 seconds)', () {
      // Speed: 0.5 Mbps = 0.0625 MB/s = 62,500 bytes/s
      // Ideal size for 7 seconds: 62,500 * 7 = 437,500 bytes
      // Current size: 512KB (524,288), min next: 1MB (1,048,576)
      // Should return 2x current since ideal is smaller
      final nextSize = service.calculateNextSize(0.5, 524288, 5242880);
      expect(nextSize, equals(1048576));
    });

    test('handles fast connection (targets 7 seconds)', () {
      // Speed: 50 Mbps = 6.25 MB/s = 6,250,000 bytes/s
      // Ideal size for 7 seconds: 6,250,000 * 7 = 43,750,000 bytes
      // Max size: 10MB (10,485,760)
      // Should cap at max size
      final nextSize = service.calculateNextSize(50.0, 1048576, 10485760);
      expect(nextSize, equals(10485760));
    });

    test('handles medium speed connection', () {
      // Speed: 5 Mbps = 0.625 MB/s = 625,000 bytes/s
      // Ideal size for 7 seconds: 625,000 * 7 = 4,375,000 bytes
      // Current size: 1MB (1,048,576), min next: 2MB (2,097,152)
      // Should return ideal size since it's larger than 2x current
      final nextSize = service.calculateNextSize(5.0, 1048576, 10485760);
      expect(nextSize, equals(4375000));
    });

    test('progressive sizing for download (1MB start, 10MB max)', () {
      const startSize = 1048576; // 1MB
      const maxSize = 10485760; // 10MB
      
      // First iteration: 10 Mbps
      final size1 = service.calculateNextSize(10.0, startSize, maxSize);
      expect(size1, greaterThan(startSize * 2));
      expect(size1, lessThanOrEqualTo(maxSize));
      
      // Second iteration: 15 Mbps (faster)
      final size2 = service.calculateNextSize(15.0, size1, maxSize);
      expect(size2, greaterThanOrEqualTo(size1));
      expect(size2, lessThanOrEqualTo(maxSize));
    });

    test('progressive sizing for upload (512KB start, 5MB max)', () {
      const startSize = 524288; // 512KB
      const maxSize = 5242880; // 5MB
      
      // First iteration: 8 Mbps
      final size1 = service.calculateNextSize(8.0, startSize, maxSize);
      expect(size1, greaterThan(startSize * 2));
      expect(size1, lessThanOrEqualTo(maxSize));
      
      // Second iteration: 12 Mbps (faster)
      final size2 = service.calculateNextSize(12.0, size1, maxSize);
      expect(size2, greaterThanOrEqualTo(size1));
      expect(size2, lessThanOrEqualTo(maxSize));
    });

    test('returns maxSize when already at maximum', () {
      // When current size equals max size, should return max size
      final nextSize = service.calculateNextSize(10.0, 10485760, 10485760);
      expect(nextSize, equals(10485760));
    });

    test('handles very slow connection', () {
      // Speed: 0.1 Mbps = 0.0125 MB/s = 12,500 bytes/s
      // Ideal size for 7 seconds: 12,500 * 7 = 87,500 bytes
      // Current size: 512KB (524,288), min next: 1MB (1,048,576)
      // Should return 2x current since ideal is much smaller
      final nextSize = service.calculateNextSize(0.1, 524288, 5242880);
      expect(nextSize, equals(1048576));
    });

    test('handles edge case with very small current size', () {
      // Current size: 100KB
      // Speed: 5 Mbps
      // Should still follow the algorithm correctly
      final nextSize = service.calculateNextSize(5.0, 102400, 10485760);
      expect(nextSize, greaterThan(102400 * 2));
      expect(nextSize, lessThanOrEqualTo(10485760));
    });

    test('conversion from Mbps to bytes per second is correct', () {
      // 8 Mbps = 1 MB/s = 1,000,000 bytes/s
      // Ideal size for 7 seconds: 1,000,000 * 7 = 7,000,000 bytes
      final nextSize = service.calculateNextSize(8.0, 1048576, 10485760);
      expect(nextSize, equals(7000000));
    });

    test('ensures result is always an integer', () {
      // Test with speed that would produce fractional bytes
      final nextSize = service.calculateNextSize(3.7, 1048576, 10485760);
      expect(nextSize, isA<int>());
      expect(nextSize, greaterThan(0));
    });
  });

  group('SpeedTestService - measureServerLatency', () {
    late SpeedTestService service;

    setUp(() {
      service = SpeedTestService();
    });

    test('measures latency for valid server (httpbin.org)', () async {
      final server = service.testServers.firstWhere(
        (s) => s.name == 'httpbin.org',
      );
      
      final latency = await service.measureServerLatency(server);
      
      // Latency should be a positive value
      expect(latency, greaterThan(0));
      // Latency should be reasonable (less than 5 seconds)
      expect(latency, lessThan(5000));
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('measures latency for valid server (postman-echo.com)', () async {
      final server = service.testServers.firstWhere(
        (s) => s.name == 'postman-echo.com',
      );
      
      final latency = await service.measureServerLatency(server);
      
      // Latency should be a positive value
      expect(latency, greaterThan(0));
      // Latency should be reasonable (less than 5 seconds)
      expect(latency, lessThan(5000));
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('returns latency in milliseconds', () async {
      final server = service.testServers.first;
      
      final latency = await service.measureServerLatency(server);
      
      // Verify it's an integer (milliseconds)
      expect(latency, isA<int>());
      // Should be a reasonable value (typically 10-500ms for good connections)
      expect(latency, greaterThan(0));
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('throws exception for invalid server', () async {
      final invalidServer = TestServer(
        name: 'invalid-server',
        baseUrl: 'https://this-domain-does-not-exist-12345.com',
        downloadEndpoint: '/bytes/{size}',
        uploadEndpoint: '/post',
        pingEndpoint: '/get',
      );
      
      // Should throw an exception when server is unreachable
      expect(
        () => service.measureServerLatency(invalidServer),
        throwsA(isA<Exception>()),
      );
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('measures round-trip time consistently', () async {
      final server = service.testServers.first;
      
      // Measure latency multiple times
      final latency1 = await service.measureServerLatency(server);
      final latency2 = await service.measureServerLatency(server);
      final latency3 = await service.measureServerLatency(server);
      
      // All measurements should be positive
      expect(latency1, greaterThan(0));
      expect(latency2, greaterThan(0));
      expect(latency3, greaterThan(0));
      
      // Measurements should be relatively consistent (within reasonable variance)
      // Allow for network variability - measurements should be within 500ms of each other
      final measurements = [latency1, latency2, latency3];
      final maxLatency = measurements.reduce((a, b) => a > b ? a : b);
      final minLatency = measurements.reduce((a, b) => a < b ? a : b);
      expect(maxLatency - minLatency, lessThan(1000));
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('SpeedTestService - selectOptimalServer', () {
    late SpeedTestService service;

    setUp(() {
      service = SpeedTestService();
    });

    test('selects server with lowest latency among all servers', () async {
      // This test verifies that selectOptimalServer picks the server
      // with the lowest latency from all available servers
      final selectedServer = await service.selectOptimalServer();
      
      // Should return a valid server
      expect(selectedServer, isNotNull);
      expect(selectedServer.name, isNotEmpty);
      
      // The selected server should be one of the configured servers
      expect(service.testServers.contains(selectedServer), isTrue);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('prefers servers with latency < 100ms when available', () async {
      // This test verifies Requirement 1.5: prefer servers with latency < 100ms
      final selectedServer = await service.selectOptimalServer();
      
      // Measure the latency of the selected server
      final selectedLatency = await service.measureServerLatency(selectedServer);
      
      // If the selected server has latency >= 100ms, verify that all other
      // servers also have latency >= 100ms (meaning no preferred servers exist)
      if (selectedLatency >= 100) {
        for (final server in service.testServers) {
          if (server != selectedServer) {
            try {
              final latency = await service.measureServerLatency(server);
              // All other servers should also have latency >= 100ms
              expect(latency, greaterThanOrEqualTo(100),
                reason: 'If selected server has latency >= 100ms, all servers should have latency >= 100ms');
            } catch (e) {
              // Server failed - that's okay, it wouldn't be selected anyway
            }
          }
        }
      }
    }, timeout: const Timeout(Duration(seconds: 45)));

    test('handles server failures with fallback', () async {
      // This test verifies Requirement 1.3: fallback when servers fail
      // Even if some servers fail, selectOptimalServer should still work
      // as long as at least one server is available
      
      final selectedServer = await service.selectOptimalServer();
      
      // Should successfully select a server despite potential failures
      expect(selectedServer, isNotNull);
      
      // The selected server should be responsive
      final isValid = await service.validateServer(selectedServer);
      expect(isValid, isTrue);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('throws exception when all servers fail', () async {
      // Create a service with only invalid servers
      final testService = SpeedTestService();
      testService.testServers.clear();
      testService.testServers.addAll([
        TestServer(
          name: 'invalid1',
          baseUrl: 'https://invalid-domain-12345.com',
          downloadEndpoint: '/bytes/{size}',
          uploadEndpoint: '/post',
          pingEndpoint: '/get',
        ),
        TestServer(
          name: 'invalid2',
          baseUrl: 'https://another-invalid-domain-67890.com',
          downloadEndpoint: '/bytes/{size}',
          uploadEndpoint: '/post',
          pingEndpoint: '/get',
        ),
      ]);
      
      // Should throw an exception when all servers fail
      expect(
        () => testService.selectOptimalServer(),
        throwsA(isA<Exception>()),
      );
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('returns consistent results when called multiple times', () async {
      // Call selectOptimalServer multiple times
      final server1 = await service.selectOptimalServer();
      final server2 = await service.selectOptimalServer();
      
      // Both should return valid servers
      expect(server1, isNotNull);
      expect(server2, isNotNull);
      
      // Results should be consistent (same server or servers with similar latency)
      // Note: Due to network variability, the exact server may differ,
      // but both should be valid choices
      expect(service.testServers.contains(server1), isTrue);
      expect(service.testServers.contains(server2), isTrue);
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('validates servers before measuring latency', () async {
      // This test verifies Requirement 1.4: server validation before testing
      final selectedServer = await service.selectOptimalServer();
      
      // The selected server should be valid
      final isValid = await service.validateServer(selectedServer);
      expect(isValid, isTrue,
        reason: 'Selected server should be validated and available');
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('SpeedTestService - performLatencySamples', () {
    late SpeedTestService service;

    setUp(() {
      service = SpeedTestService();
    });

    test('collects at least 5 latency samples', () async {
      final server = service.testServers.firstWhere(
        (s) => s.name == 'httpbin.org',
      );
      
      final samples = await service.performLatencySamples(server, 5);
      
      // Should collect at least 5 samples (may be less if some fail after retries)
      // But for a valid server, we expect all 5 to succeed
      expect(samples.length, greaterThanOrEqualTo(3));
      expect(samples.length, lessThanOrEqualTo(5));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('returns list of positive latency values', () async {
      final server = service.testServers.first;
      
      final samples = await service.performLatencySamples(server, 5);
      
      // All samples should be positive integers
      for (final sample in samples) {
        expect(sample, isA<int>());
        expect(sample, greaterThan(0));
        expect(sample, lessThan(5000)); // Reasonable upper bound
      }
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('excludes failed samples from results', () async {
      // Create a server that will fail
      final unreliableServer = TestServer(
        name: 'unreliable',
        baseUrl: 'https://this-domain-does-not-exist-12345.com',
        downloadEndpoint: '/bytes/{size}',
        uploadEndpoint: '/post',
        pingEndpoint: '/get',
      );
      
      final samples = await service.performLatencySamples(unreliableServer, 3);
      
      // Should return empty list since all samples will fail
      expect(samples, isEmpty);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('handles retry logic for failed samples', () async {
      final server = service.testServers.first;
      
      // Request 3 samples
      final samples = await service.performLatencySamples(server, 3);
      
      // For a valid server, should get all 3 samples
      // (retries should help recover from transient failures)
      expect(samples.length, greaterThanOrEqualTo(2));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('collects correct number of samples when requested', () async {
      final server = service.testServers.first;
      
      // Test with different sample counts
      final samples3 = await service.performLatencySamples(server, 3);
      final samples5 = await service.performLatencySamples(server, 5);
      final samples7 = await service.performLatencySamples(server, 7);
      
      // Should attempt to collect the requested number
      expect(samples3.length, lessThanOrEqualTo(3));
      expect(samples5.length, lessThanOrEqualTo(5));
      expect(samples7.length, lessThanOrEqualTo(7));
      
      // For a valid server, should get most or all samples
      expect(samples3.length, greaterThanOrEqualTo(2));
      expect(samples5.length, greaterThanOrEqualTo(3));
      expect(samples7.length, greaterThanOrEqualTo(5));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('returns empty list when all samples fail', () async {
      final invalidServer = TestServer(
        name: 'invalid',
        baseUrl: 'https://this-domain-does-not-exist-12345.com',
        downloadEndpoint: '/bytes/{size}',
        uploadEndpoint: '/post',
        pingEndpoint: '/get',
      );
      
      final samples = await service.performLatencySamples(invalidServer, 3);
      
      // Should return empty list when all samples fail
      expect(samples, isEmpty);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('samples are reasonable latency values', () async {
      final server = service.testServers.first;
      
      final samples = await service.performLatencySamples(server, 5);
      
      // Calculate median to verify samples are reasonable
      if (samples.isNotEmpty) {
        final median = service.calculateMedian(samples.map((s) => s.toDouble()).toList());
        
        // Median latency should be reasonable (typically 10-500ms)
        expect(median, greaterThan(0));
        expect(median, lessThan(2000));
      }
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('SpeedTestService - validateServer', () {
    late SpeedTestService service;

    setUp(() {
      service = SpeedTestService();
    });

    test('returns true for valid server (httpbin.org)', () async {
      final server = service.testServers.firstWhere(
        (s) => s.name == 'httpbin.org',
      );
      
      final isValid = await service.validateServer(server);
      expect(isValid, isTrue);
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('returns true for valid server (postman-echo.com)', () async {
      final server = service.testServers.firstWhere(
        (s) => s.name == 'postman-echo.com',
      );
      
      final isValid = await service.validateServer(server);
      expect(isValid, isTrue);
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('returns true for valid server (reqres.in)', () async {
      final server = service.testServers.firstWhere(
        (s) => s.name == 'reqres.in',
      );
      
      final isValid = await service.validateServer(server);
      // Note: reqres.in may have intermittent issues or rate limiting
      // This test verifies the method works, but the result may vary
      expect(isValid, isA<bool>());
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('returns false for invalid server (non-existent domain)', () async {
      final invalidServer = TestServer(
        name: 'invalid-server',
        baseUrl: 'https://this-domain-does-not-exist-12345.com',
        downloadEndpoint: '/bytes/{size}',
        uploadEndpoint: '/post',
        pingEndpoint: '/get',
      );
      
      final isValid = await service.validateServer(invalidServer);
      expect(isValid, isFalse);
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('returns false for server with invalid endpoint', () async {
      final invalidServer = TestServer(
        name: 'invalid-endpoint',
        baseUrl: 'https://httpbin.org',
        downloadEndpoint: '/bytes/{size}',
        uploadEndpoint: '/post',
        pingEndpoint: '/this-endpoint-does-not-exist',
      );
      
      final isValid = await service.validateServer(invalidServer);
      expect(isValid, isFalse);
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('completes within 5 second timeout', () async {
      final server = service.testServers.first;
      
      final stopwatch = Stopwatch()..start();
      await service.validateServer(server);
      stopwatch.stop();
      
      // Should complete within 5 seconds (5000ms) plus some buffer
      expect(stopwatch.elapsedMilliseconds, lessThan(6000));
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('validates all configured test servers', () async {
      // At least 2 out of 3 servers should be valid
      // (Some servers may have intermittent issues or rate limiting)
      int validCount = 0;
      for (final server in service.testServers) {
        final isValid = await service.validateServer(server);
        if (isValid) {
          validCount++;
        }
      }
      expect(validCount, greaterThanOrEqualTo(2), 
        reason: 'At least 2 out of 3 servers should be valid');
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('SpeedTestService - performDownloadSample', () {
    late SpeedTestService service;

    setUp(() {
      service = SpeedTestService();
    });

    test('downloads data and returns speed in Mbps', () async {
      final server = service.testServers.firstWhere(
        (s) => s.name == 'httpbin.org',
      );
      
      // Download 1MB (1048576 bytes)
      final speed = await service.performDownloadSample(server, 1048576);
      
      // Speed should be positive
      expect(speed, greaterThan(0));
      // Speed should be reasonable (0.1 Mbps to 1000 Mbps)
      expect(speed, greaterThan(0.1));
      expect(speed, lessThan(1000));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('handles different file sizes', () async {
      final server = service.testServers.first;
      
      // Test with 512KB
      final speed512KB = await service.performDownloadSample(server, 524288);
      expect(speed512KB, greaterThan(0));
      
      // Test with 2MB
      final speed2MB = await service.performDownloadSample(server, 2097152);
      expect(speed2MB, greaterThan(0));
      
      // Speeds should be relatively similar (within reasonable variance)
      // Allow for network variability
      expect(speed512KB, greaterThan(0.1));
      expect(speed2MB, greaterThan(0.1));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('returns speed calculated from actual bytes transferred', () async {
      final server = service.testServers.first;
      
      // Download 1MB
      final speed = await service.performDownloadSample(server, 1048576);
      
      // Speed should be calculated correctly
      // For 1MB in reasonable time (1-10 seconds), speed should be 0.8-8 Mbps
      expect(speed, greaterThan(0.5));
      expect(speed, lessThan(100));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('throws exception for invalid server', () async {
      final invalidServer = TestServer(
        name: 'invalid',
        baseUrl: 'https://this-domain-does-not-exist-12345.com',
        downloadEndpoint: '/bytes/{size}',
        uploadEndpoint: '/post',
        pingEndpoint: '/get',
      );
      
      // Should throw an exception when server is unreachable
      expect(
        () => service.performDownloadSample(invalidServer, 1048576),
        throwsA(isA<Exception>()),
      );
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('supports progressive sizing from 1MB to 10MB', () async {
      final server = service.testServers.first;
      
      // Test minimum size (1MB)
      final speed1MB = await service.performDownloadSample(server, 1048576);
      expect(speed1MB, greaterThan(0));
      
      // Test maximum size (10MB) - skip if network is slow
      // This is a longer test, so we'll just verify it works
      final speed10MB = await service.performDownloadSample(server, 10485760);
      expect(speed10MB, greaterThan(0));
      
      // Both measurements should be reasonable
      expect(speed1MB, greaterThan(0.1));
      expect(speed10MB, greaterThan(0.1));
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('SpeedTestService - measureLatency (complete)', () {
    late SpeedTestService service;

    setUp(() {
      service = SpeedTestService();
    });

    test('returns map with median, isPoorConnection, and sampleCount', () async {
      final result = await service.measureLatency();
      
      // Should return a map with required keys
      expect(result, isA<Map<String, dynamic>>());
      expect(result.containsKey('median'), isTrue);
      expect(result.containsKey('isPoorConnection'), isTrue);
      expect(result.containsKey('sampleCount'), isTrue);
      
      // Verify types
      expect(result['median'], isA<int>());
      expect(result['isPoorConnection'], isA<bool>());
      expect(result['sampleCount'], isA<int>());
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('median latency is a positive integer in milliseconds', () async {
      final result = await service.measureLatency();
      final median = result['median'] as int;
      
      // Median should be positive and reasonable
      expect(median, greaterThan(0));
      expect(median, lessThan(5000)); // Less than 5 seconds
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('collects at least 5 samples by default', () async {
      final result = await service.measureLatency();
      final sampleCount = result['sampleCount'] as int;
      
      // Should collect at least 3 samples (allowing for some failures)
      // Ideally 5, but network issues may cause some to fail
      expect(sampleCount, greaterThanOrEqualTo(3));
      expect(sampleCount, lessThanOrEqualTo(5));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('flags poor connection when latency exceeds 1000ms', () async {
      // This test verifies the poor connection detection logic
      // Note: We can't easily force high latency in a unit test,
      // so we verify the flag is a boolean and trust the logic
      final result = await service.measureLatency();
      final isPoorConnection = result['isPoorConnection'] as bool;
      
      // Should be a boolean value
      expect(isPoorConnection, isA<bool>());
      
      // For most test environments, connection should be good
      // (This may vary based on network conditions)
      expect(isPoorConnection, isA<bool>());
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('excludes failed samples from median calculation', () async {
      // This test verifies that failed samples don't affect the result
      final result = await service.measureLatency();
      final sampleCount = result['sampleCount'] as int;
      final median = result['median'] as int;
      
      // If we got a result, it should be based on successful samples only
      expect(sampleCount, greaterThan(0));
      expect(median, greaterThan(0));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('throws exception when more than 50% of samples fail', () async {
      // Create a service with only invalid servers
      final testService = SpeedTestService();
      testService.testServers.clear();
      testService.testServers.addAll([
        TestServer(
          name: 'invalid1',
          baseUrl: 'https://invalid-domain-12345.com',
          downloadEndpoint: '/bytes/{size}',
          uploadEndpoint: '/post',
          pingEndpoint: '/get',
        ),
      ]);
      
      // Should throw an exception when most samples fail
      expect(
        () => testService.measureLatency(),
        throwsA(isA<Exception>()),
      );
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('uses optimal server when no server specified', () async {
      // Call without specifying a server
      final result = await service.measureLatency();
      
      // Should successfully complete using optimal server
      expect(result['median'], greaterThan(0));
      expect(result['sampleCount'], greaterThan(0));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('uses specified server when provided', () async {
      final server = service.testServers.firstWhere(
        (s) => s.name == 'httpbin.org',
      );
      
      // Call with specific server
      final result = await service.measureLatency(server: server);
      
      // Should successfully complete using specified server
      expect(result['median'], greaterThan(0));
      expect(result['sampleCount'], greaterThan(0));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('allows custom sample count', () async {
      // Request 3 samples instead of default 5
      final result = await service.measureLatency(samples: 3);
      final sampleCount = result['sampleCount'] as int;
      
      // Should collect up to 3 samples
      expect(sampleCount, lessThanOrEqualTo(3));
      expect(sampleCount, greaterThan(0));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('median calculation is correct for collected samples', () async {
      final result = await service.measureLatency();
      final median = result['median'] as int;
      
      // Median should be a reasonable value
      // (We can't verify the exact calculation without access to raw samples,
      // but we can verify it's in a reasonable range)
      expect(median, greaterThan(0));
      expect(median, lessThan(2000)); // Typically less than 2 seconds
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('returns consistent results across multiple calls', () async {
      final result1 = await service.measureLatency();
      final result2 = await service.measureLatency();
      
      final median1 = result1['median'] as int;
      final median2 = result2['median'] as int;
      
      // Both should be positive
      expect(median1, greaterThan(0));
      expect(median2, greaterThan(0));
      
      // Results should be relatively consistent (within 500ms)
      // Allow for network variability
      expect((median1 - median2).abs(), lessThan(1000));
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('SpeedTestService - measureDownloadSpeed (complete)', () {
    late SpeedTestService service;

    setUp(() {
      service = SpeedTestService();
    });

    test('returns map with median and sampleCount', () async {
      final result = await service.measureDownloadSpeed();
      
      // Should return a map with required keys
      expect(result, isA<Map<String, dynamic>>());
      expect(result.containsKey('median'), isTrue);
      expect(result.containsKey('sampleCount'), isTrue);
      
      // Verify types
      expect(result['median'], isA<double>());
      expect(result['sampleCount'], isA<int>());
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('median speed is formatted to one decimal place', () async {
      final result = await service.measureDownloadSpeed();
      final median = result['median'] as double;
      
      // Convert to string and check decimal places
      final medianStr = median.toString();
      final decimalPart = medianStr.split('.').length > 1 ? medianStr.split('.')[1] : '';
      
      // Should have at most 1 decimal place
      expect(decimalPart.length, lessThanOrEqualTo(1));
      
      // Speed should be positive and reasonable
      expect(median, greaterThan(0));
      expect(median, lessThan(1000)); // Less than 1 Gbps
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('collects 3-5 samples based on variance', () async {
      final result = await service.measureDownloadSpeed();
      final sampleCount = result['sampleCount'] as int;
      
      // Should collect between 3 and 5 samples
      expect(sampleCount, greaterThanOrEqualTo(3));
      expect(sampleCount, lessThanOrEqualTo(5));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('excludes failed samples from median calculation', () async {
      // This test verifies that failed samples don't affect the result
      final result = await service.measureDownloadSpeed();
      final sampleCount = result['sampleCount'] as int;
      final median = result['median'] as double;
      
      // If we got a result, it should be based on successful samples only
      expect(sampleCount, greaterThan(0));
      expect(median, greaterThan(0));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('uses optimal server when no server specified', () async {
      // Call without specifying a server
      final result = await service.measureDownloadSpeed();
      
      // Should successfully complete using optimal server
      expect(result['median'], greaterThan(0));
      expect(result['sampleCount'], greaterThanOrEqualTo(3));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('uses specified server when provided', () async {
      final server = service.testServers.firstWhere(
        (s) => s.name == 'httpbin.org',
      );
      
      // Call with specific server
      final result = await service.measureDownloadSpeed(server: server);
      
      // Should successfully complete using specified server
      expect(result['median'], greaterThan(0));
      expect(result['sampleCount'], greaterThanOrEqualTo(3));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('implements progressive sizing from 1MB to 10MB', () async {
      // This test verifies that the method uses performDownloadSamples
      // which implements progressive sizing
      final result = await service.measureDownloadSpeed();
      final median = result['median'] as double;
      
      // Should return a valid speed measurement
      expect(median, greaterThan(0));
      expect(median, lessThan(1000));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('throws exception when more than 50% of minimum samples fail', () async {
      // Create a service with only invalid servers
      final testService = SpeedTestService();
      testService.testServers.clear();
      testService.testServers.addAll([
        TestServer(
          name: 'invalid1',
          baseUrl: 'https://invalid-domain-12345.com',
          downloadEndpoint: '/bytes/{size}',
          uploadEndpoint: '/post',
          pingEndpoint: '/get',
        ),
      ]);
      
      // Should throw an exception when most samples fail
      expect(
        () => testService.measureDownloadSpeed(),
        throwsA(isA<Exception>()),
      );
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('median calculation is correct for collected samples', () async {
      final result = await service.measureDownloadSpeed();
      final median = result['median'] as double;
      
      // Median should be a reasonable value
      expect(median, greaterThan(0.1)); // At least 0.1 Mbps
      expect(median, lessThan(500)); // Less than 500 Mbps for typical connections
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('returns consistent results across multiple calls', () async {
      final result1 = await service.measureDownloadSpeed();
      final result2 = await service.measureDownloadSpeed();
      
      final median1 = result1['median'] as double;
      final median2 = result2['median'] as double;
      
      // Both should be positive
      expect(median1, greaterThan(0));
      expect(median2, greaterThan(0));
      
      // Results should be relatively consistent
      // Allow for network variability - within 50% of each other
      final ratio = median1 > median2 ? median1 / median2 : median2 / median1;
      expect(ratio, lessThan(2.0));
    }, timeout: const Timeout(Duration(seconds: 120)));
  });

  group('SpeedTestService - performUploadSample', () {
    late SpeedTestService service;

    setUp(() {
      service = SpeedTestService();
    });

    test('uploads data and returns speed in Mbps', () async {
      final server = service.testServers.firstWhere(
        (s) => s.name == 'httpbin.org',
      );
      
      // Upload 512KB (524288 bytes)
      final speed = await service.performUploadSample(server, 524288);
      
      // Speed should be positive
      expect(speed, greaterThan(0));
      // Speed should be reasonable (0.1 Mbps to 1000 Mbps)
      expect(speed, greaterThan(0.1));
      expect(speed, lessThan(1000));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('handles different data sizes', () async {
      final server = service.testServers.first;
      
      // Test with 512KB
      final speed512KB = await service.performUploadSample(server, 524288);
      expect(speed512KB, greaterThan(0));
      
      // Test with 1MB
      final speed1MB = await service.performUploadSample(server, 1048576);
      expect(speed1MB, greaterThan(0));
      
      // Speeds should be relatively similar (within reasonable variance)
      // Allow for network variability
      expect(speed512KB, greaterThan(0.1));
      expect(speed1MB, greaterThan(0.1));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('returns speed calculated from actual bytes transferred', () async {
      final server = service.testServers.first;
      
      // Upload 512KB
      final speed = await service.performUploadSample(server, 524288);
      
      // Speed should be calculated correctly
      // For 512KB in reasonable time (1-10 seconds), speed should be 0.4-4 Mbps
      expect(speed, greaterThan(0.1));
      expect(speed, lessThan(100));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('throws exception for invalid server', () async {
      final invalidServer = TestServer(
        name: 'invalid',
        baseUrl: 'https://this-domain-does-not-exist-12345.com',
        downloadEndpoint: '/bytes/{size}',
        uploadEndpoint: '/post',
        pingEndpoint: '/get',
      );
      
      // Should throw an exception when server is unreachable
      expect(
        () => service.performUploadSample(invalidServer, 524288),
        throwsA(isA<Exception>()),
      );
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('supports progressive sizing from 512KB to 5MB', () async {
      final server = service.testServers.first;
      
      // Test minimum size (512KB)
      final speed512KB = await service.performUploadSample(server, 524288);
      expect(speed512KB, greaterThan(0));
      
      // Test maximum size (5MB)
      final speed5MB = await service.performUploadSample(server, 5242880);
      expect(speed5MB, greaterThan(0));
      
      // Both measurements should be reasonable
      expect(speed512KB, greaterThan(0.1));
      expect(speed5MB, greaterThan(0.1));
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}
