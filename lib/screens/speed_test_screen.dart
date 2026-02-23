import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/speed_test_provider.dart';
import '../providers/speed_test_history_provider.dart';
import '../models/test_progress.dart';
import '../models/speed_test_result.dart';
import '../widgets/speedometer_gauge.dart';
import 'speed_test_history_screen.dart';

class SpeedTestScreen extends ConsumerWidget {
  const SpeedTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testState = ref.watch(speedTestProvider);
    final history = ref.watch(speedTestHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Speed Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showMethodologyModal(context),
            tooltip: 'How is speed measured?',
          ),
          if (history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SpeedTestHistoryScreen(),
                  ),
                );
              },
              tooltip: 'View history',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Show progress if test is running
            if (testState.isRunning && testState.progress != null)
              _buildProgressDisplay(testState.progress!)
            // Show error if test failed
            else if (testState.error != null)
              _buildErrorDisplay(testState.error!, ref)
            // Show result if test completed
            else if (testState.result != null)
              _buildResultDisplay(testState.result!, context)
            // Show start button if idle
            else
              _buildIdleState(),
            
            const SizedBox(height: 24),
            
            // Control buttons
            _buildControlButtons(testState, ref),
          ],
        ),
        ),
      ),
    );
  }

  /// Builds the idle state with start button.
  Widget _buildIdleState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Icon(
          Icons.speed,
          size: 80,
          color: Colors.blue.shade300,
        ),
        const SizedBox(height: 24),
        const Text(
          'Test Your Connection',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Measure your download, upload, and latency',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildProgressDisplay(TestProgress progress) {
    final isDownload = progress.phase == TestPhase.download;
    final isUpload = progress.phase == TestPhase.upload;

    return Column(
      children: [
        const SizedBox(height: 20),
        Text(
          progress.phaseDescription,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SpeedometerGauge(
              label: 'DOWNLOAD',
              currentSpeed: isDownload ? progress.currentSpeed : null,
              maxSpeed: 300.0,
            ),
            SpeedometerGauge(
              label: 'UPLOAD',
              currentSpeed: isUpload ? progress.currentSpeed : null,
              maxSpeed: 300.0,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Elapsed: ${progress.elapsedSeconds}s',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildResultDisplay(SpeedTestResult result, BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Icon(Icons.check_circle, size: 56, color: Colors.green.shade400),
        const SizedBox(height: 12),
        const Text(
          'Test Complete',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 28),

        // Two gauges showing final speeds
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SpeedometerGauge(
              label: 'DOWNLOAD',
              currentSpeed: result.downloadSpeed,
              maxSpeed: 300.0,
            ),
            SpeedometerGauge(
              label: 'UPLOAD',
              currentSpeed: result.uploadSpeed,
              maxSpeed: 300.0,
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Speed cards below gauges
        Row(
          children: [
            Expanded(
              child: _buildResultMetric(
                'Download',
                result.formattedDownloadSpeed,
                Icons.download,
                _getSpeedColor(result.downloadSpeed),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildResultMetric(
                'Upload',
                result.formattedUploadSpeed,
                Icons.upload,
                _getSpeedColor(result.uploadSpeed),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Poor connection warning
        if (result.isPoorConnection)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Poor connection detected',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        
        const SizedBox(height: 24),
        
        // Metadata
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildMetadataRow('Server', result.serverName),
              const SizedBox(height: 8),
              _buildMetadataRow(
                'Time',
                DateFormat('MMM d, yyyy HH:mm').format(result.timestamp),
              ),
              const SizedBox(height: 8),
              _buildMetadataRow('Latency', result.formattedLatency),
              const SizedBox(height: 8),
              _buildMetadataRow(
                'Samples',
                '↓${result.downloadSamples} ↑${result.uploadSamples}',
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Share button
        OutlinedButton.icon(
          onPressed: () => _shareResult(result),
          icon: const Icon(Icons.share),
          label: const Text('Share Results'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildResultMetric(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Returns color based on speed (slow/medium/fast).
  Color _getSpeedColor(double speed) {
    if (speed < 10) return Colors.red.shade600;
    if (speed < 50) return Colors.orange.shade600;
    return Colors.green.shade600;
  }

  /// Returns color based on latency (good/medium/poor).
  Color _getLatencyColor(int latency) {
    if (latency > 100) return Colors.red.shade600;
    if (latency > 50) return Colors.orange.shade600;
    return Colors.green.shade600;
  }

  /// Builds the error display when test fails.
  /// 
  /// Shows:
  /// - Error icon
  /// - Error message
  /// - Suggestions for common errors
  /// - Retry button
  /// 
  /// Requirements: 7.2, 7.5, 7.7
  Widget _buildErrorDisplay(String error, WidgetRef ref) {
    // Determine error type and suggestion
    String suggestion = 'Please try again';
    if (error.contains('No connectivity') || error.contains('All test servers failed')) {
      suggestion = 'Check your internet connection and try again';
    } else if (error.contains('failed')) {
      suggestion = 'Network conditions may be unstable. Try again in a moment';
    }
    
    return Column(
      children: [
        const SizedBox(height: 40),
        
        Icon(
          Icons.error_outline,
          size: 80,
          color: Colors.red.shade400,
        ),
        
        const SizedBox(height: 24),
        
        const Text(
          'Test Failed',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            children: [
              Text(
                error,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red.shade900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                suggestion,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.red.shade700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the control buttons (Start/Cancel/Run Again).
  /// 
  /// Shows:
  /// - "Start Test" button when idle
  /// - "Cancel Test" button during test
  /// - "Run Again" button after completion or error
  /// - Disables start button when test is running
  /// 
  /// Requirements: 8.1, 8.3, 8.5
  Widget _buildControlButtons(SpeedTestState testState, WidgetRef ref) {
    if (testState.isRunning) {
      // Show cancel button during test
      return ElevatedButton.icon(
        onPressed: () => ref.read(speedTestProvider.notifier).cancelTest(),
        icon: const Icon(Icons.cancel),
        label: const Text('Cancel Test'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          textStyle: const TextStyle(fontSize: 16),
        ),
      );
    } else if (testState.result != null || testState.error != null) {
      // Show run again button after completion or error
      return ElevatedButton.icon(
        onPressed: () {
          ref.read(speedTestProvider.notifier).reset();
          ref.read(speedTestProvider.notifier).startTest();
        },
        icon: const Icon(Icons.refresh),
        label: const Text('Run Again'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          textStyle: const TextStyle(fontSize: 16),
        ),
      );
    } else {
      // Show start button when idle
      return ElevatedButton.icon(
        onPressed: () => ref.read(speedTestProvider.notifier).startTest(),
        icon: const Icon(Icons.speed),
        label: const Text('Start Speed Test'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          textStyle: const TextStyle(fontSize: 16),
        ),
      );
    }
  }

  void _showMethodologyModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'How Speed Is Measured',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'A deep dive into how this app tests your connection',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const Divider(height: 32),
              _modalSection(
                icon: Icons.looks_one,
                color: Colors.blue,
                title: 'Phase 1 — Latency',
                body:
                    'Before measuring speed, the app pings the test server multiple times and records the round-trip time in milliseconds (ms). The median value is used to filter out spikes. A low latency (< 30 ms) means your connection responds quickly, which matters for gaming and video calls.',
              ),
              _modalSection(
                icon: Icons.looks_two,
                color: Colors.green,
                title: 'Phase 2 — Download Test',
                body:
                    'The app opens several simultaneous HTTP connections to the server and downloads chunks of data in parallel. This is intentional — a single connection rarely saturates a fast link due to TCP congestion control. By running multiple streams at once, the test can fill your pipe and report a speed closer to your true maximum.',
              ),
              _modalSection(
                icon: Icons.looks_3,
                color: Colors.orange,
                title: 'Phase 3 — Upload Test',
                body:
                    'The same parallel approach is used for upload. The app generates random data locally and pushes it to the server across multiple connections simultaneously, measuring how fast your device can send data.',
              ),
              _modalSection(
                icon: Icons.merge_type,
                color: Colors.purple,
                title: 'Why Parallelism?',
                body:
                    'TCP — the protocol used for most internet traffic — limits each individual connection\'s speed to prevent network congestion. A single connection may only use a fraction of your available bandwidth. Running 4–8 parallel streams mimics how a browser loads a webpage (many resources at once) and gives a much more accurate picture of your real-world throughput.',
              ),
              _modalSection(
                icon: Icons.calculate,
                color: Colors.teal,
                title: 'How the Final Number Is Calculated',
                body:
                    'Speed is sampled every ~200 ms during the test. The app collects all samples, discards the slowest 10% (warm-up period) and the fastest 10% (outliers), then averages the remaining values. This trimmed mean is more stable than a simple average and less susceptible to brief bursts or drops.',
              ),
              _modalSection(
                icon: Icons.device_hub,
                color: Colors.indigo,
                title: 'What Can Affect Results?',
                body:
                    '• Other devices on your network consuming bandwidth\n'
                    '• Wi-Fi interference or distance from your router\n'
                    '• Server load at the time of the test\n'
                    '• Your device\'s CPU/memory under heavy load\n'
                    '• ISP throttling during peak hours',
              ),
              _modalSection(
                icon: Icons.info_outline,
                color: Colors.grey,
                title: 'Mbps vs MB/s',
                body:
                    'Results are shown in Megabits per second (Mbps), which is the standard used by ISPs. To convert to Megabytes per second (the unit used by download managers), divide by 8. So 100 Mbps ≈ 12.5 MB/s.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modalSection({
    required IconData icon,
    required Color color,
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.grey.shade700,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Shows confirmation dialog before clearing history.
  void _shareResult(SpeedTestResult result) {
    final text = '''
Speed Test Results
━━━━━━━━━━━━━━━━━━
📥 Download: ${result.formattedDownloadSpeed}
📤 Upload: ${result.formattedUploadSpeed}
⏱️ Latency: ${result.formattedLatency}

Server: ${result.serverName}
Date: ${DateFormat('MMM d, yyyy HH:mm').format(result.timestamp)}
''';
    
    Share.share(text, subject: 'My Speed Test Results');
  }
}
