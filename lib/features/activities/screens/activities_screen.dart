import 'package:flutter/material.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/core/models/activity_model.dart';
import 'package:dream_community_app/core/models/user_model.dart';
import 'package:dream_community_app/features/activities/services/activity_service.dart';
import 'package:dream_community_app/features/activities/screens/activity_detail_screen.dart';
import 'package:dream_community_app/features/auth/services/auth_service.dart';
import 'package:dream_community_app/core/widgets/dream_toast.dart';
import 'package:dream_community_app/shared/widgets/tier_lock_modal.dart';
import 'package:dream_community_app/shared/widgets/skeleton.dart';
import 'package:dream_community_app/shared/widgets/dream_network_image.dart';
import 'package:dream_community_app/core/route/app_routes.dart';

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  State<ActivitiesScreen> createState() => ActivitiesScreenState();
}

class ActivitiesScreenState extends State<ActivitiesScreen> {
  bool _isLoading = true;
  List<ActivityModel> _activities = [];
  String _searchQuery = '';
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> refresh() async {
    await _loadData();
  }

  void setSearchQuery(String query) {
    if (mounted) setState(() => _searchQuery = query.toLowerCase());
  }

  Future<void> _loadData() async {
    final data = await ActivityService().getActivities();
    final user = await AuthService().getCurrentUser();
    if (mounted) setState(() { _activities = data; _user = user; _isLoading = false; });
  }

  bool get _hasAccess =>
      _user?.hasActivitiesAccess == true ||
      _user?.hasCommunityAccess == true ||
      _user?.hasAdminAccess == true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async => await _loadData(),
        color: AppColors.cyan,
        backgroundColor: AppColors.surface,
        child: _isLoading ? _buildSkeleton() : _buildContent(),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      children: const [
        SkeletonFeaturedCard(),
        SizedBox(height: 20),
        SkeletonVideoRow(),
        SkeletonVideoRow(),
        SkeletonVideoRow(),
      ],
    );
  }

  Widget _buildContent() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 380;
    final horizontalPadding = isSmallScreen ? 14.0 : 18.0;

    final filtered = _searchQuery.isEmpty
        ? _activities
        : _activities.where((a) =>
            a.title.toLowerCase().contains(_searchQuery) ||
            (a.description?.toLowerCase().contains(_searchQuery) ?? false)
          ).toList();

    final featured = filtered.isNotEmpty ? filtered.first : null;
    final rest = filtered.length > 1 ? filtered.sublist(1) : <ActivityModel>[];

    return CustomScrollView(
      slivers: [
        if (filtered.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 32, horizontalPadding, 110),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 32 : 40, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.surface, // Solid surface, zero gradient!
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.cyan.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.cyan.withOpacity(0.2)),
                      ),
                      child: const Icon(Icons.play_circle_outline_rounded, size: 24, color: AppColors.cyan),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _searchQuery.isNotEmpty ? 'No Matching Videos Found' : 'No Activities Videos Yet',
                      textAlign: TextAlign.center,
                      style: AppColors.soraBold(15),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _searchQuery.isNotEmpty ? 'Try a different search keyword.' : 'Activity walkthroughs and exercises are added regularly.',
                      textAlign: TextAlign.center,
                      style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          )
        else ...[
          // ── FEATURED HERO CARD ──
          if (featured != null) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 0),
                child: _buildFeaturedCard(featured, rest, isSmallScreen),
              ),
            ),
          ],

          // ── ALL VIDEOS LIST ──
          if (rest.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 0),
                child: Text(
                  'ALL VIDEOS',
                  style: AppColors.geistBold(10).copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 110),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final a = rest[index];
                    final otherVideos = filtered.where((x) => x.id != a.id).map((x) => {
                      'title': x.title,
                      'subtitle': x.description,
                      'videoUrl': x.videoUrl ?? '',
                      'thumbnailUrl': x.thumbnail ?? '',
                      'videoType': 'activity',
                      'videoId': x.id,
                    }).toList();
                    return _videoCard(a, isSmallScreen, moreVideos: otherVideos);
                  },
                  childCount: rest.length,
                ),
              ),
            ),
          ] else ...[
            const SliverPadding(padding: EdgeInsets.only(bottom: 110)),
          ],
        ],
      ],
    );
  }

  Widget _buildFeaturedCard(ActivityModel activity, List<ActivityModel> otherActivities, bool isSmallScreen) {
    return GestureDetector(
      onTap: () => _openActivity(activity, otherActivities),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface, // Solid 30% structural surface, zero gradient!
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 16:9 Thumbnail Header with Play Trigger
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildThumbnail(activity.thumbnail),
                    Center(
                      child: Container(
                        width: isSmallScreen ? 46 : 52,
                        height: isSmallScreen ? 46 : 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.6),
                          border: Border.all(color: Colors.white.withOpacity(0.15)),
                        ),
                        child: Icon(
                          !_hasAccess ? Icons.lock_rounded : Icons.play_arrow_rounded,
                          color: !_hasAccess ? AppColors.pink : AppColors.cyan,
                          size: 26,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Solid Metadata Panel (No Gradient Overlay, No Badge Pill)
            Padding(
              padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '• LATEST VIDEO',
                        style: AppColors.geistBold(10).copyWith(
                          color: AppColors.cyan,
                          letterSpacing: 1.5,
                        ),
                      ),
                      if (!_hasAccess) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.lock_rounded, size: 11, color: AppColors.pink.withOpacity(0.85)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    activity.title,
                    style: AppColors.soraBold(isSmallScreen ? 15 : 17).copyWith(
                      color: Colors.white,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (activity.description != null && activity.description!.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      activity.description!,
                      style: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _videoCard(ActivityModel activity, bool isSmallScreen, {List<Map<String, dynamic>>? moreVideos}) {
    return GestureDetector(
      onTap: () => _openActivity(activity, moreVideos ?? []),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface, // Solid 30% surface, zero gradient!
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: isSmallScreen ? 104 : 116,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildThumbnail(activity.thumbnail),
                        Center(
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withOpacity(0.6),
                              border: Border.all(color: Colors.white.withOpacity(0.15)),
                            ),
                            child: Icon(
                              !_hasAccess ? Icons.lock_rounded : Icons.play_arrow_rounded,
                              color: !_hasAccess ? AppColors.pink : AppColors.cyan,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    activity.title,
                    style: AppColors.soraBold(isSmallScreen ? 13 : 14).copyWith(
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Activities Video',
                        style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted),
                      ),
                      if (!_hasAccess) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.lock_rounded, size: 10, color: AppColors.pink.withOpacity(0.85)),
                      ],
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

  void _openActivity(ActivityModel activity, List<dynamic> otherActivities) {
    if (!_hasAccess) {
      DreamToast.warning(context, 'Upgrade your Tier Package to watch Activity videos!');
      TierLockModal.show(context, featureName: 'D.R.E.A.M Activities Videos');
      return;
    }

    final moreVideos = otherActivities.map((x) {
      if (x is ActivityModel) {
        return {
          'title': x.title,
          'subtitle': x.description,
          'videoUrl': x.videoUrl ?? '',
          'thumbnailUrl': x.thumbnail ?? '',
          'videoType': 'activity',
          'videoId': x.id,
        };
      }
      return x as Map<String, dynamic>;
    }).toList();

    Navigator.push(
      context,
      AppRoutes.minimalistTransition(
        ActivityDetailScreen(
          title: activity.title,
          videoUrl: activity.videoUrl ?? '',
          thumbnailUrl: activity.thumbnail,
          moreVideos: moreVideos,
          videoId: activity.id,
        ),
      ),
    );
  }

  Widget _buildThumbnail(String? url) {
    return DreamNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: 600,
      placeholder: (_) => _defaultSolidThumbnail(),
    );
  }

  Widget _defaultSolidThumbnail() {
    return Container(
      color: AppColors.surface, // Solid color, zero gradient!
      child: Center(
        child: Icon(Icons.play_circle_outline_rounded, color: AppColors.cyan.withOpacity(0.25), size: 36),
      ),
    );
  }
}
