import 'network_device.dart';

/// Represents the status of the scanning process
enum ScanStatus {
  /// No scan is currently running
  idle,

  /// A scan is currently in progress
  scanning,

  /// The scan has completed successfully
  completed,

  /// The scan was stopped by the user
  stopped,

  /// An error occurred during scanning
  error,
}

/// Represents the current state of the scanning process
class ScanState {
  /// Current status of the scan
  final ScanStatus status;

  /// Total number of addresses to scan
  final int totalAddresses;

  /// Number of addresses scanned so far
  final int scannedAddresses;

  /// List of discovered devices
  final List<NetworkDevice> devices;

  /// Error message if status is error
  final String? errorMessage;

  const ScanState({
    required this.status,
    this.totalAddresses = 0,
    this.scannedAddresses = 0,
    this.devices = const [],
    this.errorMessage,
  });

  /// Progress percentage (0-100)
  double get progress =>
      totalAddresses > 0 ? (scannedAddresses / totalAddresses) * 100 : 0;

  /// Creates a copy of this ScanState with the given fields replaced
  ScanState copyWith({
    ScanStatus? status,
    int? totalAddresses,
    int? scannedAddresses,
    List<NetworkDevice>? devices,
    String? errorMessage,
  }) {
    return ScanState(
      status: status ?? this.status,
      totalAddresses: totalAddresses ?? this.totalAddresses,
      scannedAddresses: scannedAddresses ?? this.scannedAddresses,
      devices: devices ?? this.devices,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanState &&
          status == other.status &&
          totalAddresses == other.totalAddresses &&
          scannedAddresses == other.scannedAddresses &&
          devices == other.devices &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      status.hashCode ^
      totalAddresses.hashCode ^
      scannedAddresses.hashCode ^
      devices.hashCode ^
      errorMessage.hashCode;
}
