import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/features/activities/screens/activities_screen.dart';
import 'package:dream_community_app/features/journal/screens/journal_episodes_screen.dart';
import 'package:dream_community_app/features/podcast/screens/podcast_screen.dart';
import 'package:dream_community_app/features/podcast/screens/podcast_apply_screen.dart';
import 'package:dream_community_app/shared/widgets/tier_lock_modal.dart';
import 'package:dream_community_app/features/auth/services/auth_service.dart';
import 'package:dream_community_app/core/models/user_model.dart';

class MediaScreen extends StatefulWidget {
  final int initialTab;
  final bool? hasCommunityAccess;
  const MediaScreen({super.key, this.initialTab = 0, this.hasCommunityAccess});

  @override
  State<MediaScreen> createState() => MediaScreenState();
}

class MediaScreenState extends State<MediaScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late bool _hasCommunityAccess;
  bool _hasActivitiesAccess = false;
  bool _hasJournalVideosAccess = false;

  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();

  final GlobalKey<PodcastScreenState> _podcastKey = GlobalKey<PodcastScreenState>();
  final GlobalKey<JournalEpisodesScreenState> _journalEpisodesKey = GlobalKey<JournalEpisodesScreenState>();
  final GlobalKey<ActivitiesScreenState> _activitiesKey = GlobalKey<ActivitiesScreenState>();

  @override
  void initState() {
    super.initState();
    _hasCommunityAccess = widget.hasCommunityAccess ?? true;
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _initAccessAndTab();
  }

  @override
  void didUpdateWidget(MediaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasCommunityAccess != null && widget.hasCommunityAccess != _hasCommunityAccess) {
      setState(() => _hasCommunityAccess = widget.hasCommunityAccess!);
    }
  }

  void _onSearchChanged(String query) {
    _podcastKey.currentState?.setSearchQuery(query);
    _journalEpisodesKey.currentState?.setSearchQuery(query);
    _activitiesKey.currentState?.setSearchQuery(query);
  }

  Future<void> refresh() async {
    await _loadPermissions();
    switch (_tabController.index) {
      case 0:
        _podcastKey.currentState?.refresh();
        break;
      case 1:
        _journalEpisodesKey.currentState?.refresh();
        break;
      case 2:
        _activitiesKey.currentState?.refresh();
        break;
    }
  }

  Future<void> refreshAccess() async {
    await _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataStr = prefs.getString('user_data');
      UserModel? user;
      if (userDataStr != null) {
        user = UserModel.fromJson(jsonDecode(userDataStr));
      } else {
        user = await AuthService().getCurrentUser();
      }

      if (user != null && mounted) {
        final u = user;
        final hasComm = u.hasCommunityAccess || (widget.hasCommunityAccess ?? false);
        setState(() {
          _hasCommunityAccess = hasComm;
          _hasActivitiesAccess = u.hasActivitiesAccess || hasComm || u.hasAdminAccess;
          _hasJournalVideosAccess = u.hasJournalVideosAccess || hasComm || u.hasAdminAccess;
        });
      }
    } catch (_) {}
  }

  Future<void> _initAccessAndTab() async {
    await _loadPermissions();
    if (mounted) {
      // Automatically land users on accessible content if initial tab is locked
      if (_tabController.index == 2 && !_hasActivitiesAccess && !_hasCommunityAccess) {
        _tabController.animateTo(0);
      } else if (_tabController.index == 1 && !_hasJournalVideosAccess && !_hasCommunityAccess) {
        _tabController.animateTo(0);
      }
    }
  }

  void _onTabTapped(int index) {
    if (index == 0) {
      _tabController.animateTo(0);
      return;
    }
    if (index == 1 && !_hasJournalVideosAccess && !_hasCommunityAccess) {
      TierLockModal.show(context, featureName: 'D.R.E.A.M. Journal Episodes');
      return;
    }
    if (index == 2 && !_hasActivitiesAccess && !_hasCommunityAccess) {
      TierLockModal.show(context, featureName: 'D.R.E.A.M. Activities Videos');
      return;
    }
    _tabController.animateTo(index);
  }

  void changeTab(int index) {
    _onTabTapped(index);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isJournalLocked = !_hasJournalVideosAccess && !_hasCommunityAccess;
    final isActivitiesLocked = !_hasActivitiesAccess && !_hasCommunityAccess;

    return Scaffold(
      backgroundColor: AppColors.background, // 60% Dominant: Deep Space Obsidian (#051424)
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── TOP HEADER (Pure Typographic & Actions, Zero Gradient, Zero Bloat) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 4),
              child: Row(
                children: [
                  Text(
                    'MEDIA',
                    style: AppColors.soraBold(24).copyWith(
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  // "Be a Guest" Header Action (Visible on Podcast Tab)
                  if (_tabController.index == 0) ...[
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PodcastApplyScreen()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surface, // Solid 30% surface, zero gradient!
                          borderRadius: BorderRadius.circular(8), // Clean geometric, no badge pill
                          border: Border.all(color: AppColors.surfaceBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.mic_none_rounded, color: AppColors.cyan, size: 14),
                            const SizedBox(width: 5),
                            Text(
                              'Be a Guest',
                              style: AppColors.geistBold(11).copyWith(color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  // Search Toggle Icon Button
                  IconButton(
                    icon: Icon(
                      _isSearchOpen ? Icons.close_rounded : Icons.search_rounded,
                      color: _isSearchOpen ? AppColors.cyan : AppColors.textMuted,
                      size: 22,
                    ),
                    splashRadius: 20,
                    onPressed: () {
                      setState(() {
                        _isSearchOpen = !_isSearchOpen;
                        if (!_isSearchOpen) {
                          _searchController.clear();
                          _onSearchChanged('');
                        }
                      });
                    },
                  ),
                ],
              ),
            ),

            // ── EXPANDABLE MINIMALIST SEARCH BAR ──
            if (_isSearchOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surface, // Solid #0A1929 surface
                    borderRadius: BorderRadius.circular(10), // Clean geometric, no pill
                    border: Border.all(color: AppColors.cyan.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: AppColors.cyan, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          onChanged: _onSearchChanged,
                          style: AppColors.geistMedium(13).copyWith(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: _tabController.index == 0
                                ? 'Search podcast episodes...'
                                : (_tabController.index == 1
                                    ? 'Search journal episodes...'
                                    : 'Search activities videos...'),
                            hintStyle: AppColors.geistMedium(13).copyWith(
                              color: AppColors.textMuted.withOpacity(0.5),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                          child: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 16),
                        ),
                    ],
                  ),
                ),
              ),

            // ── SLEEK MINIMALIST UNDERLINE TABS (Apple Music / Spotify Style, Zero Pill) ──
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.06), width: 1),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                onTap: _onTabTapped,
                indicatorColor: AppColors.cyan, // 10% Electric Cyan Accent
                indicatorWeight: 2.5,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: AppColors.cyan,
                unselectedLabelColor: AppColors.textMuted.withOpacity(0.6),
                labelStyle: AppColors.soraBold(12),
                unselectedLabelStyle: AppColors.geistMedium(12),
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                tabs: [
                  const Tab(
                    child: Text('Podcast', maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Flexible(
                          child: Text(
                            'Journal Episodes',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isJournalLocked) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.lock_rounded, size: 11, color: AppColors.pink.withOpacity(0.85)),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Flexible(
                          child: Text(
                            'Activities Video',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isActivitiesLocked) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.lock_rounded, size: 11, color: AppColors.pink.withOpacity(0.85)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── TAB VIEWS ──
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: (!_hasCommunityAccess && (!_hasJournalVideosAccess || !_hasActivitiesAccess))
                    ? const NeverScrollableScrollPhysics()
                    : const AlwaysScrollableScrollPhysics(),
                children: [
                  PodcastScreen(key: _podcastKey),
                  JournalEpisodesScreen(key: _journalEpisodesKey),
                  ActivitiesScreen(key: _activitiesKey),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
