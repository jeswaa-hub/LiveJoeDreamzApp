import 'package:flutter/material.dart';
import 'error_page.dart';

class ServerErrorPage extends StatelessWidget {
  const ServerErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ErrorPage(
      errorCode: '500',
      title: 'Server Error',
      subtitle: 'Something went wrong on our end. Please try again later.',
      icon: Icons.cloud_off_rounded,
      accentColor: const Color(0xFFFF6B6B),
      buttonText: 'RETRY',
      onButtonTap: () {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      },
    );
  }
}
