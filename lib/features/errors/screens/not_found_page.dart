import 'package:flutter/material.dart';
import 'error_page.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ErrorPage(
      errorCode: '404',
      title: 'Page Not Found',
      subtitle: 'The page you\'re looking for doesn\'t exist or has been moved.',
      icon: Icons.search_off_rounded,
      buttonText: 'GO HOME',
      onButtonTap: () {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      },
    );
  }
}
