import 'package:flutter/material.dart';
import 'package:dream_community_app/shared/widgets/minimalist_screen_loader.dart';

class AppRoutes {
  /// Global navigator key for system-level routing (401 token expiration, deep linking)
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Navigation transitions
  static Route<dynamic> minimalistTransition(Widget page) {
    return MinimalistPageRoute(page: page);
  }

  static Route<dynamic> fadeTransition(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        );
        return FadeTransition(
          opacity: curved,
          child: child,
        );
      },
    );
  }

  static Route<dynamic> slideTransition(Widget page, {Offset begin = const Offset(1.0, 0.0)}) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slide = Tween<Offset>(
          begin: begin,
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ));
        final fade = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.5),
        ));
        return SlideTransition(
          position: slide,
          child: FadeTransition(
            opacity: fade,
            child: child,
          ),
        );
      },
    );
  }

  static Route<dynamic> scaleTransition(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final scale = Tween<double>(
          begin: 0.8,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        ));
        final fade = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.5),
        ));
        return ScaleTransition(
          scale: scale,
          child: FadeTransition(
            opacity: fade,
            child: child,
          ),
        );
      },
    );
  }

  static Route<dynamic> slideFromBottom(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slide = Tween<Offset>(
          begin: const Offset(0.0, 0.3),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ));
        final fade = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.4),
        ));
        return SlideTransition(
          position: slide,
          child: FadeTransition(
            opacity: fade,
            child: child,
          ),
        );
      },
    );
  }
}
