import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/speed_test_result.dart';

class SpeedTestHistoryProvider extends StateNotifier<List<SpeedTestResult>> {
  static const String _storageKey = 'speed_test_history';
  static const int _maxHistorySize = 100;
  
  final SharedPreferences _prefs;
  
  /// Creates a new history provider and loads existing history.
  /// 
  /// [_prefs] - SharedPreferences instance for persistent storage
  SpeedTestHistoryProvider(this._prefs) : super([]) {
    _loadHistory();
  }
  
  /// Adds a new test result to history and persists it.
  /// 
  /// The result is added to the beginning of the list (newest first).
  /// If the history exceeds 100 entries, the oldest entries are removed.
  /// The updated history is automatically persisted to local storage.
  /// 
  /// [result] - The speed test result to add
  /// 
  /// Requirements: 5.1 (persist results), 5.3 (newest first), 5.7 (trim to 100)
  Future<void> addResult(SpeedTestResult result) async {
    // Add result to the beginning of the list (newest first)
    state = [result, ...state];
    
    // Trim history if it exceeds maximum size
    _trimHistory();
    
    // Persist the updated history
    await _saveHistory();
  }
  
  /// Clears all test results from history and local storage.
  /// 
  /// This removes all entries from the in-memory state and deletes
  /// the persisted data from SharedPreferences.
  /// 
  /// Requirements: 10.2 (clear history), 10.3 (remove persisted data)
  Future<void> clearHistory() async {
    // Clear the in-memory state
    state = [];
    
    // Remove the persisted data from SharedPreferences
    await _prefs.remove(_storageKey);
  }
  
  /// Retrieves the N most recent test results.
  /// 
  /// Returns a list of the most recent results, up to the specified count.
  /// The results are already in chronological order (newest first).
  /// 
  /// [count] - The maximum number of results to return
  /// 
  /// Returns a list of up to [count] most recent results.
  /// 
  /// Requirements: 10.1 (retrieve results), 5.3 (chronological order)
  List<SpeedTestResult> getRecentResults(int count) {
    // State is already in chronological order (newest first)
    // Return up to 'count' results
    return state.take(count).toList();
  }
  
  /// Loads history from SharedPreferences on initialization.
  /// 
  /// Reads the JSON-encoded history from local storage, deserializes
  /// each result, and updates the state. If no history exists or if
  /// there's an error loading, the state remains empty.
  /// 
  /// Requirements: 5.4 (JSON deserialization), 5.5 (load on start)
  Future<void> _loadHistory() async {
    try {
      // Get the JSON-encoded history from SharedPreferences
      final String? historyJson = _prefs.getString(_storageKey);
      
      if (historyJson == null) {
        // No history exists yet
        return;
      }
      
      // Decode the JSON array
      final List<dynamic> historyList = jsonDecode(historyJson);
      
      // Deserialize each result
      final List<SpeedTestResult> results = historyList
          .map((json) => SpeedTestResult.fromJson(json as Map<String, dynamic>))
          .toList();
      
      // Update state with loaded results
      state = results;
    } catch (e) {
      // If there's an error loading history, start with empty state
      // This handles cases like corrupted data or format changes
      state = [];
      // Log error for debugging (remove in production)
      debugPrint('Error loading speed test history: $e');
    }
  }
  
  /// Saves the current history to SharedPreferences.
  /// 
  /// Serializes all results to JSON and stores them in local storage.
  /// This method is called automatically after adding results or clearing history.
  /// 
  /// Requirements: 5.4 (JSON serialization)
  Future<void> _saveHistory() async {
    try {
      // Serialize all results to JSON
      final List<Map<String, dynamic>> historyList =
          state.map((result) => result.toJson()).toList();
      
      // Encode to JSON string
      final String historyJson = jsonEncode(historyList);
      
      // Save to SharedPreferences
      await _prefs.setString(_storageKey, historyJson);
    } catch (e) {
      // Log error but don't throw - we don't want to break the app
      // if persistence fails
      debugPrint('Error saving speed test history: $e');
    }
  }
  
  /// Trims history to the maximum size limit.
  /// 
  /// If the history exceeds 100 entries, removes the oldest entries
  /// (from the end of the list) to maintain the limit.
  /// 
  /// Requirements: 5.7 (remove oldest when exceeding 100)
  void _trimHistory() {
    if (state.length > _maxHistorySize) {
      // Keep only the first _maxHistorySize entries (newest)
      state = state.sublist(0, _maxHistorySize);
    }
  }
}

/// Provider for accessing the speed test history.
/// 
/// This provider requires SharedPreferences to be initialized before use.
/// It should be overridden in main.dart with an actual SharedPreferences instance.
/// 
/// Example usage in main.dart:
/// ```dart
/// final prefs = await SharedPreferences.getInstance();
/// runApp(
///   ProviderScope(
///     overrides: [
///       speedTestHistoryProvider.overrideWith(
///         (ref) => SpeedTestHistoryProvider(prefs),
///       ),
///     ],
///     child: MyApp(),
///   ),
/// );
/// ```
final speedTestHistoryProvider =
    StateNotifierProvider<SpeedTestHistoryProvider, List<SpeedTestResult>>(
  (ref) => throw UnimplementedError(
    'speedTestHistoryProvider must be overridden with SharedPreferences',
  ),
);
