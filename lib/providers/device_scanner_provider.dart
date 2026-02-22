import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/scan_state.dart';
import '../models/scan_progress.dart';
import '../services/device_scanner_service.dart';
import '../services/network_service.dart';
import 'network_provider.dart';

/// Provider for DeviceScannerService instance
final deviceScannerServiceProvider = Provider<DeviceScannerService>((ref) {
  return DeviceScannerService();
});

/// StateNotifier for managing scan state
class ScanStateNotifier extends StateNotifier<ScanState> {
  final DeviceScannerService _scannerService;
  final NetworkService _networkService;
  StreamSubscription<ScanProgress>? _scanSubscription;

  ScanStateNotifier(this._scannerService, this._networkService)
      : super(const ScanState(status: ScanStatus.idle));

  /// Start a new network scan
  /// Validates network connection and initiates subnet scan
  Future<void> startScan() async {
    try {
      // Get network info
      final networkInfo = await _networkService.getNetworkInfo();

      // Check for permission errors
      if (networkInfo['ssid'] == 'Permission denied') {
        state = state.copyWith(
          status: ScanStatus.error,
          errorMessage:
              'Location permission required. Please grant location permission in settings to scan network devices.',
        );
        return;
      }

      // Check for network info retrieval errors
      if (networkInfo['ssid']?.startsWith('Error:') == true) {
        state = state.copyWith(
          status: ScanStatus.error,
          errorMessage:
              'Failed to retrieve network information: ${networkInfo['ssid']}. Please check your network connection.',
        );
        return;
      }

      // Validate Wi-Fi connection
      if (networkInfo['ip'] == null || networkInfo['subnet'] == null) {
        state = state.copyWith(
          status: ScanStatus.error,
          errorMessage:
              'Wi-Fi connection required. Please connect to a Wi-Fi network and try again.',
        );
        return;
      }

      // Clear previous results and set status to scanning
      state = const ScanState(status: ScanStatus.scanning);

      // Start subnet scan
      _scanSubscription = _scannerService
          .scanSubnet(networkInfo['ip']!, networkInfo['subnet']!)
          .listen(
        (progress) {
          // Update state with progress
          if (progress.newDevice != null) {
            // Add newly discovered device to the list
            final updatedDevices = List.of(state.devices)
              ..add(progress.newDevice!);

            state = state.copyWith(
              totalAddresses: progress.totalAddresses,
              scannedAddresses: progress.scannedAddresses,
              devices: updatedDevices,
            );
          } else {
            // Update progress without adding a device
            state = state.copyWith(
              totalAddresses: progress.totalAddresses,
              scannedAddresses: progress.scannedAddresses,
            );
          }
        },
        onError: (error) {
          // Handle scanning errors
          state = state.copyWith(
            status: ScanStatus.error,
            errorMessage:
                'Scanning error occurred: ${error.toString()}. Please try again.',
          );
        },
        onDone: () {
          state = state.copyWith(status: ScanStatus.completed);
        },
      );
    } catch (e) {
      // Handle unexpected errors during scan initialization
      state = state.copyWith(
        status: ScanStatus.error,
        errorMessage:
            'Failed to start scan: ${e.toString()}. Please check your network connection and try again.',
      );
    }
  }

  /// Stop the current scan
  /// Cancels ongoing scan and preserves discovered devices
  void stopScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;

    if (state.status == ScanStatus.scanning) {
      state = state.copyWith(status: ScanStatus.stopped);
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }
}

/// StateNotifierProvider for scan state management
final scanStateProvider =
    StateNotifierProvider<ScanStateNotifier, ScanState>((ref) {
  final scannerService = ref.read(deviceScannerServiceProvider);
  final networkService = ref.read(networkServiceProvider);
  return ScanStateNotifier(scannerService, networkService);
});
