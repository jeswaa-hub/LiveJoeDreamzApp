import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dream_community_app/core/route/app_routes.dart';
import 'package:dream_community_app/core/services/local_notification_service.dart';
import 'package:dream_community_app/features/profile/services/notification_service.dart';

/// Top-level background isolate handler for Firebase Cloud Messaging.
/// Triggered when the app is in the background or killed state.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FcmService] Handling a background/killed-state message: ${message.messageId}');
  try {
    // If Firebase needs initialization in background isolate:
    await Firebase.initializeApp();
  } catch (_) {
    // Already initialized or config pending
  }

  final data = message.data;
  final title = message.notification?.title ?? data['title'];
  final body = message.notification?.body ?? data['body'];
  final link = data['link'] ?? data['payload'];

  // If payload is data-only (no system tray notification attached automatically),
  // display it via LocalNotificationService so the user receives a heads-up alert.
  if (message.notification == null && title != null && body != null) {
    await LocalNotificationService.instance.showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title.toString(),
      body: body.toString(),
      payload: link?.toString(),
    );
  }
}

/// Firebase Cloud Messaging client engine for Dream Community App.
/// Handles token registration, killed-state deep linking, and heads-up notifications.
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final NotificationService _notificationService = NotificationService();
  bool _isInitialized = false;
  String? _currentToken;

  bool get isInitialized => _isInitialized;
  String? get currentToken => _currentToken;

  /// Initialize Firebase Messaging safely.
  /// Wrapped in try-catch so absence of google-services.json does not crash the app in dev.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Initialize Firebase App
      await Firebase.initializeApp();

      // 2. Set Background Message Handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 3. Request permissions (Heads-up alert, badge, sound)
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('[FcmService] Notification authorization status: ${settings.authorizationStatus}');

      // 4. Foreground presentation options (iOS & Android)
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 5. Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FcmService] Foreground message received: ${message.messageId}');
        _handleForegroundMessage(message);
      });

      // 6. Handle notification tap when app was minimized in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FcmService] Notification clicked from background: ${message.messageId}');
        _handleNotificationClick(message);
      });

      // 7. Handle cold start notification tap when app was killed
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FcmService] App launched from killed state via notification: ${initialMessage.messageId}');
        _handleNotificationClick(initialMessage);
      }

      // 8. Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) {
        _currentToken = newToken;
        registerTokenWithBackend();
      });

      _isInitialized = true;
      debugPrint('[FcmService] Initialized successfully.');
    } catch (e) {
      debugPrint('[FcmService] Initialization skipped or failed (config pending): $e');
    }
  }

  /// Handle incoming message while user is actively using the app.
  void _handleForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title'];
    final body = message.notification?.body ?? message.data['body'];
    final link = message.data['link'] ?? message.data['payload'];

    if (title != null && body != null) {
      LocalNotificationService.instance.showNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title.toString(),
        body: body.toString(),
        payload: link?.toString(),
      );
    }
  }

  /// Direct deep linking on notification tap (killed state or background).
  void _handleNotificationClick(RemoteMessage message) {
    final link = message.data['link'] ?? message.data['payload'];
    if (link == null || link.toString().trim().isEmpty) return;

    final targetRoute = link.toString().trim();
    debugPrint('[FcmService] Deep linking to targetRoute: $targetRoute');

    final navContext = AppRoutes.navigatorKey.currentContext;
    if (navContext != null) {
      Navigator.of(navContext).pushNamed(targetRoute);
      LocalNotificationService.pendingRoute = null;
    } else {
      LocalNotificationService.pendingRoute = targetRoute;
    }
  }

  /// Retrieve device token from Firebase and register it with Laravel backend.
  Future<void> registerTokenWithBackend() async {
    if (!_isInitialized) {
      await initialize();
    }
    if (!_isInitialized) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      _currentToken = token;

      String deviceType = 'android';
      if (!kIsWeb) {
        if (Platform.isIOS) {
          deviceType = 'ios';
        } else if (Platform.isAndroid) {
          deviceType = 'android';
        }
      }

      final success = await _notificationService.registerFcmToken(
        fcmToken: token,
        deviceType: deviceType,
      );

      debugPrint('[FcmService] Registered device token with backend: $success ($deviceType)');
    } catch (e) {
      debugPrint('[FcmService] Error registering token with backend: $e');
    }
  }

  /// Revoke and delete token on logout to prevent notification leakage.
  Future<void> revokeToken() async {
    try {
      final token = _currentToken ?? await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _notificationService.revokeFcmToken(token);
        await FirebaseMessaging.instance.deleteToken();
        _currentToken = null;
        debugPrint('[FcmService] Revoked and deleted device token.');
      }
    } catch (e) {
      debugPrint('[FcmService] Error revoking device token: $e');
    }
  }
}
