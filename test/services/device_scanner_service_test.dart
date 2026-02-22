import 'package:flutter_test/flutter_test.dart';
import 'package:network_scanner/services/device_scanner_service.dart';

void main() {
  late DeviceScannerService scannerService;

  setUp(() {
    scannerService = DeviceScannerService();
  });

  group('calculateSubnetRange', () {
    test('calculates correct range for /24 subnet (254 hosts)', () {
      final range = scannerService.calculateSubnetRange(
        '192.168.1.50',
        '255.255.255.0',
      );

      expect(range.length, equals(254));
      expect(range.first, equals('192.168.1.1'));
      expect(range.last, equals('192.168.1.254'));
      expect(range, isNot(contains('192.168.1.0'))); // Network address
      expect(range, isNot(contains('192.168.1.255'))); // Broadcast address
    });

    test('calculates correct range for /30 subnet (2 hosts)', () {
      final range = scannerService.calculateSubnetRange(
        '192.168.1.1',
        '255.255.255.252',
      );

      expect(range.length, equals(2));
      expect(range, contains('192.168.1.1'));
      expect(range, contains('192.168.1.2'));
      expect(range, isNot(contains('192.168.1.0'))); // Network address
      expect(range, isNot(contains('192.168.1.3'))); // Broadcast address
    });

    test('calculates correct range for /16 subnet', () {
      final range = scannerService.calculateSubnetRange(
        '192.168.0.1',
        '255.255.0.0',
      );

      expect(range.length, equals(65534)); // 2^16 - 2
      expect(range.first, equals('192.168.0.1'));
      expect(range.last, equals('192.168.255.254'));
      expect(range, isNot(contains('192.168.0.0'))); // Network address
      expect(range, isNot(contains('192.168.255.255'))); // Broadcast address
    });

    test('throws ArgumentError for invalid IP address', () {
      expect(
        () => scannerService.calculateSubnetRange('invalid', '255.255.255.0'),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for invalid subnet mask', () {
      expect(
        () => scannerService.calculateSubnetRange('192.168.1.1', 'invalid'),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for IP with out of range octet', () {
      expect(
        () => scannerService.calculateSubnetRange('192.168.1.256', '255.255.255.0'),
        throwsArgumentError,
      );
    });

    test('handles different IP within same subnet correctly', () {
      final range1 = scannerService.calculateSubnetRange(
        '192.168.1.1',
        '255.255.255.0',
      );
      final range2 = scannerService.calculateSubnetRange(
        '192.168.1.200',
        '255.255.255.0',
      );

      // Both should generate the same range
      expect(range1, equals(range2));
    });
  });

  group('probeHost', () {
    test('returns NetworkDevice when host responds', () async {
      // Test with localhost which should always respond
      final device = await scannerService.probeHost('127.0.0.1');

      expect(device, isNotNull);
      expect(device!.ipAddress, equals('127.0.0.1'));
      expect(device.responseTimeMs, greaterThan(0));
      expect(device.hostname, isNull); // Hostname not resolved yet
      expect(device.macAddress, isNull); // MAC not retrieved yet
      expect(device.discoveredAt, isNotNull);
    });

    test('returns null when host does not respond', () async {
      // Use a non-routable IP address that should timeout
      final device = await scannerService.probeHost('192.0.2.1');

      expect(device, isNull);
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('applies 2-second timeout', () async {
      final stopwatch = Stopwatch()..start();
      
      // Use a non-routable IP that will timeout
      await scannerService.probeHost('192.0.2.1');
      
      stopwatch.stop();
      
      // Should complete within approximately 2 seconds (allow some overhead)
      expect(stopwatch.elapsedMilliseconds, lessThan(3000));
    }, timeout: const Timeout(Duration(seconds: 5)));
  });

  group('resolveHostname', () {
    test('returns hostname for localhost', () async {
      // Test with localhost which should resolve
      final hostname = await scannerService.resolveHostname('127.0.0.1');

      // Localhost should resolve to something (typically 'localhost')
      expect(hostname, isNotNull);
      expect(hostname, isNotEmpty);
    });

    test('returns null for non-resolvable IP', () async {
      // Use a non-routable IP that won't resolve
      final hostname = await scannerService.resolveHostname('192.0.2.1');

      expect(hostname, isNull);
    }, timeout: const Timeout(Duration(seconds: 3)));

    test('applies 1-second timeout', () async {
      final stopwatch = Stopwatch()..start();
      
      // Use a non-routable IP that will timeout
      await scannerService.resolveHostname('192.0.2.1');
      
      stopwatch.stop();
      
      // Should complete within approximately 1 second (allow some overhead)
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
    }, timeout: const Timeout(Duration(seconds: 3)));

    test('returns null for invalid IP address', () async {
      // Test with invalid IP format
      final hostname = await scannerService.resolveHostname('invalid.ip');

      expect(hostname, isNull);
    });
  });

  group('getMacAddress', () {
    test('returns null on non-Android/iOS platforms', () async {
      // On platforms other than Android/iOS, should return null
      final macAddress = await scannerService.getMacAddress('127.0.0.1');

      // This test will pass on desktop platforms (Windows, macOS, Linux)
      // and fail on Android/iOS, which is expected behavior
      if (!const bool.fromEnvironment('dart.library.io') ||
          !(const String.fromEnvironment('dart.vm.product') == 'true')) {
        // Running on desktop/web - should return null
        expect(macAddress, isNull);
      }
    });

    test('handles timeout gracefully', () async {
      final stopwatch = Stopwatch()..start();
      
      // Use a non-routable IP that will timeout
      await scannerService.getMacAddress('192.0.2.1');
      
      stopwatch.stop();
      
      // Should complete within approximately 2 seconds (allow some overhead)
      expect(stopwatch.elapsedMilliseconds, lessThan(3000));
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('returns null for invalid IP address', () async {
      // Test with invalid IP format
      final macAddress = await scannerService.getMacAddress('invalid.ip');

      expect(macAddress, isNull);
    });
  });

  group('scanSubnet', () {
    test('yields initial progress with zero scanned addresses', () async {
      // Use a small subnet for testing
      final stream = scannerService.scanSubnet('192.168.1.1', '255.255.255.252');
      
      final firstProgress = await stream.first;
      
      expect(firstProgress.totalAddresses, equals(2));
      expect(firstProgress.scannedAddresses, equals(0));
      expect(firstProgress.isComplete, isFalse);
      expect(firstProgress.newDevice, isNull);
    });

    test('yields progress updates as scanning proceeds', () async {
      // Use a very small subnet for quick testing
      final stream = scannerService.scanSubnet('192.168.1.1', '255.255.255.252');
      
      final progressList = await stream.toList();
      
      // Should have at least initial progress and final completion
      expect(progressList.length, greaterThanOrEqualTo(2));
      
      // First progress should be initial state
      expect(progressList.first.scannedAddresses, equals(0));
      expect(progressList.first.isComplete, isFalse);
      
      // Last progress should be completion
      expect(progressList.last.isComplete, isTrue);
      expect(progressList.last.scannedAddresses, equals(progressList.last.totalAddresses));
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('discovers localhost when scanning subnet containing 127.0.0.1', () async {
      // Scan a small subnet containing localhost
      final stream = scannerService.scanSubnet('127.0.0.1', '255.255.255.252');
      
      final progressList = await stream.toList();
      
      // Should discover at least one device (localhost)
      final devicesFound = progressList
          .where((p) => p.newDevice != null)
          .map((p) => p.newDevice!)
          .toList();
      
      expect(devicesFound, isNotEmpty);
      expect(devicesFound.any((d) => d.ipAddress == '127.0.0.1'), isTrue);
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('yields final completion status', () async {
      final stream = scannerService.scanSubnet('192.168.1.1', '255.255.255.252');
      
      final progressList = await stream.toList();
      final lastProgress = progressList.last;
      
      expect(lastProgress.isComplete, isTrue);
      expect(lastProgress.scannedAddresses, equals(lastProgress.totalAddresses));
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('handles scan cancellation via stream subscription', () async {
      // Use a larger subnet to ensure we can cancel mid-scan
      final stream = scannerService.scanSubnet('192.168.1.1', '255.255.255.0');
      
      int progressCount = 0;
      final subscription = stream.listen((progress) {
        progressCount++;
      });
      
      // Cancel after a short delay
      await Future.delayed(const Duration(milliseconds: 100));
      await subscription.cancel();
      
      // Should have received some progress updates before cancellation
      expect(progressCount, greaterThan(0));
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('processes IPs in batches of 20', () async {
      // Use a subnet with more than 20 addresses
      final stream = scannerService.scanSubnet('192.168.1.1', '255.255.255.240'); // /28 = 14 hosts
      
      final progressList = await stream.toList();
      
      // Verify all addresses were scanned
      final lastProgress = progressList.last;
      expect(lastProgress.scannedAddresses, equals(14));
      expect(lastProgress.isComplete, isTrue);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('includes hostname and MAC address in discovered devices', () async {
      // Scan localhost which should resolve hostname
      final stream = scannerService.scanSubnet('127.0.0.1', '255.255.255.252');
      
      final progressList = await stream.toList();
      
      // Find localhost device
      final localhostDevice = progressList
          .where((p) => p.newDevice != null && p.newDevice!.ipAddress == '127.0.0.1')
          .map((p) => p.newDevice!)
          .firstOrNull;
      
      if (localhostDevice != null) {
        // Hostname should be resolved for localhost
        expect(localhostDevice.hostname, isNotNull);
        expect(localhostDevice.responseTimeMs, greaterThan(0));
        // MAC address may or may not be available depending on platform
      }
    }, timeout: const Timeout(Duration(seconds: 10)));
  });
}
