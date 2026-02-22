import 'package:flutter/material.dart';
import '../models/network_device.dart';

/// Widget that displays a single discovered network device
/// Shows device icon with color based on hostname availability
/// Displays device name, IP address, MAC address, and response time
class DeviceListItem extends StatelessWidget {
  final NetworkDevice device;

  const DeviceListItem({
    super.key,
    required this.device,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(
          Icons.devices,
          color: device.hostname != null ? Colors.green : Colors.grey,
          size: 32,
        ),
        title: Text(
          device.displayName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('IP: ${device.ipAddress}'),
            if (device.macAddress != null)
              Text('MAC: ${device.macAddress}'),
            Text('Response: ${device.responseTimeMs}ms'),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
