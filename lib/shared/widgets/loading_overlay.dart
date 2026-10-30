import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';

class LoadingOverlay extends StatelessWidget {
  final String? message;
  final bool isVisible;

  const LoadingOverlay({super.key, this.message, this.isVisible = true});

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/DreamCommunityLogo.webp',
              width: 80,
              height: 80,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.cyan,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  message!,
                  style: GoogleFonts.geist(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class LoadingOverlayState {
  static OverlayEntry? _overlayEntry;

  static void show(BuildContext context, {String? message}) {
    hide();
    _overlayEntry = OverlayEntry(
      builder: (context) => LoadingOverlay(message: message, isVisible: true),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}
