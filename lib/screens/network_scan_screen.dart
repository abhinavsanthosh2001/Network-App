import 'package:flutter/material.dart';

class NetworkScanScreen extends StatelessWidget {
  const NetworkScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Scan'),
      ),
      body: const Center(
        child: Text('Phase 3: LAN Device Scanner'),
      ),
    );
  }
}
