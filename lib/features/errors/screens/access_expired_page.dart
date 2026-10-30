import 'package:flutter/material.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'error_page.dart';

class AccessExpiredPage extends StatelessWidget {
  const AccessExpiredPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ErrorPage(
      title: 'Access Expired',
      subtitle: 'Your membership has expired. Please repurchase to continue.',
      icon: Icons.card_membership_rounded,
      accentColor: AppColors.pink,
      buttonText: 'RENEW ACCESS',
      onButtonTap: () {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      },
      secondaryButtonText: 'VIEW PROFILE',
      onSecondaryButtonTap: () {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        Navigator.of(context).pushNamed('/profile');
      },
    );
  }
}
