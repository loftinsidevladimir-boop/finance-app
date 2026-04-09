import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

/// true если есть хоть одно активное подключение (wifi, mobile, ethernet и т.д.)
final isOnlineProvider = Provider<bool>((ref) {
  final result = ref.watch(connectivityProvider).valueOrNull;
  if (result == null) return true; // оптимистично до первого события
  return result.any((r) => r != ConnectivityResult.none);
});
