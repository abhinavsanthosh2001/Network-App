import 'package:flutter/material.dart';
import '../models/scan_state.dart';

/// Widget that displays scan results summary
/// Shows device count when scan is completed or stopped
/// Displayed in a footer container at the bottom of the screen
class ScanSummary extends StatelessWidget {
  final ScanStatus status;
  final int deviceCount;

  const ScanSummary({
    super.key,
    required this.status,
    required this.deviceCount,
  });

  @override
  Widget build(BuildContext context) {
    // Only show summary when scan is completed or stopped
    if (status != ScanStatus.completed && status != ScanStatus.stopped) {
      return const SizedBox.shrink();
    }

    String message = '';
    if (status == ScanStatus.completed) {
      message = 'Scan complete: $deviceCount device(s) found';
    } else if (status == ScanStatus.stopped) {
      message = 'Scan stopped: $deviceCount device(s) found';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade200,
      width: double.infinity,
      child: Text(
        message,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
