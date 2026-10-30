import 'package:flutter/material.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/core/models/notification_model.dart';
import 'package:dream_community_app/features/profile/services/notification_service.dart';
import 'package:dream_community_app/core/services/pending_approval_sync_service.dart';
import 'package:dream_community_app/shared/widgets/in_app_notification_banner.dart';
import 'package:dream_community_app/core/services/local_notification_service.dart';
import 'package:dream_community_app/shared/widgets/app_toast.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _service = NotificationService();
  List<AppNotification> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final notifications = await _service.getNotifications();
    if (mounted) {
      final unread = notifications.where((n) => !n.isRead).length;
      PendingApprovalSyncService.instance.setUnread(unread);
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteNotification(AppNotification notification, int index) async {
    final removed = notification;
    final removedIndex = index;

    setState(() {
      _notifications.removeAt(index);
    });

    if (!removed.isRead) {
      PendingApprovalSyncService.instance.decrementUnread();
    }

    final success = await _service.deleteNotification(removed.id);
    if (!success && mounted) {
      // Rollback if delete fails
      setState(() {
        _notifications.insert(removedIndex, removed);
      });
      AppToast.show(context, 'Failed to delete notification', type: ToastType.error);
    } else if (mounted) {
      AppToast.show(context, 'Notification deleted', type: ToastType.info);
    }
  }

  Future<void> _confirmClearAll() async {
    if (_notifications.isEmpty) return;

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        title: Text('Clear All Notifications', style: AppColors.soraBold(16).copyWith(color: Colors.white)),
        content: Text(
          'Are you sure you want to remove all notifications? This action cannot be undone.',
          style: AppColors.geistMedium(13).copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppColors.geistMedium(13).copyWith(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Text('Clear All', style: AppColors.geistBold(13).copyWith(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldClear == true && mounted) {
      final backup = List<AppNotification>.from(_notifications);
      setState(() {
        _notifications.clear();
      });
      PendingApprovalSyncService.instance.clearUnread();

      final success = await _service.clearAllNotifications();
      if (!success && mounted) {
        setState(() {
          _notifications = backup;
        });
        AppToast.show(context, 'Failed to clear notifications', type: ToastType.error);
      } else if (mounted) {
        AppToast.show(context, 'All notifications cleared', type: ToastType.info);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Notifications', style: AppColors.soraBold(16)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_rounded, color: AppColors.cyan, size: 20),
            tooltip: 'Send Test Notification',
            onPressed: () {
              final testId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
              InAppNotificationBannerService.instance.show(
                id: testId,
                title: 'D.R.E.A.M. Alert! 🔔',
                message: 'In-app notification banner is working properly!',
                type: 'success',
                link: '/notifications',
              );
              LocalNotificationService.instance.showNotification(
                id: testId,
                title: 'D.R.E.A.M. Alert! 🔔',
                body: 'In-app notification banner is working properly!',
                payload: '/notifications',
              );
            },
          ),
          if (_notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () async {
                PendingApprovalSyncService.instance.clearUnread();
                await _service.markAllAsRead();
                _loadNotifications();
              },
              child: Text('Read all', style: AppColors.geistMedium(12).copyWith(color: AppColors.cyan)),
            ),
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.textMuted, size: 20),
              tooltip: 'Clear All',
              onPressed: _confirmClearAll,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.cyan, strokeWidth: 2))
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none, color: AppColors.textMuted.withOpacity(0.3), size: 48),
                      const SizedBox(height: 12),
                      Text('No notifications yet', style: AppColors.geistMedium(13).copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: AppColors.cyan,
                  backgroundColor: AppColors.surface,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      return _dismissibleNotificationItem(n, index);
                    },
                  ),
                ),
    );
  }

  Widget _dismissibleNotificationItem(AppNotification notification, int index) {
    return Dismissible(
      key: ValueKey('notif_${notification.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFF5252).withOpacity(0.18),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFF5252).withOpacity(0.35)),
        ),
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF5252), size: 20),
            const SizedBox(width: 6),
            Text('Delete', style: AppColors.geistBold(12).copyWith(color: const Color(0xFFFF5252))),
          ],
        ),
      ),
      onDismissed: (_) => _deleteNotification(notification, index),
      child: _notificationItem(notification, index),
    );
  }

  Widget _notificationItem(AppNotification notification, int index) {
    IconData icon;
    Color iconColor;

    switch (notification.type) {
      case 'book_club_chat':
      case 'chat':
        icon = Icons.forum_rounded;
        iconColor = AppColors.cyan;
        break;
      case 'event_new':
      case 'event':
        icon = Icons.event_available_rounded;
        iconColor = AppColors.cyan;
        break;
      case 'success':
        icon = Icons.check_circle_outline;
        iconColor = const Color(0xFF69F0AE);
        break;
      case 'warning':
        icon = Icons.warning_amber_outlined;
        iconColor = const Color(0xFFFFD740);
        break;
      case 'error':
        icon = Icons.error_outline;
        iconColor = const Color(0xFFFF5252);
        break;
      default:
        icon = Icons.info_outline;
        iconColor = AppColors.cyan;
    }

    final cleanMessage = notification.message.replaceAll('_', ' ');

    return GestureDetector(
      onTap: () {
        if (!notification.isRead) {
          PendingApprovalSyncService.instance.decrementUnread();
          setState(() {
            _notifications[index] = notification.copyWith(isRead: true);
          });
          _service.markAsRead(notification.id);
        }
        if (notification.link != null && notification.link!.trim().isNotEmpty) {
          Navigator.pushNamed(context, notification.link!.trim()).then((_) {
            if (mounted) _loadNotifications();
          });
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: notification.isRead
              ? AppColors.surface.withOpacity(0.2)
              : AppColors.surface.withOpacity(0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: notification.isRead
                ? Colors.white.withOpacity(0.04)
                : AppColors.cyan.withOpacity(0.12),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: AppColors.geistBold(13).copyWith(
                            color: notification.isRead ? AppColors.textSecondary : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6, right: 4),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.cyan,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cleanMessage,
                    style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        notification.timeAgo,
                        style: AppColors.geistMedium(10).copyWith(color: AppColors.textMuted.withOpacity(0.6)),
                      ),
                      GestureDetector(
                        onTap: () => _deleteNotification(notification, index),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.textMuted.withOpacity(0.45),
                            size: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
