import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/scan_state.dart';
import '../providers/device_scanner_provider.dart';
import '../widgets/scan_controls.dart';
import '../widgets/scan_progress.dart';
import '../widgets/device_list.dart';
import '../widgets/error_message.dart';
import '../widgets/scan_summary.dart';

/// Network Scan screen that displays LAN device scanner interface
/// Allows users to scan the local network for active devices
/// Shows scan progress, discovered devices, and scan controls
class NetworkScanScreen extends ConsumerWidget {
  const NetworkScanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanState = ref.watch(scanStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Scan'),
      ),
      body: Column(
        children: [
          // Scan controls section (start/stop button)
          const ScanControls(),

          // Progress indicator (visible when scanning)
          if (scanState.status == ScanStatus.scanning)
            ScanProgress(progress: scanState.progress),

          // Error message (visible when error occurs)
          if (scanState.status == ScanStatus.error)
            ErrorMessage(message: scanState.errorMessage),

          // Device list (scrollable, takes remaining space)
          Expanded(
            child: DeviceList(devices: scanState.devices),
          ),

          // Summary footer (visible when completed or stopped)
          ScanSummary(
            status: scanState.status,
            deviceCount: scanState.devices.length,
          ),
        ],
      ),
    );
  }
}
