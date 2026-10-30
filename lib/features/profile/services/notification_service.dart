import 'package:dio/dio.dart';
import 'package:dream_community_app/core/api/dio_client.dart';
import 'package:dream_community_app/core/api/api_endpoints.dart';
import 'package:dream_community_app/core/models/notification_model.dart';

class NotificationService {
  final Dio _dio = DioClient().dio;

  Future<List<AppNotification>> getNotifications() async {
    try {
      final response = await _dio.get(ApiEndpoints.notifications);
      final raw = response.data;
      final data = raw is Map ? (raw['data'] ?? raw['value'] ?? raw) : raw;
      if (data is List) {
        return data.map((n) => AppNotification.fromJson(n as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> markAsRead(int notificationId) async {
    try {
      await _dio.post('${ApiEndpoints.notifications}/$notificationId/read');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> markEventAsRead({int? eventId}) async {
    try {
      await _dio.post(
        '${ApiEndpoints.notifications}/mark-event-read',
        data: eventId != null ? {'event_id': eventId} : {},
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> markLinkAsRead(String link) async {
    try {
      await _dio.post(
        '${ApiEndpoints.notifications}/mark-link-read',
        data: {'link': link},
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> markAllAsRead() async {
    try {
      await _dio.post('${ApiEndpoints.notifications}/read-all');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteNotification(int notificationId) async {
    try {
      await _dio.delete('${ApiEndpoints.notifications}/$notificationId');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> clearAllNotifications() async {
    try {
      await _dio.delete(ApiEndpoints.notifications);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Register or refresh device FCM token with backend
  Future<bool> registerFcmToken({
    required String fcmToken,
    required String deviceType,
    String? deviceId,
  }) async {
    try {
      await _dio.post(
        '${ApiEndpoints.notifications}/fcm-token',
        data: {
          'fcm_token': fcmToken,
          'device_type': deviceType,
          if (deviceId != null) 'device_id': deviceId,
        },
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Revoke device FCM token on logout
  Future<bool> revokeFcmToken(String fcmToken) async {
    try {
      await _dio.delete(
        '${ApiEndpoints.notifications}/fcm-token',
        data: {'fcm_token': fcmToken},
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}
