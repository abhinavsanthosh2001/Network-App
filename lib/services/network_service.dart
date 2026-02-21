import 'package:network_info_plus/network_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class NetworkService {
  final NetworkInfo _networkInfo = NetworkInfo();
  final Connectivity _connectivity = Connectivity();

  Future<Map<String, String?>> getNetworkInfo() async {
    if (kIsWeb) {
      return {
        'ssid': 'Not supported on web',
        'ip': 'Run on Android/iOS',
        'gateway': null,
        'subnet': null,
      };
    }
    
    try {
      final status = await Permission.location.request();
      
      if (!status.isGranted) {
        return {
          'ssid': 'Permission denied',
          'ip': null,
          'gateway': null,
          'subnet': null,
        };
      }

      final wifiName = await _networkInfo.getWifiName();
      final wifiIP = await _networkInfo.getWifiIP();
      final wifiGateway = await _networkInfo.getWifiGatewayIP();
      final wifiSubmask = await _networkInfo.getWifiSubmask();
      
      return {
        'ssid': wifiName?.replaceAll('"', ''),
        'ip': wifiIP,
        'gateway': wifiGateway,
        'subnet': wifiSubmask,
      };
    } catch (e) {
      return {
        'ssid': 'Error: $e',
        'ip': null,
        'gateway': null,
        'subnet': null,
      };
    }
  }

  Future<ConnectivityResult> getConnectionType() async {
    return await _connectivity.checkConnectivity();
  }

  Stream<ConnectivityResult> get connectivityStream => _connectivity.onConnectivityChanged;
}