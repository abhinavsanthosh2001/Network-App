import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/speed_test_provider.dart';
import '../providers/speed_test_history_provider.dart';
import '../models/test_progress.dart';
import '../models/speed_test_result.dart';

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
          if (history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _showClearHistoryDialog(context, ref),
              tooltip: 'Clear history',
            ),
        ],
      ),
      body: Column(
        children: [
          // Main test area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Show progress if test is running
                  if (testState.isRunning && testState.progress != null)
                    _buildProgressDisplay(testState.progress!)
                  // Show error if test failed
                  else if (testState.error != null)
                    _buildErrorDisplay(testState.error!, ref)
                  // Show result if test completed
                  else if (testState.result != null)
                    _buildResultDisplay(testState.result!)
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
          
          // History section
          if (history.isNotEmpty) ...[
            const Divider(height: 1),
            _buildHistorySection(history, ref),
          ],
        ],
      ),
    );
  }

  /// Builds the idle state with start button.
  Widget _buildIdleState() {
    return Column(
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

  /// Builds the real-time progress display during test execution.
  /// 
  /// Shows:
  /// - Current test phase
  /// - Progress bar with percentage
  /// - Intermediate speed/latency values
  /// - Elapsed time for current phase
  /// 
  /// Requirements: 6.1, 6.2, 6.3, 6.5, 6.6
  Widget _buildProgressDisplay(TestProgress progress) {
    return Column(
      children: [
        const SizedBox(height: 20),
        
        // Phase indicator
        Text(
          progress.phaseDescription,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Progress bar
        LinearProgressIndicator(
          value: progress.progressPercentage,
          minHeight: 8,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade400),
        ),
        
        const SizedBox(height: 12),
        
        // Progress percentage
        Text(
          '${(progress.progressPercentage * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Current measurements
        if (progress.currentSpeed != null)
          _buildProgressMetric(
            'Current Speed',
            '${progress.currentSpeed!.toStringAsFixed(1)} Mbps',
            Icons.speed,
          ),
        
        if (progress.currentLatency != null)
          _buildProgressMetric(
            'Latency',
            '${progress.currentLatency} ms',
            Icons.timer,
          ),
        
        const SizedBox(height: 24),
        
        // Elapsed time
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

  Widget _buildProgressMetric(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28, color: Colors.blue.shade400),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the result display after test completion.
  /// 
  /// Shows:
  /// - Download speed with icon and formatting
  /// - Upload speed with icon and formatting
  /// - Latency with icon and formatting
  /// - Server name used for test
  /// - Timestamp of test
  /// - Poor connection indicator if applicable
  /// - Color coding for speeds
  /// 
  /// Requirements: 2.7, 3.7, 4.5, 5.2
  Widget _buildResultDisplay(result) {
    return Column(
      children: [
        const SizedBox(height: 20),
        
        // Success icon
        Icon(
          Icons.check_circle,
          size: 60,
          color: Colors.green.shade400,
        ),
        
        const SizedBox(height: 16),
        
        const Text(
          'Test Complete',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Download speed
        _buildResultMetric(
          'Download',
          result.formattedDownloadSpeed,
          Icons.download,
          _getSpeedColor(result.downloadSpeed),
        ),
        
        const SizedBox(height: 24),
        
        // Upload speed
        _buildResultMetric(
          'Upload',
          result.formattedUploadSpeed,
          Icons.upload,
          _getSpeedColor(result.uploadSpeed),
        ),
        
        const SizedBox(height: 24),
        
        // Latency
        _buildResultMetric(
          'Latency',
          result.formattedLatency,
          Icons.timer,
          _getLatencyColor(result.latency),
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
              _buildMetadataRow(
                'Samples',
                '↓${result.downloadSamples} ↑${result.uploadSamples}',
              ),
            ],
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 36, color: color),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
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

  /// Builds the history section with list of past results.
  /// 
  /// Shows:
  /// - Results in chronological order (newest first)
  /// - Download/upload speeds and latency for each entry
  /// - Human-readable timestamps
  /// - Swipe-to-delete for individual entries
  /// - Empty state when no history
  /// 
  /// Requirements: 5.3, 10.1, 10.2, 10.4, 10.5
  Widget _buildHistorySection(List history, WidgetRef ref) {
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${history.length} test${history.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, index) {
                final result = history[index];
                return Dismissible(
                  key: Key(result.timestamp.toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (direction) async {
                    // Create a new list without this result
                    final historyNotifier = ref.read(speedTestHistoryProvider.notifier);
                    
                    // Get current history, remove the item, and save
                    final currentHistory = ref.read(speedTestHistoryProvider);
                    final updatedHistory = List<SpeedTestResult>.from(currentHistory)
                      ..removeAt(index);
                    
                    // Clear and re-add all items (simple approach for now)
                    await historyNotifier.clearHistory();
                    for (final item in updatedHistory) {
                      await historyNotifier.addResult(item);
                    }
                  },
                  child: _buildHistoryItem(result),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(result) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getSpeedColor(result.downloadSpeed).withOpacity(0.2),
        child: Icon(
          Icons.speed,
          color: _getSpeedColor(result.downloadSpeed),
        ),
      ),
      title: Row(
        children: [
          Icon(Icons.download, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            '${result.downloadSpeed.toStringAsFixed(1)} Mbps',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 16),
          Icon(Icons.upload, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            '${result.uploadSpeed.toStringAsFixed(1)} Mbps',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
      subtitle: Text(
        'Latency: ${result.latency} ms • ${result.serverName}',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: Text(
        DateFormat('MMM d\nHH:mm').format(result.timestamp),
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        textAlign: TextAlign.right,
      ),
    );
  }

  /// Shows confirmation dialog before clearing history.
  void _showClearHistoryDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text(
          'Are you sure you want to clear all test history? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(speedTestHistoryProvider.notifier).clearHistory();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
