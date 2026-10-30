import 'package:dio/dio.dart';
import 'package:dream_community_app/core/config/api_config.dart';
import 'package:dream_community_app/core/network/network_status_service.dart';
import 'package:dream_community_app/core/route/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DioClient {
  static DioClient? _instance;
  static String? _cachedToken;
  late final Dio _dio;

  DioClient._() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.timeout,
      receiveTimeout: ApiConfig.timeout,
      headers: {
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (_cachedToken == null || _cachedToken!.isEmpty) {
          final prefs = await SharedPreferences.getInstance();
          _cachedToken = prefs.getString('auth_token');
        }
        if (_cachedToken != null && _cachedToken!.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $_cachedToken';
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        // Successful response marks network as online
        NetworkStatusService.instance.setOnline();
        handler.next(response);
      },
      onError: (error, handler) async {
        // 1. Check for connection / socket / timeout drops
        if (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.sendTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.connectionError) {
          NetworkStatusService.instance.setOffline();
        }

        // 2. Sanctum 401 Unauthorized handling
        final statusCode = error.response?.statusCode;
        final path = error.requestOptions.path;
        final isAuthEndpoint = path.contains('/auth/login') ||
            path.contains('/auth/register') ||
            path.contains('/auth/forgot-password');

        if (statusCode == 401 && !isAuthEndpoint) {
          // Invalidate stored token
          _cachedToken = null;
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('auth_token');

          // Smoothly route to TokenExpiredPage
          AppRoutes.navigatorKey.currentState?.pushNamedAndRemoveUntil(
            '/error/token-expired',
            (route) => false,
          );
        }

        handler.next(error);
      },
    ));
  }

  factory DioClient() {
    _instance ??= DioClient._();
    return _instance!;
  }

  static void setToken(String? token) {
    _cachedToken = token;
  }

  static void clearToken() {
    _cachedToken = null;
  }

  Dio get dio => _dio;
}
