import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_scanner/models/scan_state.dart';
import 'package:network_scanner/models/scan_progress.dart';
import 'package:network_scanner/providers/device_scanner_provider.dart';
import 'package:network_scanner/services/device_scanner_service.dart';
import 'package:network_scanner/services/network_service.dart';

/// Mock NetworkService for testing
class MockNetworkService extends NetworkService {
  Map<String, String?>? _mockNetworkInfo;
  Exception? _mockException;

  void setMockNetworkInfo(Map<String, String?> info) {
    _mockNetworkInfo = info;
    _mockException = null;
  }

  void setMockException(Exception exception) {
    _mockException = exception;
    _mockNetworkInfo = null;
  }

  @override
  Future<Map<String, String?>> getNetworkInfo() async {
    if (_mockException != null) {
      throw _mockException!;
    }
    return _mockNetworkInfo ?? {};
  }
}

/// Mock DeviceScannerService for testing
class MockDeviceScannerService extends DeviceScannerService {
  MockDeviceScannerService() : super();

  @override
  Stream<ScanProgress> scanSubnet(String ipAddress, String subnetMask) async* {
    // Return empty stream for testing
    yield ScanProgress(
      totalAddresses: 0,
      scannedAddresses: 0,
      isComplete: true,
    );
  }
}

void main() {
  group('ScanStateNotifier Error Handling', () {
    late MockDeviceScannerService mockScannerService;
    late MockNetworkService mockNetworkService;
    late ScanStateNotifier notifier;

    setUp(() {
      mockScannerService = MockDeviceScannerService();
      mockNetworkService = MockNetworkService();
      notifier = ScanStateNotifier(mockScannerService, mockNetworkService);
    });

    tearDown(() {
      notifier.dispose();
    });

    test('should handle permission denied error', () async {
      // Arrange
      mockNetworkService.setMockNetworkInfo({
        'ssid': 'Permission denied',
        'ip': null,
        'gateway': null,
        'subnet': null,
      });

      // Act
      await notifier.startScan();

      // Assert
      expect(notifier.state.status, ScanStatus.error);
      expect(
        notifier.state.errorMessage,
        contains('Location permission required'),
      );
      expect(notifier.state.errorMessage, contains('grant location permission'));
    });

    test('should handle Wi-Fi not connected error', () async {
      // Arrange
      mockNetworkService.setMockNetworkInfo({
        'ssid': 'MyNetwork',
        'ip': null,
        'gateway': null,
        'subnet': null,
      });

      // Act
      await notifier.startScan();

      // Assert
      expect(notifier.state.status, ScanStatus.error);
      expect(
        notifier.state.errorMessage,
        contains('Wi-Fi connection required'),
      );
      expect(notifier.state.errorMessage, contains('connect to a Wi-Fi network'));
    });

    test('should handle network info retrieval error', () async {
      // Arrange
      mockNetworkService.setMockNetworkInfo({
        'ssid': 'Error: Network interface not found',
        'ip': null,
        'gateway': null,
        'subnet': null,
      });

      // Act
      await notifier.startScan();

      // Assert
      expect(notifier.state.status, ScanStatus.error);
      expect(
        notifier.state.errorMessage,
        contains('Failed to retrieve network information'),
      );
      expect(notifier.state.errorMessage, contains('check your network connection'));
    });

    test('should handle exception during scan initialization', () async {
      // Arrange
      mockNetworkService.setMockException(
        Exception('Network service unavailable'),
      );

      // Act
      await notifier.startScan();

      // Assert
      expect(notifier.state.status, ScanStatus.error);
      expect(
        notifier.state.errorMessage,
        contains('Failed to start scan'),
      );
      expect(notifier.state.errorMessage, contains('Network service unavailable'));
    });

    test('should provide actionable error messages', () async {
      // Test that all error messages provide guidance
      final errorScenarios = [
        {
          'networkInfo': {
            'ssid': 'Permission denied',
            'ip': null,
            'gateway': null,
            'subnet': null,
          },
          'expectedGuidance': 'grant location permission in settings',
        },
        {
          'networkInfo': {
            'ssid': 'MyNetwork',
            'ip': null,
            'gateway': null,
            'subnet': null,
          },
          'expectedGuidance': 'connect to a Wi-Fi network and try again',
        },
        {
          'networkInfo': {
            'ssid': 'Error: Something went wrong',
            'ip': null,
            'gateway': null,
            'subnet': null,
          },
          'expectedGuidance': 'check your network connection',
        },
      ];

      for (final scenario in errorScenarios) {
        // Arrange
        mockNetworkService.setMockNetworkInfo(
          scenario['networkInfo'] as Map<String, String?>,
        );

        // Act
        await notifier.startScan();

        // Assert
        expect(notifier.state.status, ScanStatus.error);
        expect(
          notifier.state.errorMessage,
          contains(scenario['expectedGuidance'] as String),
          reason: 'Error message should provide actionable guidance',
        );

        // Reset for next iteration
        notifier = ScanStateNotifier(mockScannerService, mockNetworkService);
      }
    });
  });
}
