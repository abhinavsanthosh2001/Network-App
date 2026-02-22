import 'dart:async';
import 'dart:io';
import '../models/network_device.dart';
import '../models/scan_progress.dart';

class DeviceScannerService {
  DeviceScannerService();

  /// Probe a single IP address to check if host is active
  /// Returns NetworkDevice if host responds, null if no response or timeout
  /// Applies 2-second timeout for the ping operation
  Future<NetworkDevice?> probeHost(String ipAddress) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Determine ping command based on platform
      final String pingCommand;
      final List<String> pingArgs;
      
      if (Platform.isWindows) {
        pingCommand = 'ping';
        pingArgs = ['-n', '1', '-w', '2000', ipAddress]; // 1 ping, 2000ms timeout
      } else {
        // Linux, macOS, Android, iOS
        pingCommand = 'ping';
        pingArgs = ['-c', '1', '-W', '2', ipAddress]; // 1 ping, 2 second timeout
      }

      // Execute ping command with timeout
      final result = await Process.run(
        pingCommand,
        pingArgs,
      ).timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          // Return a failed process result on timeout
          return ProcessResult(0, 1, '', 'Timeout');
        },
      );

      stopwatch.stop();

      // Check if ping was successful (exit code 0)
      if (result.exitCode == 0) {
        final responseTimeMs = stopwatch.elapsedMilliseconds;
        
        return NetworkDevice(
          ipAddress: ipAddress,
          hostname: null, // Hostname resolution will be done separately
          macAddress: null, // MAC address retrieval will be done separately
          responseTimeMs: responseTimeMs,
          discoveredAt: DateTime.now(),
        );
      }

      // Host did not respond
      return null;
    } catch (e) {
      // Error during ping (timeout or other error)
      stopwatch.stop();
      return null;
    }
  }

  /// Calculate subnet range from IP address and subnet mask
  /// Returns a list of valid host IP addresses in the subnet
  /// Excludes network address and broadcast address
  List<String> calculateSubnetRange(String ipAddress, String subnetMask) {
    // Parse IP address into octets
    final ipOctets = _parseIpAddress(ipAddress);
    if (ipOctets == null) {
      throw ArgumentError('Invalid IP address format: $ipAddress');
    }

    // Parse subnet mask into octets
    final maskOctets = _parseIpAddress(subnetMask);
    if (maskOctets == null) {
      throw ArgumentError('Invalid subnet mask format: $subnetMask');
    }

    // Calculate network address (IP AND subnet mask)
    final networkOctets = List<int>.generate(
      4,
      (i) => ipOctets[i] & maskOctets[i],
    );

    // Calculate broadcast address (network address OR inverted mask)
    final broadcastOctets = List<int>.generate(
      4,
      (i) => networkOctets[i] | (~maskOctets[i] & 0xFF),
    );

    // Generate all IP addresses in the range
    final ipList = <String>[];
    
    // Convert network and broadcast addresses to comparable format
    final networkAddress = _octetsToInt(networkOctets);
    final broadcastAddress = _octetsToInt(broadcastOctets);

    // Generate all valid host addresses (exclude network and broadcast)
    for (int ip = networkAddress + 1; ip < broadcastAddress; ip++) {
      ipList.add(_intToIpAddress(ip));
    }

    return ipList;
  }

  /// Scan entire subnet with concurrent probing
  /// Yields ScanProgress updates as devices are discovered
  /// Supports cancellation via stream subscription
  /// Batch size: 20 concurrent probes at a time
  Stream<ScanProgress> scanSubnet(String ipAddress, String subnetMask) async* {
    // Calculate IP range using calculateSubnetRange
    final ipRange = calculateSubnetRange(ipAddress, subnetMask);
    final totalAddresses = ipRange.length;
    int scannedAddresses = 0;

    // Initialize ScanProgress tracking
    yield ScanProgress(
      totalAddresses: totalAddresses,
      scannedAddresses: 0,
      isComplete: false,
    );

    // Batch size for concurrent probing
    const batchSize = 20;

    // Process IPs in batches
    for (int i = 0; i < ipRange.length; i += batchSize) {
      // Get current batch of IPs
      final endIndex = (i + batchSize < ipRange.length) ? i + batchSize : ipRange.length;
      final batch = ipRange.sublist(i, endIndex);

      // Create concurrent probe tasks for this batch
      final probeTasks = batch.map((ip) => probeHost(ip)).toList();

      // Wait for all probes in the batch to complete
      final results = await Future.wait(probeTasks);

      // Process results and yield progress updates
      for (int j = 0; j < results.length; j++) {
        scannedAddresses++;
        final device = results[j];

        if (device != null) {
          // Attempt to resolve hostname and MAC address for discovered device
          final hostname = await resolveHostname(device.ipAddress);
          final macAddress = await getMacAddress(device.ipAddress);

          // Create updated device with hostname and MAC address
          final updatedDevice = NetworkDevice(
            ipAddress: device.ipAddress,
            hostname: hostname,
            macAddress: macAddress,
            responseTimeMs: device.responseTimeMs,
            discoveredAt: device.discoveredAt,
          );

          // Yield progress update with newly discovered device
          yield ScanProgress(
            totalAddresses: totalAddresses,
            scannedAddresses: scannedAddresses,
            newDevice: updatedDevice,
            isComplete: false,
          );
        } else {
          // Yield progress update without new device
          yield ScanProgress(
            totalAddresses: totalAddresses,
            scannedAddresses: scannedAddresses,
            isComplete: false,
          );
        }
      }
    }

    // Yield final completion status
    yield ScanProgress(
      totalAddresses: totalAddresses,
      scannedAddresses: scannedAddresses,
      isComplete: true,
    );
  }

  /// Parse IP address string into list of 4 octets
  /// Returns null if format is invalid
  List<int>? _parseIpAddress(String ipAddress) {
    final parts = ipAddress.split('.');
    
    if (parts.length != 4) {
      return null;
    }

    try {
      final octets = parts.map((part) => int.parse(part)).toList();
      
      // Validate each octet is in range 0-255
      for (final octet in octets) {
        if (octet < 0 || octet > 255) {
          return null;
        }
      }
      
      return octets;
    } catch (e) {
      return null;
    }
  }

  /// Convert 4 octets to a single 32-bit integer
  int _octetsToInt(List<int> octets) {
    return (octets[0] << 24) | (octets[1] << 16) | (octets[2] << 8) | octets[3];
  }

  /// Convert 32-bit integer to IP address string
  String _intToIpAddress(int ip) {
    return '${(ip >> 24) & 0xFF}.${(ip >> 16) & 0xFF}.${(ip >> 8) & 0xFF}.${ip & 0xFF}';
  }

  /// Resolve hostname for an IP address using reverse DNS lookup
  /// Returns hostname string if successful, null if resolution fails or times out
  /// Applies 1-second timeout
  Future<String?> resolveHostname(String ipAddress) async {
    try {
      // Parse the IP address
      final address = InternetAddress(ipAddress);
      
      // Perform reverse DNS lookup with 1-second timeout
      final result = await address.reverse().timeout(
        const Duration(seconds: 1),
        onTimeout: () {
          // Throw TimeoutException on timeout
          throw TimeoutException('Hostname resolution timed out');
        },
      );

      // Return the hostname if lookup succeeded
      return result.host;
    } catch (e) {
      // Return null on any error (invalid IP, lookup failure, timeout, etc.)
      return null;
    }
  }

  /// Retrieve MAC address for an IP address using ARP table lookup
  /// Returns formatted MAC address if successful, null if unavailable or unsupported
  /// Only supported on Android and iOS platforms
  Future<String?> getMacAddress(String ipAddress) async {
    // Check if platform supports ARP table lookup
    if (!Platform.isAndroid && !Platform.isIOS) {
      // MAC address retrieval not supported on this platform
      return null;
    }

    try {
      // Execute ARP table lookup command
      final String arpCommand;
      final List<String> arpArgs;
      
      if (Platform.isAndroid || Platform.isIOS) {
        arpCommand = 'arp';
        arpArgs = ['-n', ipAddress];
      } else {
        // Should not reach here due to platform check above
        return null;
      }

      // Run ARP command with timeout
      final result = await Process.run(
        arpCommand,
        arpArgs,
      ).timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          return ProcessResult(0, 1, '', 'Timeout');
        },
      );

      // Check if command was successful
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        
        // Parse MAC address from ARP output
        final macAddress = _parseMacAddressFromArp(output);
        
        if (macAddress != null) {
          // Format and return MAC address
          return _formatMacAddress(macAddress);
        }
      }

      return null;
    } catch (e) {
      // Return null on any error
      return null;
    }
  }

  /// Parse MAC address from ARP command output
  /// Returns raw MAC address string if found, null otherwise
  String? _parseMacAddressFromArp(String arpOutput) {
    // MAC address pattern: matches various formats like
    // AA:BB:CC:DD:EE:FF, aa-bb-cc-dd-ee-ff, aabbccddeeff
    final macPattern = RegExp(
      r'([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})|([0-9A-Fa-f]{12})',
      caseSensitive: false,
    );

    final match = macPattern.firstMatch(arpOutput);
    if (match != null) {
      return match.group(0);
    }

    return null;
  }

  /// Format MAC address to standard format (AA:BB:CC:DD:EE:FF)
  /// Handles various input formats (colon, dash, or no separator)
  String _formatMacAddress(String macAddress) {
    // Remove any existing separators
    final cleanMac = macAddress.replaceAll(RegExp(r'[:-]'), '');
    
    // Ensure it's 12 characters
    if (cleanMac.length != 12) {
      return macAddress; // Return as-is if invalid length
    }

    // Format as AA:BB:CC:DD:EE:FF
    final formatted = <String>[];
    for (int i = 0; i < cleanMac.length; i += 2) {
      formatted.add(cleanMac.substring(i, i + 2).toUpperCase());
    }

    return formatted.join(':');
  }
}
