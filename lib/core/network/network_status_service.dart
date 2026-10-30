import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dream_community_app/core/config/api_config.dart';

/// Singleton service that tracks connectivity state to the Laravel MySQL API.
class NetworkStatusService {
  NetworkStatusService._();
  static final NetworkStatusService instance = NetworkStatusService._();

  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);
  bool _wasOffline = false;
  Timer? _recoveryTimer;

  bool get isOnline => isOnlineNotifier.value;
  bool get wasOffline => _wasOffline;

  void setOffline() {
    if (isOnlineNotifier.value) {
      isOnlineNotifier.value = false;
      _wasOffline = true;
      _startRecoveryCheck();
    }
  }

  void setOnline() {
    _recoveryTimer?.cancel();
    if (!isOnlineNotifier.value) {
      isOnlineNotifier.value = true;
    }
  }

  void _startRecoveryCheck() {
    _recoveryTimer?.cancel();
    _recoveryTimer = Timer.periodic(const Duration(seconds: 8), (timer) async {
      final success = await checkConnection();
      if (success) {
        timer.cancel();
        setOnline();
      }
    });
  }

  Future<bool> checkConnection() async {
    try {
      final uri = Uri.parse(ApiConfig.baseUrl);
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      return res.statusCode < 500;
    } catch (_) {
      return false;
    }
  }
}
