import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dream_community_app/core/api/dio_client.dart';
import 'package:dream_community_app/core/api/api_endpoints.dart';
import 'package:dream_community_app/core/services/local_notification_service.dart';
import 'package:dream_community_app/shared/widgets/in_app_notification_banner.dart';

/// Central Real-Time Synchronization Engine for Dream Community App.
/// Handles:
/// 1. Fast sub-second polling (2.5s) for manual payment approvals (Venmo/CashApp).
/// 2. Live background heartbeat (12s) keeping User Profile, Tier permissions, and Role 100% in sync with the database.
/// 3. Real-time unread notification count badge stream.
/// 4. In-App Heads-Up & OS Local notification dispatch.
/// 5. App lifecycle resume resynchronization.
class PendingApprovalSyncService {
  PendingApprovalSyncService._();
  static final PendingApprovalSyncService instance = PendingApprovalSyncService._();

  Timer? _pollingTimer;
  Timer? _heartbeatTimer;
  int? _activePurchaseId;
  String _activeType = 'community';
  bool _isChecking = false;
  final Set<int> _seenNotificationIds = {};

  /// Global notifier that fires when a pending purchase or tier is approved/unlocked
  final ValueNotifier<bool> onAccessUnlocked = ValueNotifier<bool>(false);

  /// Global notifier that fires whenever user profile or permissions update from the server
  final ValueNotifier<Map<String, dynamic>?> onUserDataUpdated = ValueNotifier<Map<String, dynamic>?>(null);

  /// Global notifier for real-time unread notification badge count
  final ValueNotifier<int> unreadNotificationsCount = ValueNotifier<int>(0);

  /// Stores the most recent approval payload
  final ValueNotifier<Map<String, dynamic>?> lastApprovedData = ValueNotifier<Map<String, dynamic>?>(null);

  int? get activePurchaseId => _activePurchaseId;
  bool get isPolling => _pollingTimer != null && _pollingTimer!.isActive;

  /// Start background heartbeat (every 12 seconds) while the app is active
  void startHeartbeat() {
    if (_heartbeatTimer != null && _heartbeatTimer!.isActive) return;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      syncNow();
    });
    // Trigger initial sync immediately
    syncNow();
  }

  /// Pause heartbeat when app enters background
  void pauseHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Resume heartbeat when app returns to foreground
  void resumeHeartbeat() {
    startHeartbeat();
  }

  /// Instant, on-demand synchronization pass (invoked on app resume, tab switch, or pull-to-refresh)
  Future<void> syncNow() async {
    if (_isChecking) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) return;

    _isChecking = true;
    try {
      final response = await DioClient().dio.get(
        '/tier/check-pending',
        queryParameters: {'_t': DateTime.now().millisecondsSinceEpoch},
      );
      final data = response.data;
      if (data != null && data['success'] == true) {
        // 1. Update live unread notification badge count
        if (data['unread_notifications'] != null) {
          final count = (data['unread_notifications'] as num).toInt();
          if (unreadNotificationsCount.value != count) {
            unreadNotificationsCount.value = count;
          }
        }

        // 2. Dispatch In-App & OS Local Notification if a fresh unread notification exists
        if (data['latest_notification'] != null) {
          final notif = data['latest_notification'] as Map<String, dynamic>;
          final notifId = (notif['id'] as num).toInt();

          final alreadyShown = _seenNotificationIds.contains(notifId);
          debugPrint('[PendingSync] Latest notification: #$notifId ("${notif['title']}") | AlreadyShown: $alreadyShown');

          if (!alreadyShown) {
            _seenNotificationIds.add(notifId);

            final title = (notif['title'] ?? 'D.R.E.A.M. Alert').toString();
            final message = (notif['message'] ?? '').toString();
            final type = (notif['type'] ?? 'info').toString();
            final link = notif['link']?.toString();

            debugPrint('[PendingSync] Triggering In-App Banner & Local Notification for #$notifId: $title');

            InAppNotificationBannerService.instance.show(
              id: notifId,
              title: title,
              message: message,
              type: type,
              link: link,
            );

            LocalNotificationService.instance.showNotification(
              id: notifId,
              title: title,
              body: message,
              payload: link,
            );
          }
        }

        // 3. Check pending purchase status
        if (data['has_pending'] == true && data['purchase_id'] != null) {
          final pId = data['purchase_id'] as int;
          final pTier = (data['tier'] ?? 'community').toString();
          if (!isPolling) {
            startPolling(purchaseId: pId, type: pTier);
          }
        } else if (data['recently_approved'] == true && data['user'] != null) {
          await _applyApproval(data['user'], data['tier'] ?? 'community');
          lastApprovedData.value = data;
          onAccessUnlocked.value = true;
        }

        // 3. Detect if server permissions or user data changed dynamically
        if (data['user'] != null) {
          final freshUser = data['user'] as Map<String, dynamic>;
          final cachedStr = prefs.getString('user_data');
          bool hasChanged = false;

          if (cachedStr != null) {
            try {
              final cachedUser = jsonDecode(cachedStr) as Map<String, dynamic>;
              final oldTier = (cachedUser['tier'] ?? '').toString();
              final newTier = (freshUser['tier'] ?? '').toString();
              final oldRole = (cachedUser['role'] ?? '').toString();
              final newRole = (freshUser['role'] ?? '').toString();
              final oldJournal = cachedUser['has_journal_access'] == true || cachedUser['hasJournalAccess'] == true;
              final newJournal = freshUser['has_journal_access'] == true || freshUser['hasJournalAccess'] == true;
              final oldComm = cachedUser['has_community_access'] == true || cachedUser['hasCommunityAccess'] == true;
              final newComm = freshUser['has_community_access'] == true || freshUser['hasCommunityAccess'] == true;

              if (oldTier != newTier || oldRole != newRole || oldJournal != newJournal || oldComm != newComm) {
                hasChanged = true;
              }
            } catch (_) {
              hasChanged = true;
            }
          } else {
            hasChanged = true;
          }

          if (hasChanged) {
            await prefs.setString('user_data', jsonEncode(freshUser));
            await prefs.setBool(
              'has_journal_access',
              freshUser['has_journal_access'] == true || freshUser['hasJournalAccess'] == true,
            );
            onUserDataUpdated.value = freshUser;
            onAccessUnlocked.value = true;
          }
        }
      }
    } catch (e) {
      debugPrint('[PendingSync] syncNow error: $e');
    } finally {
      _isChecking = false;
    }
  }

  /// Start fast active polling (every 2.5s) for a specific purchase ID
  Future<void> startPolling({
    required int purchaseId,
    String type = 'community',
    Function(Map<String, dynamic> data)? onApproved,
  }) async {
    _activePurchaseId = purchaseId;
    _activeType = type;

    // Save locally so polling can resume if user navigates or reloads
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pending_purchase_id', purchaseId);
    await prefs.setString('pending_purchase_type', type);

    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) async {
      await _checkStatus(purchaseId, onApproved: onApproved);
    });

    // Run first check immediately
    _checkStatus(purchaseId, onApproved: onApproved);
  }

  /// Automatically check if there is an existing pending purchase on app start or tab change
  Future<void> checkExistingPending() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getInt('pending_purchase_id');
    final savedType = prefs.getString('pending_purchase_type') ?? 'community';

    if (savedId != null && savedId > 0) {
      startPolling(purchaseId: savedId, type: savedType);
      return;
    }

    await syncNow();
  }

  /// Alias for checkExistingPending for callers resuming pending approvals
  Future<void> checkAndResumePending() => checkExistingPending();

  Future<void> _checkStatus(int purchaseId, {Function(Map<String, dynamic> data)? onApproved}) async {
    try {
      final endpoint = _activeType == 'merch'
          ? '/mobile/merch/order-status/$purchaseId'
          : '${ApiEndpoints.communityTier}/status/$purchaseId';

      final response = await DioClient().dio.get(
        endpoint,
        queryParameters: {'_t': DateTime.now().millisecondsSinceEpoch},
      );
      final data = response.data;

      if (data != null && data['success'] == true) {
        final isApproved = data['is_approved'] == true ||
            data['status'] == 'completed' ||
            data['status'] == 'confirmed';

        if (isApproved) {
          stopPolling();

          final isMerch = _activeType == 'merch';
          final orderNum = data['order_number'] ?? purchaseId;
          final title = isMerch ? 'Order Approved! 📦' : 'Access Unlocked! 🎉';
          final message = isMerch
              ? 'Your merchandise order #$orderNum has been confirmed by Super Admin!'
              : 'Your D.R.E.A.M. payment has been approved! All features are now unlocked.';

          InAppNotificationBannerService.instance.show(
            id: purchaseId,
            title: title,
            message: message,
            type: 'success',
            link: isMerch ? '/notifications' : '/home',
          );

          LocalNotificationService.instance.showNotification(
            id: purchaseId,
            title: title,
            body: message,
            payload: isMerch ? '/notifications' : '/home',
          );

          if (_activeType != 'merch') {
            final user = data['user'] as Map<String, dynamic>?;
            final tier = data['tier'] ?? _activeType;
            await _applyApproval(user, tier);
          } else {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('pending_purchase_id');
            await prefs.remove('pending_purchase_type');
          }

          lastApprovedData.value = data;
          onAccessUnlocked.value = true;
          onApproved?.call(data);
        }
      }
    } catch (e) {
      // Continue polling silently on temporary network dips
    }
  }

  Future<void> _applyApproval(Map<String, dynamic>? user, String tier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_purchase_id');
    await prefs.remove('pending_purchase_type');

    if (user != null) {
      await prefs.setString('user_data', jsonEncode(user));
      await prefs.setBool(
        'has_journal_access',
        user['has_journal_access'] == true || user['hasJournalAccess'] == true,
      );
      onUserDataUpdated.value = user;
    } else {
      // Fallback
      if (tier == 'journal') {
        await prefs.setBool('has_journal_access', true);
      }
    }
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _activePurchaseId = null;
  }

  /// Notification badge helpers
  void setUnread(int count) {
    unreadNotificationsCount.value = count;
  }

  void decrementUnread([int amount = 1]) {
    unreadNotificationsCount.value = (unreadNotificationsCount.value - amount).clamp(0, 999);
  }

  void clearUnread() {
    unreadNotificationsCount.value = 0;
  }
}
