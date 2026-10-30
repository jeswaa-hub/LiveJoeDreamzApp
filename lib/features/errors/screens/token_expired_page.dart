import 'package:flutter/material.dart';
import 'error_page.dart';

class TokenExpiredPage extends StatelessWidget {
  const TokenExpiredPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ErrorPage(
      title: 'Session Expired',
      subtitle: 'Your session has expired. Please log in again to continue.',
      icon: Icons.timer_off_rounded,
      accentColor: const Color(0xFFFFC048),
      buttonText: 'LOGIN AGAIN',
      onButtonTap: () {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      },
    );
  }
}
