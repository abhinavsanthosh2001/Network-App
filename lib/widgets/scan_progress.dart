import 'package:flutter/material.dart';

/// Widget that displays scan progress
/// Shows a linear progress indicator and percentage text
/// Only visible when scanning is in progress
class ScanProgress extends StatelessWidget {
  final double progress;

  const ScanProgress({
    super.key,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: progress / 100,
            minHeight: 8,
          ),
          const SizedBox(height: 8),
          Text(
            '${progress.toStringAsFixed(1)}% complete',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
