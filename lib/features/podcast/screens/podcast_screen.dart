import 'package:flutter/material.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/core/models/podcast_model.dart';
import 'package:dream_community_app/core/models/user_model.dart';
import 'package:dream_community_app/features/podcast/services/podcast_service.dart';
import 'package:dream_community_app/features/podcast/screens/podcast_detail_screen.dart';
import 'package:dream_community_app/features/podcast/screens/podcast_apply_screen.dart';
import 'package:dream_community_app/features/auth/services/auth_service.dart';
import 'package:dream_community_app/core/widgets/dream_toast.dart';
import 'package:dream_community_app/shared/widgets/tier_lock_modal.dart';
import 'package:dream_community_app/shared/widgets/skeleton.dart';
import 'package:dream_community_app/shared/widgets/dream_network_image.dart';
import 'package:dream_community_app/core/route/app_routes.dart';

class PodcastScreen extends StatefulWidget {
  const PodcastScreen({super.key});

  @override
  State<PodcastScreen> createState() => PodcastScreenState();
}

class PodcastScreenState extends State<PodcastScreen> {
  bool _isLoading = true;
  List<PodcastModel> _episodes = [];
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
    final data = await PodcastService().getEpisodes();
    final user = await AuthService().getCurrentUser();
    if (mounted) setState(() { _episodes = data; _user = user; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async => await _loadData(),
        color: AppColors.cyan,
        backgroundColor: AppColors.surface,
        child: _isLoading
            ? ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                children: const [
                  SkeletonFeaturedCard(),
                  SizedBox(height: 20),
                  SkeletonVideoRow(),
                  SkeletonVideoRow(),
                  SkeletonVideoRow(),
                ],
              )
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 380;
    final horizontalPadding = isSmallScreen ? 14.0 : 18.0;

    final hasPodcastAccess = _user?.hasPodcastAccess == true || _user?.hasAdminAccess == true;

    final filtered = _searchQuery.isEmpty
        ? _episodes
        : _episodes.where((e) =>
            e.title.toLowerCase().contains(_searchQuery) ||
            (e.guestName?.toLowerCase().contains(_searchQuery) ?? false) ||
            (e.description?.toLowerCase().contains(_searchQuery) ?? false)
          ).toList();

    final featured = filtered.isNotEmpty ? filtered.first : null;
    final rest = filtered.length > 1 ? filtered.sublist(1) : <PodcastModel>[];

    return CustomScrollView(
      slivers: [
        if (featured != null) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 0),
              child: GestureDetector(
                onTap: () {
                  final moreVideos = rest.map((e) => {
                    'title': e.title,
                    'subtitle': 'with ${e.guestName ?? ''}',
                    'videoUrl': e.videoUrl ?? '',
                    'thumbnailUrl': e.thumbnailUrl ?? '',
                    'videoType': 'podcast',
                    'videoId': e.id,
                  }).toList();
                  Navigator.push(
                    context,
                    AppRoutes.minimalistTransition(
                      PodcastDetailScreen(
                        title: featured.title,
                        guest: featured.guestName ?? '',
                        videoUrl: featured.videoUrl ?? '',
                        thumbnailUrl: featured.thumbnailUrl,
                        moreVideos: moreVideos,
                        videoId: featured.id,
                      ),
                    ),
                  );
                },
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
                      // 16:9 Thumbnail Header with Center Play Trigger
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              _buildThumbnail(featured.thumbnailUrl),
                              Center(
                                child: Container(
                                  width: isSmallScreen ? 46 : 52,
                                  height: isSmallScreen ? 46 : 52,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withOpacity(0.6),
                                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: AppColors.cyan,
                                    size: 28,
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
                                  '• LATEST EPISODE',
                                  style: AppColors.geistBold(10).copyWith(
                                    color: AppColors.cyan,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                if (featured.episodeNumber != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    'EP ${featured.episodeNumber}',
                                    style: AppColors.geistMedium(10).copyWith(
                                      color: AppColors.textMuted.withOpacity(0.7),
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              featured.title,
                              style: AppColors.soraBold(isSmallScreen ? 15 : 17).copyWith(
                                color: Colors.white,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (featured.guestName != null && featured.guestName!.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                'With ${featured.guestName}',
                                style: AppColors.geistMedium(12).copyWith(
                                  color: AppColors.textMuted,
                                ),
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
              ),
            ),
          ),
        ],

        if (filtered.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 32, horizontalPadding, 110),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 32 : 40, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.surface, // Solid 30% structural surface, zero gradient!
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
                      child: const Icon(Icons.podcasts_rounded, color: AppColors.cyan, size: 24),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _searchQuery.isNotEmpty ? 'No Matching Episodes' : 'No Podcast Episodes Yet',
                      textAlign: TextAlign.center,
                      style: AppColors.soraBold(15),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'Try searching with different keywords.'
                          : 'New episodes are currently being scheduled. Stay tuned or apply to be a guest!',
                      textAlign: TextAlign.center,
                      style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted, height: 1.5),
                    ),
                    const SizedBox(height: 18),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PodcastApplyScreen())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.cyan, // Solid 10% accent, zero gradient!
                          borderRadius: BorderRadius.circular(10), // Clean geometric, no pill
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.mic_rounded, color: Color(0xFF051424), size: 15),
                            const SizedBox(width: 6),
                            Text(
                              'Apply to Be a Guest',
                              style: AppColors.geistBold(11).copyWith(color: const Color(0xFF051424)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (rest.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 0),
              child: Text(
                'ALL EPISODES',
                style: AppColors.geistBold(10).copyWith(color: AppColors.textMuted, letterSpacing: 2),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 110),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final episode = rest[index];
                  final otherVideos = filtered.where((e) => e.id != episode.id).map((e) => {
                    'title': e.title,
                    'subtitle': 'with ${e.guestName ?? ''}',
                    'videoUrl': e.videoUrl ?? '',
                    'videoType': 'podcast',
                    'videoId': e.id,
                  }).toList();
                  return _episodeCard(episode, isSmallScreen, moreVideos: otherVideos);
                },
                childCount: rest.length,
              ),
            ),
          ),
        ] else ...[
          const SliverPadding(padding: EdgeInsets.only(bottom: 110)),
        ],
      ],
    );
  }

  Widget _buildThumbnail(String? url) {
    return DreamNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: 600,
      placeholder: (_) => _defaultGradient(),
    );
  }

  Widget _defaultGradient() {
    return Container(
      color: AppColors.surface, // Solid color, zero gradient!
      child: Center(
        child: Icon(Icons.podcasts_rounded, color: AppColors.cyan.withOpacity(0.25), size: 36),
      ),
    );
  }

  Widget _episodeCard(PodcastModel episode, bool isSmallScreen, {List<Map<String, dynamic>>? moreVideos}) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          AppRoutes.minimalistTransition(
            PodcastDetailScreen(
              title: episode.title,
              guest: episode.guestName ?? '',
              videoUrl: episode.videoUrl ?? '',
              thumbnailUrl: episode.thumbnailUrl,
              moreVideos: moreVideos,
              videoId: episode.id,
            ),
          ),
        );
      },
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
                        _buildThumbnail(episode.thumbnailUrl),
                        Center(
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withOpacity(0.6),
                              border: Border.all(color: Colors.white.withOpacity(0.15)),
                            ),
                            child: const Icon(Icons.play_arrow_rounded, color: AppColors.cyan, size: 16),
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
                    episode.title,
                    style: AppColors.soraBold(isSmallScreen ? 13 : 14).copyWith(
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ep ${episode.episodeNumber ?? "?"} • D.R.E.A.M. Podcast',
                    style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted),
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
}
