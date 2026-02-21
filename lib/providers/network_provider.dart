import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/network_service.dart';

final networkServiceProvider = Provider<NetworkService>((ref) => NetworkService());

final networkInfoProvider = FutureProvider<Map<String, String?>>((ref) async {
  final networkService = ref.read(networkServiceProvider);
  return await networkService.getNetworkInfo();
});

final connectivityProvider = StreamProvider<ConnectivityResult>((ref) {
  final networkService = ref.read(networkServiceProvider);
  return networkService.connectivityStream;
});