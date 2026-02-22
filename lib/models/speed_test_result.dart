/// Represents the result of a completed speed test.
class SpeedTestResult {
  final double downloadSpeed; // Mbps
  final double uploadSpeed; // Mbps
  final int latency; // milliseconds
  final DateTime timestamp;
  final String serverName; // which server was used
  final int downloadSamples; // number of samples taken
  final int uploadSamples; // number of samples taken
  final bool isPoorConnection; // latency > 1000ms

  SpeedTestResult({
    required this.downloadSpeed,
    required this.uploadSpeed,
    required this.latency,
    required this.timestamp,
    required this.serverName,
    required this.downloadSamples,
    required this.uploadSamples,
    required this.isPoorConnection,
  });

  Map<String, dynamic> toJson() => {
        'downloadSpeed': downloadSpeed,
        'uploadSpeed': uploadSpeed,
        'latency': latency,
        'timestamp': timestamp.toIso8601String(),
        'serverName': serverName,
        'downloadSamples': downloadSamples,
        'uploadSamples': uploadSamples,
        'isPoorConnection': isPoorConnection,
      };

  factory SpeedTestResult.fromJson(Map<String, dynamic> json) =>
      SpeedTestResult(
        downloadSpeed: json['downloadSpeed'],
        uploadSpeed: json['uploadSpeed'],
        latency: json['latency'],
        timestamp: DateTime.parse(json['timestamp']),
        serverName: json['serverName'],
        downloadSamples: json['downloadSamples'],
        uploadSamples: json['uploadSamples'],
        isPoorConnection: json['isPoorConnection'],
      );

  /// Returns formatted download speed with one decimal place.
  String get formattedDownloadSpeed =>
      '${downloadSpeed.toStringAsFixed(1)} Mbps';

  /// Returns formatted upload speed with one decimal place.
  String get formattedUploadSpeed => '${uploadSpeed.toStringAsFixed(1)} Mbps';

  /// Returns formatted latency as an integer.
  String get formattedLatency => '$latency ms';
}
