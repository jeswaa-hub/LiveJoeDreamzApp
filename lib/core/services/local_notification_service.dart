import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:dream_community_app/core/route/app_routes.dart';

/// Central OS-level local notification engine for Dream Community App.
/// Handles Android Heads-Up Notifications & iOS Darwin alerts with sound and vibration.
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const String _channelId = 'dream_community_notifications_v2';
  static const String _channelName = 'D.R.E.A.M. Community Alerts';
  static const String _channelDescription =
      'Real-time transaction approvals, community announcements, and book chat alerts.';

  /// Initialize local notifications engine
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
      );

      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create Android Notification Channel
      if (!kIsWeb && Platform.isAndroid) {
        final androidImpl = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl != null) {
          await androidImpl.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDescription,
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
            ),
          );
          // Request POST_NOTIFICATIONS permission for Android 13+
          await androidImpl.requestNotificationsPermission();
        }
      }

      _isInitialized = true;

      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        final payload = launchDetails.notificationResponse?.payload;
        if (payload != null && payload.trim().isNotEmpty) {
          pendingRoute = payload.trim();
        } else {
          pendingRoute = '/notifications';
        }
        debugPrint('[LocalNotificationService] App launched from notification tap -> pendingRoute: $pendingRoute');
      }
    } catch (e) {
      debugPrint('[LocalNotificationService] Initialization error: $e');
    }
  }

  /// Trigger a heads-up system notification in the phone's notification shade
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        ticker: title,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.message,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[LocalNotificationService] Failed to show notification: $e');
    }
  }

  static String? pendingRoute;

  /// Handle notification tap when user taps OS notification drawer item
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    String targetRoute = '/notifications';
    if (payload != null && payload.trim().isNotEmpty) {
      targetRoute = payload.trim();
    }
    debugPrint('[LocalNotificationService] Notification tapped -> targetRoute: $targetRoute');

    final navContext = AppRoutes.navigatorKey.currentContext;
    if (navContext != null) {
      Navigator.of(navContext).pushNamed(targetRoute);
      pendingRoute = null;
    } else {
      pendingRoute = targetRoute;
    }
  }

  /// Consumes and pushes pending notification route once Navigator is ready
  void checkAndConsumePendingRoute() {
    if (pendingRoute == null) return;
    final route = pendingRoute!;
    pendingRoute = null;
    final navContext = AppRoutes.navigatorKey.currentContext;
    if (navContext != null) {
      debugPrint('[LocalNotificationService] Consuming pending route: $route');
      Navigator.of(navContext).pushNamed(route);
    }
  }
}
