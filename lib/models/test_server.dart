/// Represents a remote server endpoint for speed testing.
class TestServer {
  final String name;
  final String baseUrl;
  final String downloadEndpoint;
  final String uploadEndpoint;
  final String pingEndpoint;

  TestServer({
    required this.name,
    required this.baseUrl,
    required this.downloadEndpoint,
    required this.uploadEndpoint,
    required this.pingEndpoint,
  });

  /// Returns the full URL for downloading data of a specific size.
  String getDownloadUrl(int sizeBytes) =>
      '$baseUrl$downloadEndpoint'.replaceAll('{size}', sizeBytes.toString());

  /// Returns the full URL for uploading data.
  String getUploadUrl() => '$baseUrl$uploadEndpoint';

  /// Returns the full URL for ping/latency testing.
  String getPingUrl() => '$baseUrl$pingEndpoint';
}
