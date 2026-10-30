import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/core/route/app_routes.dart';

/// Central In-App Heads-Up Notification Service for Dream Community App.
/// Uses Flutter's global Overlay to guarantee the banner appears smoothly on TOP
/// of any active screen, dialog, tab, or modal.
class InAppNotificationBannerService {
  InAppNotificationBannerService._();
  static final InAppNotificationBannerService instance =
      InAppNotificationBannerService._();

  OverlayEntry? _currentEntry;
  Timer? _dismissTimer;
  Map<String, dynamic>? _queuedBanner;

  /// Display a floating, glassmorphic heads-up banner at the top of the viewport
  bool show({
    required int id,
    required String title,
    required String message,
    String type = 'info',
    String? link,
  }) {
    debugPrint('[InAppNotificationBanner] show() -> id: $id, title: "$title", type: $type');

    // Remove any currently displayed banner cleanly
    dismiss();

    final overlay = AppRoutes.navigatorKey.currentState?.overlay;
    if (overlay == null) {
      debugPrint('[InAppNotificationBanner] Overlay is null right now, queueing banner for next active frame.');
      _queuedBanner = {
        'id': id,
        'title': title,
        'message': message,
        'type': type,
        'link': link,
      };
      // Try again shortly when navigation / frame settles
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_queuedBanner != null) {
          final pending = _queuedBanner!;
          _queuedBanner = null;
          show(
            id: pending['id'] as int,
            title: pending['title'] as String,
            message: pending['message'] as String,
            type: pending['type'] as String,
            link: pending['link'] as String?,
          );
        }
      });
      return false;
    }

    _queuedBanner = null;
    _currentEntry = OverlayEntry(
      builder: (context) => _InAppBannerWidget(
        id: id,
        title: title,
        message: message,
        type: type,
        link: link,
        onDismiss: dismiss,
      ),
    );

    overlay.insert(_currentEntry!);

    // Automatically dismiss after 4.5 seconds
    _dismissTimer = Timer(const Duration(milliseconds: 4500), () {
      dismiss();
    });
    return true;
  }

  /// Dismiss the active banner
  void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    if (_currentEntry != null) {
      try {
        _currentEntry?.remove();
      } catch (_) {}
      _currentEntry = null;
    }
  }
}

class _InAppBannerWidget extends StatefulWidget {
  final int id;
  final String title;
  final String message;
  final String type;
  final String? link;
  final VoidCallback onDismiss;

  const _InAppBannerWidget({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.link,
    required this.onDismiss,
  });

  @override
  State<_InAppBannerWidget> createState() => _InAppBannerWidgetState();
}

class _InAppBannerWidgetState extends State<_InAppBannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _animController.forward();
  }

  void _close() {
    if (mounted && _animController.status != AnimationStatus.dismissed) {
      _animController.reverse().then((_) {
        widget.onDismiss();
      });
    } else {
      widget.onDismiss();
    }
  }

  void _onTap() {
    _close();
    final navContext = AppRoutes.navigatorKey.currentContext;
    if (navContext != null) {
      if (widget.link != null && widget.link!.trim().isNotEmpty) {
        Navigator.of(navContext).pushNamed(widget.link!.trim());
      } else {
        Navigator.of(navContext).pushNamed('/notifications');
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;

    Color accentColor;
    IconData iconData;

    switch (widget.type) {
      case 'book_club_chat':
      case 'chat':
        accentColor = AppColors.cyan;
        iconData = Icons.forum_rounded;
        break;
      case 'event_new':
      case 'event':
        accentColor = AppColors.cyan;
        iconData = Icons.event_available_rounded;
        break;
      case 'success':
        accentColor = const Color(0xFF69F0AE);
        iconData = Icons.check_circle_rounded;
        break;
      case 'warning':
        accentColor = const Color(0xFFFFD740);
        iconData = Icons.warning_amber_rounded;
        break;
      case 'error':
        accentColor = const Color(0xFFFF5252);
        iconData = Icons.error_outline_rounded;
        break;
      default:
        accentColor = AppColors.cyan;
        iconData = Icons.notifications_active_rounded;
    }

    return Positioned(
      top: topPadding + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Dismissible(
            key: ValueKey('alert_${widget.id}_${widget.title}'),
            direction: DismissDirection.up,
            onDismissed: (_) => _close(),
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: _onTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A1929).withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.22),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.7),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Accent Icon
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          iconData,
                          color: accentColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Text content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.title,
                                    style: AppColors.soraBold(13).copyWith(
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Now',
                                  style: AppColors.geistMedium(10).copyWith(
                                    color: AppColors.textMuted.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.message,
                              style: AppColors.geistMedium(12).copyWith(
                                color: AppColors.textSecondary,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Close button
                      GestureDetector(
                        onTap: _close,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2, left: 4),
                          child: Icon(
                            Icons.close_rounded,
                            color: AppColors.textMuted.withValues(alpha: 0.6),
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
