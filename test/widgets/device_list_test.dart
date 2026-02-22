import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_scanner/models/network_device.dart';
import 'package:network_scanner/widgets/device_list.dart';
import 'package:network_scanner/widgets/device_list_item.dart';

void main() {
  group('DeviceList Widget', () {
    testWidgets('displays empty state when no devices',
        (WidgetTester tester) async {
      // Arrange
      const devices = <NetworkDevice>[];

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DeviceList(devices: devices),
          ),
        ),
      );

      // Assert
      expect(find.text('No devices discovered yet'), findsOneWidget);
      expect(find.byType(DeviceListItem), findsNothing);
    });

    testWidgets('displays single device', (WidgetTester tester) async {
      // Arrange
      final devices = [
        NetworkDevice(
          ipAddress: '192.168.1.100',
          hostname: 'test-device',
          macAddress: 'AA:BB:CC:DD:EE:FF',
          responseTimeMs: 50,
          discoveredAt: DateTime.now(),
        ),
      ];

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceList(devices: devices),
          ),
        ),
      );

      // Assert
      expect(find.byType(DeviceListItem), findsOneWidget);
      expect(find.text('No devices discovered yet'), findsNothing);
    });

    testWidgets('displays multiple devices', (WidgetTester tester) async {
      // Arrange
      final devices = [
        NetworkDevice(
          ipAddress: '192.168.1.100',
          hostname: 'device-1',
          responseTimeMs: 50,
          discoveredAt: DateTime.now(),
        ),
        NetworkDevice(
          ipAddress: '192.168.1.101',
          hostname: 'device-2',
          responseTimeMs: 60,
          discoveredAt: DateTime.now(),
        ),
        NetworkDevice(
          ipAddress: '192.168.1.102',
          responseTimeMs: 70,
          discoveredAt: DateTime.now(),
        ),
      ];

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceList(devices: devices),
          ),
        ),
      );

      // Assert
      expect(find.byType(DeviceListItem), findsNWidgets(3));
    });

    testWidgets('sorts devices by IP address numerically',
        (WidgetTester tester) async {
      // Arrange - devices in unsorted order
      final devices = [
        NetworkDevice(
          ipAddress: '192.168.1.100',
          hostname: 'device-100',
          responseTimeMs: 50,
          discoveredAt: DateTime.now(),
        ),
        NetworkDevice(
          ipAddress: '192.168.1.5',
          hostname: 'device-5',
          responseTimeMs: 60,
          discoveredAt: DateTime.now(),
        ),
        NetworkDevice(
          ipAddress: '192.168.1.50',
          hostname: 'device-50',
          responseTimeMs: 70,
          discoveredAt: DateTime.now(),
        ),
      ];

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceList(devices: devices),
          ),
        ),
      );

      // Assert - verify order by checking text positions
      final deviceItems = tester.widgetList<DeviceListItem>(
        find.byType(DeviceListItem),
      ).toList();

      expect(deviceItems[0].device.ipAddress, '192.168.1.5');
      expect(deviceItems[1].device.ipAddress, '192.168.1.50');
      expect(deviceItems[2].device.ipAddress, '192.168.1.100');
    });

    testWidgets('sorts devices across different subnets',
        (WidgetTester tester) async {
      // Arrange
      final devices = [
        NetworkDevice(
          ipAddress: '192.168.2.1',
          responseTimeMs: 50,
          discoveredAt: DateTime.now(),
        ),
        NetworkDevice(
          ipAddress: '192.168.1.255',
          responseTimeMs: 60,
          discoveredAt: DateTime.now(),
        ),
        NetworkDevice(
          ipAddress: '192.168.1.1',
          responseTimeMs: 70,
          discoveredAt: DateTime.now(),
        ),
      ];

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceList(devices: devices),
          ),
        ),
      );

      // Assert
      final deviceItems = tester.widgetList<DeviceListItem>(
        find.byType(DeviceListItem),
      ).toList();

      expect(deviceItems[0].device.ipAddress, '192.168.1.1');
      expect(deviceItems[1].device.ipAddress, '192.168.1.255');
      expect(deviceItems[2].device.ipAddress, '192.168.2.1');
    });

    testWidgets('uses ListView.builder for rendering',
        (WidgetTester tester) async {
      // Arrange
      final devices = [
        NetworkDevice(
          ipAddress: '192.168.1.100',
          responseTimeMs: 50,
          discoveredAt: DateTime.now(),
        ),
      ];

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceList(devices: devices),
          ),
        ),
      );

      // Assert
      expect(find.byType(ListView), findsOneWidget);
    });
  });
}
