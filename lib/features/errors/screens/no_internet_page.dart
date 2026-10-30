import 'package:flutter/material.dart';
import 'error_page.dart';

class NoInternetPage extends StatelessWidget {
  const NoInternetPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ErrorPage(
      title: 'No Internet Connection',
      subtitle: 'Please check your WiFi or mobile data and try again.',
      icon: Icons.wifi_off_rounded,
      accentColor: const Color(0xFFFF9F43),
      buttonText: 'TRY AGAIN',
      onButtonTap: () {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      },
    );
  }
}
