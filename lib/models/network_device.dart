/// Represents a discovered device on the network.
class NetworkDevice {
  /// The IP address of the device
  final String ipAddress;

  /// The hostname of the device (null if resolution failed)
  final String? hostname;

  /// The MAC address of the device (null if unavailable)
  final String? macAddress;

  /// Response time in milliseconds
  final int responseTimeMs;

  /// Timestamp when the device was discovered
  final DateTime discoveredAt;

  NetworkDevice({
    required this.ipAddress,
    this.hostname,
    this.macAddress,
    required this.responseTimeMs,
    required this.discoveredAt,
  });

  /// Display name: hostname if available, otherwise IP address
  String get displayName => hostname ?? ipAddress;

  /// Equality based on IP address
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NetworkDevice && ipAddress == other.ipAddress;

  @override
  int get hashCode => ipAddress.hashCode;

  /// Creates a copy of this NetworkDevice with the given fields replaced
  NetworkDevice copyWith({
    String? ipAddress,
    String? hostname,
    String? macAddress,
    int? responseTimeMs,
    DateTime? discoveredAt,
  }) {
    return NetworkDevice(
      ipAddress: ipAddress ?? this.ipAddress,
      hostname: hostname ?? this.hostname,
      macAddress: macAddress ?? this.macAddress,
      responseTimeMs: responseTimeMs ?? this.responseTimeMs,
      discoveredAt: discoveredAt ?? this.discoveredAt,
    );
  }
}
