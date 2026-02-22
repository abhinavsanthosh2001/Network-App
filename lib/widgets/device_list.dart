import 'package:flutter/material.dart';
import '../models/network_device.dart';
import 'device_list_item.dart';

/// Widget that displays a list of discovered network devices
/// Shows empty state when no devices are found
/// Sorts devices by IP address numerically
class DeviceList extends StatelessWidget {
  final List<NetworkDevice> devices;

  const DeviceList({
    super.key,
    required this.devices,
  });

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return const Center(
        child: Text(
          'No devices discovered yet',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    // Sort devices by IP address numerically
    final sortedDevices = List<NetworkDevice>.from(devices)
      ..sort((a, b) => _compareIpAddresses(a.ipAddress, b.ipAddress));

    return ListView.builder(
      itemCount: sortedDevices.length,
      itemBuilder: (context, index) {
        return DeviceListItem(device: sortedDevices[index]);
      },
    );
  }

  /// Compare two IP addresses numerically
  /// Parses each octet and compares them in order
  int _compareIpAddresses(String ip1, String ip2) {
    final parts1 = ip1.split('.').map(int.parse).toList();
    final parts2 = ip2.split('.').map(int.parse).toList();

    for (int i = 0; i < 4; i++) {
      if (parts1[i] != parts2[i]) {
        return parts1[i].compareTo(parts2[i]);
      }
    }

    return 0;
  }
}
