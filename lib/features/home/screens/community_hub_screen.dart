import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/features/home/screens/home_content.dart';
import 'package:dream_community_app/features/media/screens/media_screen.dart';
import 'package:dream_community_app/features/journal/screens/journal_screen.dart';
import 'package:dream_community_app/features/book_club/screens/book_club_screen.dart';
import 'package:dream_community_app/features/profile/screens/profile_screen.dart';
import 'package:dream_community_app/shared/widgets/tier_lock_modal.dart';
import 'package:dream_community_app/shared/widgets/curved_bubble_nav_bar.dart';
import 'package:dream_community_app/features/auth/services/auth_service.dart';
import 'package:dream_community_app/shared/widgets/app_toast.dart';
import 'package:dream_community_app/core/services/pending_approval_sync_service.dart';
import 'package:dream_community_app/core/services/local_notification_service.dart';

class CommunityHubScreen extends StatefulWidget {
  final int initialIndex;

  const CommunityHubScreen({super.key, this.initialIndex = 0});

  @override
  State<CommunityHubScreen> createState() => _CommunityHubScreenState();
}

class _CommunityHubScreenState extends State<CommunityHubScreen> with WidgetsBindingObserver {
  late int _currentIndex;
  int _previousIndex = 0;
  bool _hasJournalAccess = false;
  bool _hasCommunityAccess = false;
  bool _isJournalCoverActive = true;

  final GlobalKey<HomeContentState> _homeKey = GlobalKey<HomeContentState>();
  final GlobalKey<MediaScreenState> _mediaKey = GlobalKey<MediaScreenState>();
  final GlobalKey<JournalScreenState> _journalKey = GlobalKey<JournalScreenState>();
  final GlobalKey<BookClubScreenState> _bookClubKey = GlobalKey<BookClubScreenState>();
  final GlobalKey<ProfileScreenState> _profileKey = GlobalKey<ProfileScreenState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _previousIndex = widget.initialIndex;
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();

    // Start listening for live super admin approval & user update events
    PendingApprovalSyncService.instance.onAccessUnlocked.addListener(_onAccessUnlockedLive);
    PendingApprovalSyncService.instance.onUserDataUpdated.addListener(_onUserDataLiveUpdated);
    PendingApprovalSyncService.instance.checkExistingPending();
    PendingApprovalSyncService.instance.startHeartbeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      LocalNotificationService.instance.checkAndConsumePendingRoute();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PendingApprovalSyncService.instance.onAccessUnlocked.removeListener(_onAccessUnlockedLive);
    PendingApprovalSyncService.instance.onUserDataUpdated.removeListener(_onUserDataLiveUpdated);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      PendingApprovalSyncService.instance.resumeHeartbeat();
      PendingApprovalSyncService.instance.syncNow();
      _checkPermissions();
      _syncActiveTab(_currentIndex);
      LocalNotificationService.instance.checkAndConsumePendingRoute();
    }
    // Keep heartbeat active in background when minimized in recent apps
  }

  void _onUserDataLiveUpdated() {
    if (mounted) {
      _checkPermissions();
      _syncActiveTab(_currentIndex);
    }
  }

  void _onAccessUnlockedLive() {
    if (PendingApprovalSyncService.instance.onAccessUnlocked.value && mounted) {
      _checkPermissions();
      _homeKey.currentState?.refresh();
      _journalKey.currentState?.refresh();
      _bookClubKey.currentState?.refresh();
      AppToast.show(
        context,
        '🎉 Membership Approved! All features are now unlocked.',
        type: ToastType.success,
      );
    }
  }

  void _syncActiveTab(int index) {
    switch (index) {
      case 0:
        _homeKey.currentState?.refresh();
        break;
      case 1:
        _mediaKey.currentState?.refresh();
        break;
      case 2:
        _journalKey.currentState?.refresh();
        break;
      case 3:
        _bookClubKey.currentState?.refresh();
        break;
      case 4:
        _profileKey.currentState?.refresh();
        break;
    }
  }

  void _switchTabDirect(int index) {
    if (index == _currentIndex) {
      _syncActiveTab(index);
      return;
    }
    if (mounted) {
      setState(() {
        _previousIndex = _currentIndex;
        _currentIndex = index;
      });
      _syncActiveTab(index);
    }
  }

  Future<void> _checkPermissions() async {
    // 0. Immediate local pref fallback — set right after purchase
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('has_journal_access') == true && !_hasJournalAccess) {
        setState(() => _hasJournalAccess = true);
      }
    } catch (_) {}

    // 1. Immediate instant check from local cache to avoid UI lock lag
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataStr = prefs.getString('user_data');
      if (userDataStr != null) {
        final map = jsonDecode(userDataStr);
        final rawTier = (map['tier'] ?? 'free').toString().toLowerCase().trim();
        final isNonFreeTier = rawTier.isNotEmpty && rawTier != 'free' && rawTier != 'guest';
        final isNonJournalTier = isNonFreeTier && rawTier != 'journal';
        final role = (map['role'] ?? '').toString().toLowerCase();
        final isAdmin = role == 'admin' || role == 'super_admin' || map['has_admin_access'] == true || map['hasAdminAccess'] == true;

        final hasJournal = map['has_journal_access'] == true ||
            map['hasJournalAccess'] == true ||
            isNonFreeTier ||
            isAdmin;
        final hasComm = map['has_community_access'] == true ||
            map['hasCommunityAccess'] == true ||
            isNonJournalTier ||
            isAdmin;

        if (mounted) {
          setState(() {
            _hasJournalAccess = hasJournal;
            _hasCommunityAccess = hasComm;
          });
        }
      }
    } catch (_) {}

    // 3. Fresh user sync from API
    try {
      final user = await AuthService().getCurrentUser();
      if (user != null && mounted) {
        final rawTier = (user.tier ?? 'free').toLowerCase().trim();
        final isNonFreeTier = rawTier.isNotEmpty && rawTier != 'free' && rawTier != 'guest';
        final isNonJournalTier = isNonFreeTier && rawTier != 'journal';
        final isAdmin = user.hasAdminAccess || user.role == 'admin' || user.role == 'super_admin';

        setState(() {
          _hasJournalAccess = user.hasJournalAccess || isNonFreeTier || isAdmin;
          _hasCommunityAccess = user.hasCommunityAccess || isNonJournalTier || isAdmin;
        });
      }
    } catch (_) {}
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) {
      _syncActiveTab(index);
      return;
    }

    // Check Community Lock for Book Club (Index 3) - If not purchased, show modal
    if (index == 3 && !_hasCommunityAccess) {
      if (mounted) {
        TierLockModal.show(context, featureName: 'D.R.E.A.M. Book Club');
      }
      return;
    }

    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
      if (index == 2 && _hasJournalAccess) {
        _isJournalCoverActive = true;
      }
    });

    if (index == 2 && _hasJournalAccess) {
      _journalKey.currentState?.showCover();
    }

    // Auto re-sync active tab data upon switching
    _syncActiveTab(index);

    // Refresh permissions in background without blocking tab switch
    _checkPermissions();
  }

  @override
  Widget build(BuildContext context) {
    final bool hideNavBar = ((_currentIndex == 2 && !_hasJournalAccess) ||
        (_currentIndex == 2 && _isJournalCoverActive));

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) {
          _onTabTapped(_previousIndex == 3 ? 0 : _previousIndex);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            Positioned.fill(
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  HomeContent(
                    key: _homeKey,
                    onProfileTap: () => _onTabTapped(4),
                    onNavigate: (index) => _onTabTapped(index),
                    onNavigateMedia: (mediaTab) {
                      if (mediaTab != 0 && !_hasCommunityAccess) {
                        TierLockModal.show(
                          context,
                          featureName: mediaTab == 1
                              ? 'D.R.E.A.M Journal Episodes'
                              : 'D.R.E.A.M Activities Videos',
                        );
                        return;
                      }
                      _onTabTapped(1);
                      _mediaKey.currentState?.changeTab(mediaTab);
                    },
                  ),
                  MediaScreen(
                    key: _mediaKey,
                    initialTab: 0,
                    hasCommunityAccess: _hasCommunityAccess,
                  ),
                  JournalScreen(
                    key: _journalKey,
                    onNavigateHome: () => _switchTabDirect(0),
                    onJournalUnlocked: () {
                      _checkPermissions();
                    },
                    onCoverAnimationChanged: (isActive) {
                      if (mounted && _isJournalCoverActive != isActive) {
                        setState(() => _isJournalCoverActive = isActive);
                      }
                    },
                  ),
                  BookClubScreen(
                    key: _bookClubKey,
                    onNavigateHome: () =>
                        _onTabTapped(_previousIndex == 3 ? 0 : _previousIndex),
                  ),
                  ProfileScreen(
                    key: _profileKey,
                  ),
                ],
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeInOutCubic,
              left: 0,
              right: 0,
              bottom: hideNavBar ? -130.0 : 0.0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                opacity: hideNavBar ? 0.0 : 1.0,
                child: IgnorePointer(
                  ignoring: hideNavBar,
                  child: CurvedBubbleNavBar(
                    currentIndex: _currentIndex,
                    onTap: _onTabTapped,
                    items: [
                      const CurvedBubbleNavItem(
                        outlineIcon: Icons.home_outlined,
                        filledIcon: Icons.home_rounded,
                        label: 'Home',
                      ),
                      const CurvedBubbleNavItem(
                        outlineIcon: Icons.play_circle_outline_rounded,
                        filledIcon: Icons.play_circle_fill_rounded,
                        label: 'Media',
                      ),
                      CurvedBubbleNavItem(
                        outlineIcon: Icons.menu_book_outlined,
                        filledIcon: Icons.menu_book_rounded,
                        label: 'Journal',
                        isLocked: !_hasJournalAccess,
                      ),
                      CurvedBubbleNavItem(
                        outlineIcon: Icons.auto_stories_outlined,
                        filledIcon: Icons.auto_stories_rounded,
                        label: 'Book Club',
                        isLocked: !_hasCommunityAccess,
                      ),
                      const CurvedBubbleNavItem(
                        outlineIcon: Icons.person_outline_rounded,
                        filledIcon: Icons.person_rounded,
                        label: 'Profile',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
