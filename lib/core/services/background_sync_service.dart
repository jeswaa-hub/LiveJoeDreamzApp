import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dream_community_app/core/config/api_config.dart';

/// Background Notification Polling Engine for Dream Community App.
/// Keeps polling the local API for approvals & order updates even when the user
/// is outside the app on the phone's Android Home Screen or using another app.
class BackgroundSyncService {
  BackgroundSyncService._();
  static final BackgroundSyncService instance = BackgroundSyncService._();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    debugPrint('[BackgroundSyncService] Production FCM & PendingApprovalSyncService active.');
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onBackgroundServiceStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });

    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }

  final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const darwinInit = DarwinInitializationSettings();
  const initSettings = InitializationSettings(android: androidInit, iOS: darwinInit);
  await notificationsPlugin.initialize(settings: initSettings);

  const String channelId = 'dream_community_notifications_v2';
  const String channelName = 'D.R.E.A.M. Community Alerts';

  // Run periodic background polling every 12 seconds
  Timer.periodic(const Duration(seconds: 12), (timer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null || token.isEmpty) return;

      final url = Uri.parse('${ApiConfig.baseUrl}/tier/check-pending?_t=${DateTime.now().millisecondsSinceEpoch}');
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['latest_notification'] != null) {
          final notif = data['latest_notification'] as Map<String, dynamic>;
          final notifId = (notif['id'] as num).toInt();

          final seenIds = prefs.getStringList('seen_bg_notification_ids') ?? [];
          final isSeen = seenIds.contains(notifId.toString());

          if (!isSeen) {
            seenIds.add(notifId.toString());
            // Keep at most 50 IDs in storage
            if (seenIds.length > 50) {
              seenIds.removeRange(0, seenIds.length - 50);
            }
            await prefs.setStringList('seen_bg_notification_ids', seenIds);

            final title = (notif['title'] ?? 'D.R.E.A.M. Alert').toString();
            final message = (notif['message'] ?? '').toString();
            final link = notif['link']?.toString();

            final androidDetails = AndroidNotificationDetails(
              channelId,
              channelName,
              channelDescription: 'Real-time approvals and order updates',
              importance: Importance.max,
              priority: Priority.max,
              ticker: title,
              icon: '@mipmap/ic_launcher',
              playSound: true,
              enableVibration: true,
              visibility: NotificationVisibility.public,
              category: AndroidNotificationCategory.message,
            );

            final notificationDetails = NotificationDetails(
              android: androidDetails,
              iOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            );

            await notificationsPlugin.show(
              id: notifId,
              title: title,
              body: message,
              notificationDetails: notificationDetails,
              payload: (link != null && link.startsWith('/')) ? link : '/notifications',
            );
          }
        }
      }
    } catch (e) {
      // Continue silently on brief background network dips
    }
  });
}
