import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/speed_test_result.dart';
import '../models/test_progress.dart';
import '../models/cancellation_token.dart';
import '../services/speed_test_service.dart';
import 'speed_test_history_provider.dart';

/// Represents the state of an active speed test.
/// 
/// This immutable state class contains all information about the current
/// speed test execution, including results, progress, errors, and running status.
/// 
/// Requirements: 6.1 (progress tracking), 8.6 (result notification)
class SpeedTestState {
  final SpeedTestResult? result;
  final TestProgress? progress;
  final String? error;
  final bool isRunning;
  
  const SpeedTestState({
    this.result,
    this.progress,
    this.error,
    this.isRunning = false,
  });
  
  /// Creates a copy of this state with the specified fields replaced.
  SpeedTestState copyWith({
    SpeedTestResult? result,
    TestProgress? progress,
    String? error,
    bool? isRunning,
    bool clearResult = false,
    bool clearProgress = false,
    bool clearError = false,
  }) {
    return SpeedTestState(
      result: clearResult ? null : (result ?? this.result),
      progress: clearProgress ? null : (progress ?? this.progress),
      error: clearError ? null : (error ?? this.error),
      isRunning: isRunning ?? this.isRunning,
    );
  }
}

/// Provider for managing active speed test execution.
/// 
/// This provider handles:
/// - Starting and cancelling speed tests
/// - Tracking test progress in real-time
/// - Managing test state (running, completed, error)
/// - Preventing concurrent test execution
/// - Automatically persisting completed results to history
/// 
/// Requirements:
/// - 8.1: Initiate test sequence
/// - 8.3: Support cancellation
/// - 8.5: Prevent concurrent tests
/// - 8.6: Notify UI with results
/// - 6.1, 6.4: Track and report progress
class SpeedTestProvider extends StateNotifier<SpeedTestState> {
  final SpeedTestService _service;
  final Ref _ref;
  CancellationToken? _cancellationToken;
  
  SpeedTestProvider(this._service, this._ref) : super(const SpeedTestState());
  
  /// Starts a new speed test.
  /// 
  /// This method initiates a complete speed test with all three phases:
  /// latency, download, and upload. Progress updates are emitted throughout
  /// the test, and the final result is automatically persisted to history.
  /// 
  /// If a test is already running, this method does nothing (prevents
  /// concurrent tests as per Requirement 8.5).
  /// 
  /// The test can be cancelled at any time by calling cancelTest().
  /// 
  /// Requirements:
  /// - 8.1: Begin test sequence
  /// - 8.5: Prevent concurrent tests
  /// - 8.6: Notify UI with final result
  /// - 5.1: Persist result to history
  Future<void> startTest() async {
    // Prevent starting a new test if one is already running (Requirement 8.5)
    if (state.isRunning) {
      return;
    }
    
    // Create a new cancellation token for this test
    _cancellationToken = CancellationToken();
    
    // Update state to indicate test is starting
    state = state.copyWith(
      isRunning: true,
      clearResult: true,
      clearError: true,
      clearProgress: true,
    );
    
    try {
      // Run the full test with progress callbacks
      final result = await _service.runFullTest(
        onProgress: _handleProgress,
        cancellationToken: _cancellationToken,
      );
      
      // Test completed successfully
      _handleComplete(result);
      
      // Persist result to history (Requirement 5.1)
      await _ref.read(speedTestHistoryProvider.notifier).addResult(result);
      
    } on CancelledException {
      // Test was cancelled - don't persist result (Requirement 8.4)
      _handleCancellation();
    } catch (e) {
      // Test failed with an error
      _handleError(e);
    }
  }
  
  /// Cancels the currently running test.
  /// 
  /// If a test is running, this method requests cancellation via the
  /// cancellation token. The test will stop immediately and no result
  /// will be persisted to history.
  /// 
  /// If no test is running, this method does nothing.
  /// 
  /// Requirements: 8.3 (cancel test), 8.4 (don't persist cancelled results)
  void cancelTest() {
    if (state.isRunning && _cancellationToken != null) {
      _cancellationToken!.cancel();
    }
  }
  
  /// Resets the provider state to initial values.
  /// 
  /// This clears any results, errors, and progress information.
  /// Useful for preparing the UI for a new test.
  void reset() {
    state = const SpeedTestState();
    _cancellationToken = null;
  }
  
  /// Handles progress updates during test execution.
  /// 
  /// This method is called periodically by the service during test execution
  /// to report progress. It updates the state with the latest progress
  /// information, which triggers UI updates.
  /// 
  /// [progress] - The current test progress
  /// 
  /// Requirements: 6.1 (track current phase), 6.4 (emit phase completion)
  void _handleProgress(TestProgress progress) {
    // Only update if test is still running
    if (state.isRunning) {
      state = state.copyWith(progress: progress);
    }
  }
  
  /// Handles successful test completion.
  /// 
  /// Updates the state with the final result and marks the test as no longer
  /// running. This triggers UI updates to display the results.
  /// 
  /// [result] - The completed speed test result
  /// 
  /// Requirements: 8.6 (notify UI with final result)
  void _handleComplete(SpeedTestResult result) {
    state = state.copyWith(
      result: result,
      isRunning: false,
      clearProgress: true,
      clearError: true,
    );
  }
  
  /// Handles test cancellation.
  /// 
  /// Updates the state to indicate the test is no longer running and
  /// clears any progress information. No result is persisted.
  /// 
  /// Requirements: 8.4 (don't persist cancelled results)
  void _handleCancellation() {
    state = state.copyWith(
      isRunning: false,
      clearProgress: true,
      clearError: true,
    );
  }
  
  /// Handles test errors.
  /// 
  /// Updates the state with the error message and marks the test as no longer
  /// running. This triggers UI updates to display the error.
  /// 
  /// [error] - The error that occurred during testing
  void _handleError(Object error) {
    state = state.copyWith(
      error: error.toString(),
      isRunning: false,
      clearProgress: true,
    );
  }
}

/// Provider for accessing the speed test state.
/// 
/// This provider creates a SpeedTestProvider instance with the required
/// dependencies (service and ref for accessing history provider).
/// 
/// Example usage:
/// ```dart
/// // In a widget
/// final speedTestState = ref.watch(speedTestProvider);
/// 
/// // Start a test
/// ref.read(speedTestProvider.notifier).startTest();
/// 
/// // Cancel a test
/// ref.read(speedTestProvider.notifier).cancelTest();
/// 
/// // Reset state
/// ref.read(speedTestProvider.notifier).reset();
/// ```
final speedTestProvider =
    StateNotifierProvider<SpeedTestProvider, SpeedTestState>(
  (ref) => SpeedTestProvider(SpeedTestService(), ref),
);
