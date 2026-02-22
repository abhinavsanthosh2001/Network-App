import 'network_device.dart';

/// Data class for streaming scan progress updates
class ScanProgress {
  /// Total number of addresses to scan
  final int totalAddresses;

  /// Number of addresses scanned so far
  final int scannedAddresses;

  /// Newly discovered device (null if no new device in this update)
  final NetworkDevice? newDevice;

  /// Whether the scan is complete
  final bool isComplete;

  ScanProgress({
    required this.totalAddresses,
    required this.scannedAddresses,
    this.newDevice,
    this.isComplete = false,
  });

  /// Progress percentage (0-100)
  double get progress =>
      totalAddresses > 0 ? (scannedAddresses / totalAddresses) * 100 : 0;

  /// Creates a copy of this ScanProgress with the given fields replaced
  ScanProgress copyWith({
    int? totalAddresses,
    int? scannedAddresses,
    NetworkDevice? newDevice,
    bool? isComplete,
  }) {
    return ScanProgress(
      totalAddresses: totalAddresses ?? this.totalAddresses,
      scannedAddresses: scannedAddresses ?? this.scannedAddresses,
      newDevice: newDevice ?? this.newDevice,
      isComplete: isComplete ?? this.isComplete,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanProgress &&
          totalAddresses == other.totalAddresses &&
          scannedAddresses == other.scannedAddresses &&
          newDevice == other.newDevice &&
          isComplete == other.isComplete;

  @override
  int get hashCode =>
      totalAddresses.hashCode ^
      scannedAddresses.hashCode ^
      newDevice.hashCode ^
      isComplete.hashCode;
}
