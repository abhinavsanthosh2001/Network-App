/// Configuration constants for speed testing.
class SpeedTestConfig {
  // Server selection
  static const int serverSelectionTimeout = 5000; // ms
  static const int maxLatencyForPreference = 100; // ms

  // Latency testing
  static const int latencySamples = 5;
  static const int latencyTimeout = 1000; // ms
  static const int poorConnectionThreshold = 1000; // ms

  // Download testing
  static const int downloadMinSamples = 3;
  static const int downloadMaxSamples = 5;
  static const int downloadStartSize = 2 * 1024 * 1024; // 2MB - smaller start for faster initial test
  static const int downloadMaxSize = 100 * 1024 * 1024; // 100MB - increased for very fast connections
  static const double downloadVarianceThreshold = 0.30; // 30%
  static const int targetTestDuration = 7; // seconds - target duration per sample

  // Upload testing
  static const int uploadMinSamples = 3;
  static const int uploadMaxSamples = 5;
  static const int uploadStartSize = 1 * 1024 * 1024; // 1MB - smaller start for faster initial test
  static const int uploadMaxSize = 50 * 1024 * 1024; // 50MB - increased for fast connections
  static const double uploadVarianceThreshold = 0.30; // 30%

  // Retry logic
  static const int maxRetries = 2;
  static const int retryDelay = 1000; // ms
  static const double failureThreshold = 0.50; // 50% of samples

  // Progress updates
  static const int progressUpdateInterval = 1000; // ms
}
