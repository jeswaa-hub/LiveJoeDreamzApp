import 'package:flutter/material.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';

class ErrorPage extends StatelessWidget {
  final String? errorCode;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final String? buttonText;
  final VoidCallback? onButtonTap;
  final String? secondaryButtonText;
  final VoidCallback? onSecondaryButtonTap;

  const ErrorPage({
    super.key,
    this.errorCode,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.accentColor = AppColors.cyan,
    this.buttonText,
    this.onButtonTap,
    this.secondaryButtonText,
    this.onSecondaryButtonTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon container
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor.withOpacity(0.15),
                        accentColor.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: accentColor.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(color: accentColor.withOpacity(0.1), blurRadius: 30),
                    ],
                  ),
                  child: Icon(icon, color: accentColor, size: 44),
                ),
                const SizedBox(height: 28),

                // Error code badge
                if (errorCode != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: accentColor.withOpacity(0.2)),
                    ),
                    child: Text(
                      'ERROR $errorCode',
                      style: AppColors.geistBold(10).copyWith(
                        color: accentColor,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Title
                Text(
                  title,
                  style: AppColors.soraBlack(26),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),

                // Subtitle
                Text(
                  subtitle,
                  style: AppColors.hankenMedium(14).copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),

                // Primary button
                if (buttonText != null)
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          colors: [accentColor, accentColor.withOpacity(0.8)],
                        ),
                        boxShadow: [
                          BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 12),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: onButtonTap,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child: Text(
                                buttonText!,
                                style: AppColors.geistBold(12).copyWith(
                                  color: AppColors.background,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Secondary button
                if (secondaryButtonText != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: onSecondaryButtonTap,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child: Text(
                                secondaryButtonText!,
                                style: AppColors.geistBold(12).copyWith(
                                  color: AppColors.textMuted,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
