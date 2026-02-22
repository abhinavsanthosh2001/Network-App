import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/scan_state.dart';
import '../providers/device_scanner_provider.dart';

/// Widget that displays scan control buttons
/// Shows start button when idle/completed/stopped
/// Shows stop button when scanning
class ScanControls extends ConsumerWidget {
  const ScanControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanState = ref.watch(scanStateProvider);
    final isScanning = scanState.status == ScanStatus.scanning;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            if (isScanning) {
              ref.read(scanStateProvider.notifier).stopScan();
            } else {
              ref.read(scanStateProvider.notifier).startScan();
            }
          },
          icon: Icon(isScanning ? Icons.stop : Icons.play_arrow),
          label: Text(isScanning ? 'Stop Scan' : 'Start Scan'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
          ),
        ),
      ),
    );
  }
}
