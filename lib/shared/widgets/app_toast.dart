import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppToast {
  static OverlayEntry? _currentEntry;

  static void show(BuildContext context, String message, {ToastType type = ToastType.info}) {
    try {
      _currentEntry?.remove();
    } catch (_) {}
    _currentEntry = null;

    if (!context.mounted) return;

    final config = _getConfig(type);
    final overlayState = Overlay.maybeOf(context);
    if (overlayState == null) return;

    _currentEntry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        config: config,
        onDismissed: () {
          try {
            _currentEntry?.remove();
          } catch (_) {}
          _currentEntry = null;
        },
      ),
    );

    overlayState.insert(_currentEntry!);

    Future.delayed(const Duration(seconds: 3), () {
      try {
        _currentEntry?.remove();
      } catch (_) {}
      _currentEntry = null;
    });
  }

  static Map<String, dynamic> _getConfig(ToastType type) {
    switch (type) {
      case ToastType.success:
        return {'color': const Color(0xFF22C55E), 'icon': Icons.check_circle_rounded};
      case ToastType.error:
        return {'color': const Color(0xFFEF4444), 'icon': Icons.error_rounded};
      case ToastType.warning:
        return {'color': const Color(0xFFF59E0B), 'icon': Icons.warning_rounded};
      case ToastType.info:
        return {'color': const Color(0xFF00DBE9), 'icon': Icons.info_rounded};
    }
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final Map<String, dynamic> config;
  final VoidCallback onDismissed;

  const _ToastWidget({required this.message, required this.config, required this.onDismissed});

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).viewPadding.top;

    return Positioned(
      top: topPadding + 16,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1527),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: widget.config['color'].withOpacity(0.3)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: widget.config['color'].withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(widget.config['icon'], color: widget.config['color'], size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.message, style: GoogleFonts.geist(fontSize: 13, color: Colors.white)),
                  ),
                  GestureDetector(
                    onTap: widget.onDismissed,
                    child: Icon(Icons.close, color: Colors.white.withOpacity(0.4), size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum ToastType { success, error, warning, info }
