import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';

enum ToastType { success, error, warning, info }

class DreamToast {
  static OverlayEntry? _currentEntry;
  static Timer? _timer;

  static void show(BuildContext context, {
    required String message,
    required ToastType type,
    Duration duration = const Duration(seconds: 3),
  }) {
    _removeCurrent();

    _currentEntry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        type: type,
        onDismiss: _removeCurrent,
      ),
    );

    Overlay.of(context).insert(_currentEntry!);
    _timer = Timer(duration, _removeCurrent);
  }

  static void _removeCurrent() {
    _timer?.cancel();
    _currentEntry?.remove();
    _currentEntry = null;
  }

  static void success(BuildContext context, String message) {
    show(context, message: message, type: ToastType.success);
  }

  static void error(BuildContext context, String message) {
    show(context, message: message, type: ToastType.error);
  }

  static void warning(BuildContext context, String message) {
    show(context, message: message, type: ToastType.warning);
  }

  static void info(BuildContext context, String message) {
    show(context, message: message, type: ToastType.info);
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _accentColor {
    switch (widget.type) {
      case ToastType.success:
        return AppColors.success;
      case ToastType.error:
        return AppColors.error;
      case ToastType.warning:
        return AppColors.warning;
      case ToastType.info:
        return AppColors.cyan;
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case ToastType.success:
        return Icons.check_circle_outline;
      case ToastType.error:
        return Icons.error_outline;
      case ToastType.warning:
        return Icons.warning_amber_outlined;
      case ToastType.info:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 8;

    return Positioned(
      top: topPadding,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: GestureDetector(
              onTap: () {
                _controller.reverse().then((_) => widget.onDismiss());
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1527),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _accentColor.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(_icon, color: _accentColor, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: AppColors.geistMedium(12).copyWith(
                          color: AppColors.textMuted,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    Icon(Icons.close, color: AppColors.textMuted.withOpacity(0.4), size: 14),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
