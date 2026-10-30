import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:dream_community_app/core/config/api_config.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/core/models/podcast_model.dart';
import 'package:dream_community_app/core/models/merch_product_model.dart';
import 'package:dream_community_app/core/models/activity_model.dart';
import 'package:dream_community_app/core/models/event_model.dart';
import 'package:dream_community_app/core/models/journal_model.dart';
import 'package:dream_community_app/core/models/user_model.dart';
import 'package:dream_community_app/features/podcast/services/podcast_service.dart';
import 'package:dream_community_app/features/merch/services/merch_service.dart';
import 'package:dream_community_app/features/activities/services/activity_service.dart';
import 'package:dream_community_app/features/events/services/event_service.dart';
import 'package:dream_community_app/features/journal/services/journal_service.dart';
import 'package:dream_community_app/features/auth/services/auth_service.dart';
import 'package:dream_community_app/shared/widgets/skeleton.dart';
import 'package:dream_community_app/shared/widgets/tier_lock_modal.dart';
import 'package:dream_community_app/shared/widgets/minimalist_screen_loader.dart';
import 'package:dream_community_app/features/journal/widgets/journal_paywall_modal.dart';
import 'package:dream_community_app/features/community_tier/services/tier_service.dart';
import 'package:dream_community_app/features/merch/screens/product_detail_screen.dart';
import 'package:dream_community_app/shared/widgets/dream_network_image.dart';
import 'package:dream_community_app/core/services/pending_approval_sync_service.dart';

class HomeContent extends StatefulWidget {
  final VoidCallback? onProfileTap;
  final void Function(int index)? onNavigate;
  final void Function(int mediaTab)? onNavigateMedia;

  const HomeContent({super.key, this.onProfileTap, this.onNavigate, this.onNavigateMedia});

  @override
  State<HomeContent> createState() => HomeContentState();
}

class HomeContentState extends State<HomeContent> {
  List<PodcastModel> _podcasts = [];
  PodcastModel? _latestPodcast;
  List<MerchProductModel> _hotPicks = [];
  List<ActivityModel> _activities = [];
  EventModel? _nextEvent;
  List<JournalModel> _journals = [];
  UserModel? _user;
  double? _journalPrice;
  String _journalName = 'D.R.E.A.M. Journal';
  bool _podcastLoading = true;
  bool _merchLoading = true;
  bool _activityLoading = true;
  bool _eventLoading = true;
  bool _journalLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserFromCache();
    _loadData();
  }

  Future<void> refresh() async {
    await _loadUserFromCache();
    await _loadData();
  }

  Future<void> _loadUserFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user_data');
    if (mounted) {
      setState(() {
        if (userData != null) {
          try {
            final json = jsonDecode(userData) as Map<String, dynamic>;
            _user = UserModel.fromJson(json);
          } catch (_) {}
        }
      });
    }
  }

  Future<void> _loadData() async {
    TierService().getJournalInfo().then((info) {
      if (info != null && mounted) {
        setState(() {
          if (info['name'] != null) _journalName = info['name'];
          if (info['price'] != null) _journalPrice = (info['price'] as num).toDouble();
        });
      }
    });

    AuthService().getCurrentUser().then((user) {
      if (mounted && user != null) {
        setState(() => _user = user);
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString('user_data', jsonEncode({
            'id': user.id,
            'name': user.name,
            'email': user.email,
            'username': user.username,
            'role': user.role,
            'dream_role': user.dreamRole,
            'avatar_url': user.avatarUrl,
            'bio': user.bio,
            'location': user.location,
            'website': user.website,
            'phone': user.phone,
            'interests': user.interests,
            'badge_points': user.badgePoints,
            'show_in_directory': user.showInDirectory ? 1 : 0,
            'created_at': user.createdAt,
            'tier': user.tier,
            'has_journal_access': user.hasJournalAccess,
            'has_community_access': user.hasCommunityAccess,
            'has_admin_access': user.hasAdminAccess,
            'has_journal_videos_access': user.hasJournalVideosAccess,
            'has_activities_access': user.hasActivitiesAccess,
            'has_podcast_access': user.hasPodcastAccess,
            'has_chat_access': user.hasChatAccess,
            'has_events_access': user.hasEventsAccess,
            'has_merch_access': user.hasMerchAccess,
            'has_book_club_access': user.hasBookClubAccess,
            'allowed_routes': user.allowedRoutes,
          }));
        });
      }
    });

    PodcastService().getEpisodes().then((podcasts) {
      if (mounted) {
        setState(() {
          _podcasts = podcasts;
          _latestPodcast = podcasts.isNotEmpty ? podcasts.first : null;
          _podcastLoading = false;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _podcastLoading = false);
    });

    MerchService().getProducts().then((products) {
      if (mounted) {
        setState(() {
          final sorted = List<MerchProductModel>.from(products);
          sorted.sort((a, b) => b.price.compareTo(a.price));
          _hotPicks = sorted.take(8).toList();
          _merchLoading = false;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _merchLoading = false);
    });

    ActivityService().getActivities().then((activities) {
      if (mounted) {
        setState(() {
          _activities = activities;
          _activityLoading = false;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _activityLoading = false);
    });

    EventService().getEvents(status: 'ongoing').then((events) {
      if (mounted) {
        setState(() {
          if (events.isNotEmpty) {
            _nextEvent = events.first;
          } else {
            EventService().getEvents(status: 'upcoming').then((upcoming) {
              if (mounted) {
                setState(() {
                  _nextEvent = upcoming.isNotEmpty ? upcoming.first : null;
                  _eventLoading = false;
                });
              }
            }).catchError((_) {
              if (mounted) setState(() => _eventLoading = false);
            });
            return;
          }
          _eventLoading = false;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _eventLoading = false);
    });

    JournalService().getJournals().then((journals) {
      if (mounted) {
        setState(() {
          _journals = journals.take(5).toList();
          _journalLoading = false;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _journalLoading = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final rawTier = (_user?.tier ?? '').toLowerCase().trim();
    final isTierMember = rawTier.isNotEmpty && rawTier != 'free' && rawTier != 'guest';
    final isNonJournalTier = isTierMember && rawTier != 'journal';
    final isAdmin = _user?.hasAdminAccess == true || _user?.role == 'admin' || _user?.role == 'super_admin';
    final bool hasCommunityAccess = _user?.hasCommunityAccess == true || isNonJournalTier || isAdmin;
    final bool hasJournalAccess = _user?.hasJournalAccess == true || isTierMember || isAdmin;
    final bool isFreeTier = !hasCommunityAccess && !hasJournalAccess;
    final bool hasBothAccess = hasCommunityAccess && hasJournalAccess;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppColors.cyan,
          backgroundColor: AppColors.surface,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left Side: Live Joe Dreamz Logo
                      Image.asset(
                        'assets/images/LiveJoeDreamzLogo.webp',
                        width: isSmallScreen ? 56 : 68,
                        height: isSmallScreen ? 56 : 68,
                      ),

                      // Right Side: Notification Icon + Profile Avatar
                      Row(
                        children: [
                          ValueListenableBuilder<int>(
                            valueListenable: PendingApprovalSyncService.instance.unreadNotificationsCount,
                            builder: (context, unreadCount, _) {
                              return _iconButton(
                                icon: Icons.notifications_outlined,
                                badgeCount: unreadCount,
                                onTap: () => Navigator.pushNamed(context, '/notifications'),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          _profileAvatar(widget.onProfileTap, context),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text.rich(
                    TextSpan(
                      text: 'Welcome back, ',
                      style: AppColors.soraMedium(isSmallScreen ? 22 : 24).copyWith(color: AppColors.textSecondary),
                      children: [
                        TextSpan(
                          text: '${_user?.displayName ?? 'there'}.',
                          style: AppColors.soraBold(isSmallScreen ? 22 : 24).copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // Quick Actions (For All-Access VIP Members who purchased both Community and Journal)
              if (hasBothAccess)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'QUICK ACTIONS',
                          style: AppColors.geistBold(10).copyWith(color: AppColors.textMuted, letterSpacing: 2),
                        ),
                        const SizedBox(height: 12),
                        IntrinsicHeight(
                          child: Row(
                            children: [
                              Expanded(
                                child: _vipQuickTile(
                                  title: 'Journal',
                                  subtitle: 'Write & Reflect',
                                  icon: Icons.menu_book_rounded,
                                  accentColor: AppColors.cyan,
                                  onTap: () => widget.onNavigate?.call(2),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _vipQuickTile(
                                  title: 'Book Club',
                                  subtitle: 'D.R.E.A.M. Library',
                                  icon: Icons.auto_stories_rounded,
                                  accentColor: const Color(0xFF69F0AE),
                                  onTap: () => widget.onNavigate?.call(3),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        IntrinsicHeight(
                          child: Row(
                            children: [
                              Expanded(
                                child: _vipQuickTile(
                                  title: 'Book Club Chat',
                                  subtitle: 'Live Discussions',
                                  icon: Icons.forum_rounded,
                                  accentColor: AppColors.pink,
                                  onTap: () => Navigator.pushNamed(context, '/chat'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _vipQuickTile(
                                  title: 'Media Hub',
                                  subtitle: 'Watch Episodes',
                                  icon: Icons.play_circle_fill_rounded,
                                  accentColor: const Color(0xFFFFB74D),
                                  onTap: () => widget.onNavigateMedia?.call(0),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              // Memberships & Passes Section (Only visible for Single Paid Tier members)
              else if (!isFreeTier)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MY ACTIVE MEMBERSHIPS & PASSES',
                            style: AppColors.geistBold(10).copyWith(color: AppColors.textMuted, letterSpacing: 2)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _passCard(
                                title: _journalName,
                                subtitle: hasJournalAccess
                                    ? 'Lifetime Access Active'
                                    : '\$${_journalPrice?.toStringAsFixed(2) ?? "40.00"} Lifetime Pass',
                                isUnlocked: hasJournalAccess,
                                icon: Icons.menu_book_rounded,
                                onTap: () {
                                  if (!hasJournalAccess) {
                                    JournalPaywallModal.show(context, onUnlocked: () => setState(() {}));
                                  } else {
                                    widget.onNavigate?.call(2); // Jump to Journal tab
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _passCard(
                                title: 'Community Tier',
                                subtitle: hasCommunityAccess ? 'VIP Member Active' : 'Chat & Full Media',
                                isUnlocked: hasCommunityAccess,
                                icon: Icons.group_rounded,
                                onTap: () {
                                  if (!hasCommunityAccess) {
                                    Navigator.pushNamed(context, '/community-tier/pricing');
                                  } else {
                                    widget.onNavigate?.call(3); // Jump to Chat tab
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),


              // Featured Media (Free podcasts for non-community, all media for paid community VIP members)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: _featuredVideosSection(
                    (mediaTab) {
                      if (mediaTab == 0) {
                        widget.onNavigateMedia?.call(0); // Podcast is 100% Free
                      } else if (!hasCommunityAccess) {
                        TierLockModal.show(
                          context,
                          featureName: mediaTab == 1 ? 'D.R.E.A.M Journal Episodes' : 'D.R.E.A.M Activities Videos',
                        );
                      } else {
                        widget.onNavigateMedia?.call(mediaTab);
                      }
                    },
                    _podcasts,
                    _podcastLoading,
                    _journals,
                    _journalLoading,
                    _activities,
                    _activityLoading,
                    hasCommunityAccess: hasCommunityAccess,
                  ),
                ),
              ),

              // Dedicated D.R.E.A.M. Book Club Spotlight Card (Only visible for VIP Community members)
              if (hasCommunityAccess || _user?.hasBookClubAccess == true)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/book-club'),
                      child: _dreamBookClubSpotlightCard(context, hasAccess: true),
                    ),
                  ),
                ),

              // Community Chat Section (Only for Single Community Pass Holders — omitted for Dual VIP who already have it in Quick Actions)
              if (hasCommunityAccess && !hasBothAccess)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: _eventLoading
                        ? const SkeletonHomeChatCard()
                        : GestureDetector(
                            onTap: () => widget.onNavigate?.call(3),
                            child: _communityChatCard(),
                          ),
                  ),
                ),

              // Upcoming Event
              if (_eventLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: SkeletonHomeEventCard(),
                  ),
                )
              else if (_nextEvent != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/events'),
                      child: _upcomingEventCard(_nextEvent!),
                    ),
                  ),
                ),

              // Dream Closet
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text('D.R.E.A.M. CLOSET', style: AppColors.geistBold(12).copyWith(color: AppColors.textPrimary, letterSpacing: 1.5)),
                              if (hasBothAccess || hasCommunityAccess) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '•  10% VIP OFF',
                                  style: AppColors.geistBold(10).copyWith(
                                    color: AppColors.cyan,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(context, '/merch'),
                            child: Row(
                              children: [
                                Text('See All', style: AppColors.geistBold(11).copyWith(color: AppColors.cyan)),
                                const SizedBox(width: 4),
                                Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.cyan),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 240,
                        child: _merchLoading
                            ? ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: 4,
                                itemBuilder: (context, index) => const Padding(
                                  padding: EdgeInsets.only(right: 12),
                                  child: SizedBox(
                                    width: 170,
                                    child: SkeletonProductCard(),
                                  ),
                                ),
                              )
                            : _hotPicks.isEmpty
                                ? Center(child: Text('No products yet', style: AppColors.geistMedium(13).copyWith(color: AppColors.textMuted)))
                                : ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _hotPicks.length,
                                    itemBuilder: (context, index) {
                                      final p = _hotPicks[index];
                                      return _productCard(
                                        p.name,
                                        '\$${p.price.toStringAsFixed(2)}',
                                        imageUrl: p.imageUrl,
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ProductDetailScreen(product: p.toDetailMap()),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      );
    }

  static Widget _iconButton({
    required IconData icon,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Icon(icon, color: AppColors.textSecondary, size: 19),
          ),
          if (badgeCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.cyan, Color(0xFF00A3AF)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cyan.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                alignment: Alignment.center,
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  style: AppColors.geistBold(9).copyWith(color: const Color(0xFF051424)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _profileAvatar(VoidCallback? onProfileTap, BuildContext context) {
    final initials = _user?.initials ?? '?';
    final hasAvatar = _user?.resolvedAvatarUrl != null && _user!.resolvedAvatarUrl!.isNotEmpty;
    final hasCommunity = _user?.hasCommunityAccess ?? false;
    final hasJournal = _user?.hasJournalAccess ?? false;

    final bool hasPaidAccess = hasCommunity || hasJournal;
    final Color borderColor = hasPaidAccess ? AppColors.cyan : AppColors.surfaceBorder;
    final double borderWidth = hasPaidAccess ? 1.8 : 1.0;

    // Badge icon on right bottom corner
    IconData? badgeIcon;
    if (hasCommunity) {
      badgeIcon = Icons.check_circle_rounded;
    } else if (hasJournal) {
      badgeIcon = Icons.menu_book_rounded;
    }

    return GestureDetector(
      onTap: onProfileTap ?? () => Navigator.pushNamed(context, '/profile'),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: hasAvatar ? null : const LinearGradient(colors: [Color(0x2600DBE9), Color(0x1AFFABF0)]),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: borderWidth),
              boxShadow: hasPaidAccess
                  ? [
                      BoxShadow(
                        color: borderColor.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 0.5,
                      ),
                    ]
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: hasAvatar
                ? Image.network(
                    _user!.resolvedAvatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(child: Text(initials, style: AppColors.soraBold(14))),
                  )
                : Center(child: Text(initials, style: AppColors.soraBold(14))),
          ),
          if (badgeIcon != null)
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  color: const Color(0xFF051424),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF051424), width: 1),
                ),
                child: Center(
                  child: Icon(
                    badgeIcon,
                    color: AppColors.cyan,
                    size: badgeIcon == Icons.menu_book_rounded ? 10 : 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Widget _quickChip(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.4),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.cyan, size: 16),
            const SizedBox(width: 8),
            Text(label, style: AppColors.geistMedium(12).copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  static Widget _featuredVideosSection(
    void Function(int mediaTab)? onNavigateMedia,
    List<PodcastModel> podcasts,
    bool podcastLoading,
    List<JournalModel> journals,
    bool journalLoading,
    List<ActivityModel> activities,
    bool activityLoading, {
    required bool hasCommunityAccess,
  }) {
    // Build list of featured items
    final List<Map<String, dynamic>> items = [];

    if (!podcastLoading && podcasts.isNotEmpty) {
      final takeCount = hasCommunityAccess ? 2 : 4;
      for (final podcast in podcasts.take(takeCount)) {
        items.add({
          'type': 'podcast',
          'title': podcast.title,
          'subtitle': podcast.guestName != null && podcast.guestName!.isNotEmpty
              ? 'with ${podcast.guestName}'
              : 'Ep ${podcast.episodeNumber ?? "?"}',
          'tag': 'D.R.E.A.M. PODCAST',
          'tagColor': AppColors.cyan,
          'thumbnail': podcast.thumbnailUrl,
          'playColor': AppColors.cyan,
          'onTap': () => onNavigateMedia?.call(0),
        });
      }
    }

    // ONLY Community Tier members have access to Journal Videos and Activities!
    if (hasCommunityAccess) {
      if (!journalLoading) {
        for (final j in journals.take(1)) {
          items.add({
            'type': 'journal',
            'title': j.title,
            'subtitle': j.description ?? '',
            'tag': 'JOURNAL EPISODES',
            'tagColor': AppColors.pink,
            'thumbnail': j.thumbnail,
            'playColor': AppColors.pink,
            'onTap': () => onNavigateMedia?.call(1),
          });
        }
      }

      if (!activityLoading) {
        for (final a in activities.take(1)) {
          items.add({
            'type': 'activity',
            'title': a.title,
            'subtitle': a.description ?? '',
            'tag': 'ACTIVITIES VIDEO',
            'tagColor': AppColors.cyan,
            'thumbnail': a.thumbnail,
            'playColor': AppColors.cyan,
            'onTap': () => onNavigateMedia?.call(2),
          });
        }
      }
    }

    if (items.isEmpty && (podcastLoading || (hasCommunityAccess && (journalLoading || activityLoading)))) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(hasCommunityAccess ? 'FEATURED VIDEOS' : 'FREE EPISODES & PODCASTS',
              style: AppColors.geistBold(10).copyWith(color: AppColors.textMuted, letterSpacing: 2)),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              itemBuilder: (context, index) => const SkeletonFeaturedVideoCard(),
            ),
          ),
        ],
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              hasCommunityAccess ? 'FEATURED EPISODES' : 'FREE EPISODES & PODCASTS',
              style: AppColors.geistBold(10).copyWith(color: AppColors.textMuted, letterSpacing: 2),
            ),
            GestureDetector(
              onTap: () => onNavigateMedia?.call(0),
              child: Row(
                children: [
                  Text('See All', style: AppColors.geistBold(11).copyWith(color: AppColors.cyan)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.cyan),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _featuredCard(
                title: item['title'],
                subtitle: item['subtitle'],
                tag: item['tag'],
                tagColor: item['tagColor'],
                thumbnail: item['thumbnail'],
                playColor: item['playColor'],
                onTap: item['onTap'],
              );
            },
          ),
        ),
      ],
    );
  }

  static Widget _featuredCard({
    required String title,
    required String subtitle,
    required String tag,
    required Color tagColor,
    String? thumbnail,
    required Color playColor,
    VoidCallback? onTap,
  }) {
    final resolvedThumb = ApiConfig.resolveUrl(thumbnail);
    final hasThumb = resolvedThumb != null && resolvedThumb.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: AppColors.surface.withOpacity(0.3),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: SizedBox(
                width: double.infinity,
                child: hasThumb
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          DreamNetworkImage(
                            imageUrl: resolvedThumb,
                            fit: BoxFit.cover,
                            cacheWidth: 600,
                            placeholder: (_) => _defaultFeaturedPlaceholder(playColor),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0.0, 0.45, 1.0],
                                colors: [
                                  Colors.black.withOpacity(0.15),
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.85),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 10,
                            left: 12,
                            right: 12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: tagColor,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: tagColor.withOpacity(0.8),
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      tag,
                                      style: AppColors.geistBold(10).copyWith(
                                        color: Colors.white,
                                        letterSpacing: 1.2,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black.withOpacity(0.9),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(title, style: AppColors.soraBold(14).copyWith(color: Colors.white, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          Center(
                            child: Container(
                              width: 46, height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withOpacity(0.45),
                                border: Border.all(color: playColor.withOpacity(0.85), width: 1.5),
                                boxShadow: [BoxShadow(color: playColor.withOpacity(0.35), blurRadius: 14, spreadRadius: 1)],
                              ),
                              child: Icon(Icons.play_arrow_rounded, color: playColor, size: 26),
                            ),
                          ),
                        ],
                      )
                    : _defaultFeaturedPlaceholder(playColor),
              ),
            ),
            if (!hasThumb) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: tagColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tag,
                          style: AppColors.geistBold(9.5).copyWith(
                            color: tagColor,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(title, style: AppColors.soraBold(13).copyWith(color: AppColors.textPrimary, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(subtitle, style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _defaultFeaturedPlaceholder(Color color) {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withOpacity(0.1), AppColors.pink.withOpacity(0.05)]),
      ),
      child: Center(
        child: Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.12),
            border: Border.all(color: color.withOpacity(0.25), width: 1.5),
          ),
          child: Icon(Icons.play_arrow_rounded, color: color, size: 26),
        ),
      ),
    );
  }

  static Widget _productCard(String name, String price, {String? imageUrl, VoidCallback? onTap}) {
    final resolvedImg = ApiConfig.resolveUrl(imageUrl);
    final hasImage = resolvedImg != null && resolvedImg.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 170,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 150,
              width: double.infinity,
              decoration: hasImage ? null : BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.surface.withOpacity(0.6), AppColors.background.withOpacity(0.8)]),
              ),
              child: DreamNetworkImage(
                imageUrl: resolvedImg,
                fit: BoxFit.cover,
                cacheWidth: 350,
                placeholder: (_) => Center(
                  child: Icon(Icons.shopping_bag_outlined, color: AppColors.textMuted.withOpacity(0.3), size: 32),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name, style: AppColors.geistBold(12).copyWith(color: AppColors.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
                    Row(
                      children: [
                        Text(price, style: AppColors.geistBold(13).copyWith(color: AppColors.cyan)),
                        const Spacer(),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.cyan.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.cyan.withOpacity(0.2)),
                          ),
                          child: Icon(Icons.visibility_outlined, color: AppColors.cyan, size: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passCard({
    required String title,
    required String subtitle,
    required bool isUnlocked,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0C1524),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnlocked ? AppColors.cyan.withOpacity(0.5) : Colors.white.withOpacity(0.12),
            width: 1.2,
          ),
          boxShadow: [
            if (isUnlocked)
              BoxShadow(
                color: AppColors.cyan.withOpacity(0.12),
                blurRadius: 12,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: isUnlocked ? AppColors.cyan : AppColors.pink, size: 20),
                Text(
                  isUnlocked ? 'ACTIVE' : 'UNLOCK',
                  style: AppColors.geistBold(9.5).copyWith(
                    color: isUnlocked ? AppColors.cyan : AppColors.pink,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(title, style: AppColors.soraBold(13).copyWith(color: Colors.white)),
            const SizedBox(height: 2),
            Text(subtitle, style: AppColors.geistMedium(10).copyWith(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  static Widget _vipQuickTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1828),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accentColor.withOpacity(0.25)),
              ),
              child: Icon(icon, color: accentColor, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: AppColors.soraBold(12.5).copyWith(color: Colors.white),
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppColors.geistMedium(10).copyWith(color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _communityChatCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cyan.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.cyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.forum_outlined, color: AppColors.cyan.withOpacity(0.7), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Group Chat', style: AppColors.geistBold(13).copyWith(color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('Join the conversation', style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.textMuted.withOpacity(0.4), size: 18),
        ],
      ),
    );
  }

  static Widget _upcomingEventCard(EventModel event) {
    final isOngoing = event.status == 'ongoing';
    final labelColor = isOngoing ? const Color(0xFF69F0AE) : AppColors.cyan;
    final labelText = isOngoing ? 'ONGOING EVENT' : 'UPCOMING EVENT';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [labelColor.withOpacity(0.08), Colors.transparent]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: labelColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: labelColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.event_outlined, color: labelColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(labelText, style: AppColors.geistBold(8).copyWith(color: labelColor, letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text(event.title, style: AppColors.soraBold(13).copyWith(color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                if (event.dateFormatted.isNotEmpty)
                  Text('${event.dateFormatted}${event.timeFormatted.isNotEmpty ? ' · ${event.timeFormatted}' : ''}',
                    style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.2), size: 18),
        ],
      ),
    );
  }

  static Widget _dreamBookClubSpotlightCard(BuildContext context, {required bool hasAccess}) {
    return GestureDetector(
      onTap: () {
        if (hasAccess) {
          Navigator.pushNamed(context, '/book-club');
        } else {
          TierLockModal.show(context, featureName: 'D.R.E.A.M. Book Club');
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1828),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasAccess ? AppColors.cyan.withOpacity(0.28) : AppColors.pink.withOpacity(0.25),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: (hasAccess ? AppColors.cyan : AppColors.pink).withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 3D Book Cover Artwork
            Container(
              width: 58,
              height: 84,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.55),
                    blurRadius: 8,
                    offset: const Offset(2, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/images/books/compound_effect.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFF0E2238),
                  child: const Center(
                    child: Icon(Icons.auto_stories_rounded, color: AppColors.cyan, size: 26),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Book Details & CTA
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Text(
                          'D.R.E.A.M. BOOK CLUB',
                          style: AppColors.geistBold(10).copyWith(
                            color: AppColors.cyan,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '•  Destination',
                          style: AppColors.geistMedium(10.5).copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'The Compound Effect',
                    style: AppColors.soraBold(14).copyWith(color: Colors.white, height: 1.25),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'By Darren Hardy · Jump in to read & discuss',
                    style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        hasAccess ? 'Open Book Club' : 'Unlock with Community Pass',
                        style: AppColors.soraBold(11.5).copyWith(color: AppColors.cyan),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        hasAccess ? Icons.arrow_forward_rounded : Icons.lock_outline_rounded,
                        color: AppColors.cyan,
                        size: 13,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
