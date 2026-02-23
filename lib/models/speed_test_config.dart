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
  static const int downloadStartSize = 2 * 1024 * 1024; // 2MB
  static const int downloadMaxSize = 100 * 1024 * 1024; // 100MB
  static const double downloadVarianceThreshold = 0.30; // 30%
  static const int targetTestDuration = 7; // seconds per sample

  // Upload testing
  static const int uploadMinSamples = 3;
  static const int uploadMaxSamples = 5;
  static const int uploadStartSize = 1 * 1024 * 1024; // 1MB
  static const int uploadMaxSize = 50 * 1024 * 1024; // 50MB
  static const double uploadVarianceThreshold = 0.30; // 30%

  // Slow connection overrides (detected via latency phase)
  static const int slowDownloadMinSamples = 2;
  static const int slowDownloadMaxSamples = 3;
  static const int slowDownloadStartSize = 256 * 1024; // 256KB
  static const int slowDownloadMaxSize = 2 * 1024 * 1024; // 2MB
  static const int slowUploadMinSamples = 2;
  static const int slowUploadMaxSamples = 3;
  static const int slowUploadStartSize = 128 * 1024; // 128KB
  static const int slowUploadMaxSize = 1 * 1024 * 1024; // 1MB
  static const int slowTargetTestDuration = 4; // seconds per sample
  static const double slowVarianceThreshold = 0.40; // more lenient
  static const int slowConnectionLatencyThreshold = 300; // ms — trigger slow path

  // Retry logic
  static const int maxRetries = 2;
  static const int retryDelay = 1000; // ms
  static const double failureThreshold = 0.50; // 50% of samples

  // Progress updates
  static const int progressUpdateInterval = 1000; // ms
}
