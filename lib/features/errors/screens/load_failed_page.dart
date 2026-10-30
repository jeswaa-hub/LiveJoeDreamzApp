import 'package:flutter/material.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'error_page.dart';

class LoadFailedPage extends StatelessWidget {
  final VoidCallback? onRetry;
  const LoadFailedPage({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ErrorPage(
      title: 'Failed to Load',
      subtitle: 'Something went wrong while loading. Please try again.',
      icon: Icons.error_outline_rounded,
      accentColor: AppColors.cyan,
      buttonText: 'RETRY',
      onButtonTap: onRetry ?? () => Navigator.of(context).pop(),
      secondaryButtonText: 'GO BACK',
      onSecondaryButtonTap: () => Navigator.of(context).pop(),
    );
  }
}
