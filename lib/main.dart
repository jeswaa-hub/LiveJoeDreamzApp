import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/features/auth/screens/splash_screen.dart';
import 'package:dream_community_app/features/auth/screens/app_launch_loading_screen.dart';
import 'package:dream_community_app/features/auth/screens/login_screen.dart';
import 'package:dream_community_app/features/auth/screens/register_screen.dart';
import 'package:dream_community_app/features/home/screens/community_hub_screen.dart';
import 'package:dream_community_app/features/activities/screens/activities_screen.dart';
import 'package:dream_community_app/features/journal/screens/journal_screen.dart';
import 'package:dream_community_app/features/podcast/screens/podcast_screen.dart';
import 'package:dream_community_app/features/podcast/screens/podcast_apply_screen.dart';
import 'package:dream_community_app/features/events/screens/events_screen.dart';
import 'package:dream_community_app/features/merch/screens/merch_screen.dart';
import 'package:dream_community_app/features/chat/screens/chat_screen.dart';
import 'package:dream_community_app/features/newsletter/screens/newsletter_screen.dart';
import 'package:dream_community_app/features/profile/screens/profile_screen.dart';
import 'package:dream_community_app/features/profile/screens/notifications_screen.dart';
import 'package:dream_community_app/features/community_tier/screens/community_tier_screen.dart';
import 'package:dream_community_app/features/community_tier/screens/logged_in_tier_pricing_screen.dart';
import 'package:dream_community_app/features/errors/screens/error_pages.dart';
import 'package:dream_community_app/features/book_club/screens/book_club_screen.dart';
import 'package:dream_community_app/core/route/app_routes.dart';
import 'package:dream_community_app/shared/widgets/network_status_banner.dart';
import 'package:dream_community_app/core/services/local_notification_service.dart';
import 'package:dream_community_app/core/services/fcm_service.dart';
import 'package:dream_community_app/core/services/background_sync_service.dart';
import 'package:dream_community_app/core/services/pending_approval_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await LocalNotificationService.instance.initialize();
  await FcmService.instance.initialize();
  await BackgroundSyncService.instance.initialize();

  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.toString().contains('mouse_tracker') ||
        details.toString().contains('_debugDuringDeviceUpdate')) {
      return;
    }
    FlutterError.presentError(details);
  };

  final prefs = await SharedPreferences.getInstance();
  final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

  // Start background sync heartbeat globally on app boot
  PendingApprovalSyncService.instance.startHeartbeat();

  runApp(DreamApp(hasSeenOnboarding: hasSeenOnboarding));
}

class DreamApp extends StatelessWidget {
  final bool hasSeenOnboarding;
  const DreamApp({super.key, required this.hasSeenOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LivejoeDreamzApp',
      navigatorKey: AppRoutes.navigatorKey,
      builder: (context, child) => NetworkStatusBanner(child: child ?? const SizedBox.shrink()),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: hasSeenOnboarding ? const AppLaunchLoadingScreen() : const SplashScreen(),
      onGenerateRoute: (settings) {
        final rawName = settings.name ?? '';
        Uri uri;
        try {
          uri = Uri.parse(rawName);
        } catch (_) {
          uri = Uri(path: rawName);
        }

        String path = uri.path;
        if (!path.startsWith('/')) {
          path = '/$path';
        }
        if (path.length > 1 && path.endsWith('/')) {
          path = path.substring(0, path.length - 1);
        }
        final queryParams = uri.queryParameters;

        // 1. Events routing: /events, /events?event_id=11, /calendar/event/11, /events/11, /upcoming-events
        if (path == '/events' ||
            path.startsWith('/events/') ||
            path == '/calendar/event' ||
            path.startsWith('/calendar/event/') ||
            path == '/upcoming-events' ||
            path.startsWith('/upcoming-events/')) {
          int? eventId = int.tryParse(queryParams['event_id'] ?? queryParams['id'] ?? '');
          if (eventId == null) {
            final lastSeg = path.split('/').last;
            eventId = int.tryParse(lastSeg);
          }
          EventsScreen.globalHighlightedEventId.value = eventId;
          return AppRoutes.minimalistTransition(EventsScreen(initialEventId: eventId));
        }

        // 2. Chat routing: /chat, /chat?pillar=..., /chat?message_id=...
        if (path == '/chat' || path.startsWith('/chat/') || path == '/book-club/chat') {
          final pillar = queryParams['pillar'];
          final bookId = int.tryParse(queryParams['book_id'] ?? '');
          final messageId = queryParams['message_id'];
          ChatScreen.globalHighlightedMessageId.value = messageId;
          return AppRoutes.minimalistTransition(ChatScreen(
            initialPillar: pillar,
            initialBookId: bookId,
            initialMessageId: messageId,
          ));
        }

        // 3. Home routing: /home, /home?tab=...
        if (path == '/home') {
          final tab = int.tryParse(queryParams['tab'] ?? '') ?? 0;
          return AppRoutes.minimalistTransition(CommunityHubScreen(initialIndex: tab));
        }

        // 4. Standard App Routes Map
        final staticRoutes = <String, WidgetBuilder>{
          '/': (context) => hasSeenOnboarding ? const AppLaunchLoadingScreen() : const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/activities': (context) => const ActivitiesScreen(),
          '/journal': (context) => const JournalScreen(),
          '/podcast': (context) => const PodcastScreen(),
          '/podcast/apply': (context) => const PodcastApplyScreen(),
          '/merch': (context) => const MerchScreen(),
          '/book-club': (context) => const BookClubScreen(),
          '/newsletter': (context) => const NewsletterScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/notifications': (context) => const NotificationsScreen(),
          '/community-tier': (context) => const CommunityTierScreen(),
          '/community-tier/pricing': (context) => const LoggedInTierPricingScreen(),
          '/error/404': (context) => const NotFoundPage(),
          '/error/500': (context) => const ServerErrorPage(),
          '/error/no-internet': (context) => const NoInternetPage(),
          '/error/401': (context) => const UnauthorizedPage(),
          '/error/token-expired': (context) => const TokenExpiredPage(),
          '/error/load-failed': (context) => const LoadFailedPage(),
          '/error/access-expired': (context) => const AccessExpiredPage(),
        };

        final builder = staticRoutes[path];
        if (builder != null) {
          return AppRoutes.minimalistTransition(builder(context));
        }

        // 5. Intelligent Fallback: Never leave user stranded on a dead-end 404
        debugPrint('[onGenerateRoute] Unmatched route: $rawName (path: $path) -> gracefully defaulting to Home');
        return AppRoutes.minimalistTransition(const CommunityHubScreen(initialIndex: 0));
      },
    );
  }
}
