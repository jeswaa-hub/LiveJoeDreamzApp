import 'package:flutter/material.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'error_page.dart';

class UnauthorizedPage extends StatelessWidget {
  const UnauthorizedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ErrorPage(
      errorCode: '401',
      title: 'Login Required',
      subtitle: 'You need to be logged in to access this feature.',
      icon: Icons.lock_outline_rounded,
      accentColor: AppColors.pink,
      buttonText: 'LOGIN',
      onButtonTap: () {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      },
      secondaryButtonText: 'GO HOME',
      onSecondaryButtonTap: () {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      },
    );
  }
}
