import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../providers/network_provider.dart';

class WifiInfoScreen extends ConsumerWidget {
  const WifiInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networkInfoAsync = ref.watch(networkInfoProvider);
    final connectivityAsync = ref.watch(connectivityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wi-Fi Info'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(networkInfoProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(networkInfoProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ConnectionStatusCard(connectivityAsync),
            const SizedBox(height: 16),
            _NetworkInfoCard(networkInfoAsync),
          ],
        ),
      ),
    );
  }
}

class _ConnectionStatusCard extends StatelessWidget {
  final AsyncValue<ConnectivityResult> connectivityAsync;

  const _ConnectionStatusCard(this.connectivityAsync);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection Status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            connectivityAsync.when(
              data: (connectivity) => _buildConnectionStatus(context, connectivity),
              loading: () => const CircularProgressIndicator(),
              error: (error, _) => Text('Error: $error'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(BuildContext context, ConnectivityResult connectivity) {
    IconData icon;
    Color color;
    String status;

    switch (connectivity) {
      case ConnectivityResult.wifi:
        icon = Icons.wifi;
        color = Colors.green;
        status = 'Connected to Wi-Fi';
        break;
      case ConnectivityResult.mobile:
        icon = Icons.signal_cellular_4_bar;
        color = Colors.blue;
        status = 'Connected to Mobile Data';
        break;
      case ConnectivityResult.ethernet:
        icon = Icons.settings_ethernet;
        color = Colors.green;
        status = 'Connected to Ethernet';
        break;
      default:
        icon = Icons.wifi_off;
        color = Colors.red;
        status = 'No Connection';
    }

    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(status, style: TextStyle(color: color)),
      ],
    );
  }
}

class _NetworkInfoCard extends StatelessWidget {
  final AsyncValue<Map<String, String?>> networkInfoAsync;

  const _NetworkInfoCard(this.networkInfoAsync);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Network Information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            networkInfoAsync.when(
              data: (networkInfo) => _buildNetworkInfo(context, networkInfo),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Text('Error: $error'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkInfo(BuildContext context, Map<String, String?> networkInfo) {
    return Column(
      children: [
        _InfoRow(Icons.wifi, 'SSID', networkInfo['ssid'] ?? 'Not available'),
        _InfoRow(Icons.computer, 'IP Address', networkInfo['ip'] ?? 'Not available'),
        _InfoRow(Icons.router, 'Gateway', networkInfo['gateway'] ?? 'Not available'),
        _InfoRow(Icons.network_check, 'Subnet Mask', networkInfo['subnet'] ?? 'Not available'),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
