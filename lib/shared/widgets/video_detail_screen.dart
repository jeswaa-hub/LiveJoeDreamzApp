import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:dream_community_app/core/config/api_config.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/core/widgets/dream_toast.dart';
import 'package:dream_community_app/shared/services/comment_service.dart';
import 'package:dream_community_app/features/podcast/services/podcast_service.dart';
import 'package:dream_community_app/features/activities/services/activity_service.dart';
import 'package:dream_community_app/features/journal/services/journal_service.dart';
import 'package:dream_community_app/core/route/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VideoDetailScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final String videoUrl;
  final String? thumbnailUrl;
  final List<Map<String, dynamic>>? moreVideos;
  final String videoType;
  final int videoId;

  const VideoDetailScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.videoUrl,
    this.thumbnailUrl,
    this.moreVideos,
    required this.videoType,
    required this.videoId,
  });

  @override
  State<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends State<VideoDetailScreen>
    with SingleTickerProviderStateMixin {
  late final Player _player;
  late final VideoController _controller;
  late final AnimationController _likePulseController;

  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMsg;
  bool _isLiked = false;
  int _likeCount = 0;
  final _scrollController = ScrollController();
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<dynamic>? _errorSub;

  List<Map<String, dynamic>> _comments = [];
  List<Map<String, dynamic>> _moreVideosList = [];
  String? _token;
  final _commentController = TextEditingController();
  bool _isPostingComment = false;

  @override
  void initState() {
    super.initState();
    _likePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      lowerBound: 1.0,
      upperBound: 1.35,
    );

    if (widget.moreVideos != null && widget.moreVideos!.isNotEmpty) {
      _moreVideosList = widget.moreVideos!
          .where((v) => (v['videoType'] ?? '').toString().toLowerCase() == widget.videoType.toLowerCase())
          .toList();
    }

    _player = Player();
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );
    _initVideo();
    _loadToken();
    _loadMoreVideos();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _token = prefs.getString('auth_token') ?? prefs.getString('token');
      });
      _loadComments();
    }
  }

  Future<void> _loadMoreVideos() async {
    try {
      final list = <Map<String, dynamic>>[];
      final currentType = widget.videoType.toLowerCase();
      final currentId = widget.videoId;

      if (currentType == 'podcast') {
        final episodes = await PodcastService().getEpisodes();
        for (final ep in episodes) {
          if (ep.id != currentId) {
            list.add({
              'title': ep.title,
              'subtitle': ep.guestName != null && ep.guestName!.isNotEmpty
                  ? 'with ${ep.guestName}'
                  : 'D.R.E.A.M. Podcast',
              'videoUrl': ep.videoUrl ?? '',
              'thumbnailUrl': ep.thumbnailUrl,
              'videoType': 'podcast',
              'videoId': ep.id,
            });
          }
        }
      } else if (currentType == 'activity' || currentType == 'activities') {
        final activities = await ActivityService().getActivities();
        for (final a in activities) {
          if (a.id != currentId) {
            list.add({
              'title': a.title,
              'subtitle': a.description ?? 'D.R.E.A.M. Activity',
              'videoUrl': a.videoUrl ?? '',
              'thumbnailUrl': a.thumbnail,
              'videoType': 'activity',
              'videoId': a.id,
            });
          }
        }
      } else if (currentType == 'journal') {
        final journals = await JournalService().getJournals();
        for (final j in journals) {
          if (j.id != currentId) {
            list.add({
              'title': j.title,
              'subtitle': 'Journal Episode',
              'videoUrl': j.videoUrl ?? '',
              'thumbnailUrl': j.thumbnail,
              'videoType': 'journal',
              'videoId': j.id,
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _moreVideosList = list;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadComments() async {
    final service = CommentService(token: _token);
    final comments = await service.getComments(
      videoType: widget.videoType,
      videoId: widget.videoId,
    );
    if (mounted) {
      setState(() {
        _comments = comments;
      });
    }
  }

  Future<void> _initVideo() async {
    final rawUrl = widget.videoUrl.trim();
    if (rawUrl.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMsg = 'No video stream available for this item';
      });
      return;
    }

    final resolvedUrl = ApiConfig.resolveUrl(rawUrl);
    if (resolvedUrl == null ||
        resolvedUrl.trim().isEmpty ||
        resolvedUrl.endsWith(':8001/') ||
        resolvedUrl.endsWith(':8000/') ||
        resolvedUrl.endsWith('/')) {
      setState(() {
        _hasError = true;
        _errorMsg = 'No video stream URL found';
      });
      return;
    }
    try {
      _playingSub?.cancel();
      _completedSub?.cancel();
      _errorSub?.cancel();

      _playingSub = _player.stream.playing.listen((playing) {
        if (playing && mounted && !_isInitialized) {
          setState(() => _isInitialized = true);
        }
      });

      _completedSub = _player.stream.completed.listen((completed) {
        if (completed && mounted) {
          _player.play();
        }
      });

      _errorSub = _player.stream.error.listen((error) {
        debugPrint('[DREAM Video Error] $error');
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMsg = error.toString();
          });
        }
      });

      debugPrint('[DREAM Video] Opening URL: $resolvedUrl');
      await _player.open(Media(resolvedUrl), play: true);

      Future.delayed(const Duration(seconds: 20), () {
        if (mounted && !_isInitialized && !_hasError) {
          setState(() {
            _hasError = true;
            _errorMsg = 'Video stream took too long to load';
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMsg = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _playingSub?.cancel();
    _completedSub?.cancel();
    _errorSub?.cancel();
    _player.dispose();
    _scrollController.dispose();
    _commentController.dispose();
    _likePulseController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    if (_token == null) {
      DreamToast.error(context, 'Please log in to like this stream');
      return;
    }

    _likePulseController.forward().then((_) => _likePulseController.reverse());

    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    final service = CommentService(token: _token);
    final result = await service.toggleVideoLike(
      videoType: widget.videoType,
      videoId: widget.videoId,
    );

    if (result != null && mounted) {
      setState(() {
        _isLiked = result['liked'] ?? false;
        _likeCount = result['likes_count'] ?? 0;
      });
    }
  }

  Future<void> _submitComment() async {
    if (_isPostingComment) return;
    if (_commentController.text.trim().isEmpty) return;
    if (_token == null) {
      DreamToast.error(context, 'Please log in to join the discussion');
      return;
    }

    setState(() => _isPostingComment = true);

    try {
      final service = CommentService(token: _token);
      final newComment = await service.addComment(
        videoType: widget.videoType,
        videoId: widget.videoId,
        content: _commentController.text.trim(),
      );

      if (newComment != null && mounted) {
        setState(() {
          _comments.insert(0, newComment);
        });
        _commentController.clear();
        FocusScope.of(context).unfocus();
        DreamToast.success(context, 'Comment posted!');
      }
    } finally {
      if (mounted) {
        setState(() => _isPostingComment = false);
      }
    }
  }

  String _getCategoryLabel() {
    switch (widget.videoType.toLowerCase()) {
      case 'podcast':
        return 'D.R.E.A.M. PODCAST';
      case 'journal':
        return 'JOURNAL EPISODES';
      case 'activity':
      case 'activities':
        return 'ACTIVITIES VIDEO';
      default:
        return 'D.R.E.A.M. STREAM';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── 1. FLOATING CINEMATIC NAVIGATION BAR ──
            _buildTopNavBar(),

            // ── 2. SCROLLABLE THEATER CONTENT ──
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 40),
                children: [
                  // 16:9 Video Player Theater
                  _buildVideoPlayer(),

                  // Hero Title & Action Bar Bento
                  _buildHeroDetailsBento(),

                  // Community Discussion Bento
                  _buildDiscussionBento(),

                  // Up Next / More Videos Bento
                  _buildMoreVideosBento(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 1. FLOATING CINEMATIC NAVIGATION BAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildTopNavBar() {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(16, topPadding + 6, 16, 10),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(
            color: AppColors.surfaceBorder,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 16),
            ),
          ),
          const SizedBox(width: 12),

          // Category Badge Chip with Glowing Dot
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.cyan.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.cyan.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.cyan,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cyan.withValues(alpha: 0.8),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _getCategoryLabel(),
                  style: AppColors.geistBold(9).copyWith(
                    color: AppColors.cyan,
                    letterSpacing: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 2. VIDEO PLAYER THEATER
  // ─────────────────────────────────────────────────────────────
  Widget _buildVideoPlayer() {
    final hasThumb = widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty;
    final resolvedThumbUrl = ApiConfig.resolveUrl(widget.thumbnailUrl);

    if (widget.videoUrl.isEmpty || _hasError) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: AppColors.surface,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasThumb && resolvedThumbUrl != null)
                Image.network(
                  resolvedThumbUrl,
                  fit: BoxFit.cover,
                  headers: const {'Accept': 'image/*'},
                  errorBuilder: (context, error, stackTrace) => const SizedBox(),
                ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.4),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.error.withValues(alpha: 0.15),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                      ),
                      child: const Icon(Icons.videocam_off_rounded, color: AppColors.error, size: 26),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Video Stream Unavailable',
                      style: AppColors.soraBold(14).copyWith(color: AppColors.textPrimary),
                    ),
                    if (_errorMsg != null) ...[
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _errorMsg!,
                          style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _hasError = false;
                          _errorMsg = null;
                          _isInitialized = false;
                        });
                        _initVideo();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.cyan,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.cyan.withValues(alpha: 0.3),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.refresh_rounded, color: AppColors.background, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'RETRY STREAM',
                              style: AppColors.geistBold(11).copyWith(
                                color: AppColors.background,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: AppColors.cyan.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background poster fallback
              if (hasThumb && resolvedThumbUrl != null)
                Image.network(
                  resolvedThumbUrl,
                  fit: BoxFit.cover,
                  headers: const {'Accept': 'image/*'},
                  errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF0A101D)),
                ),

              // Native Video Layer (mounted continuously so Flutter texture is bound immediately)
              MaterialVideoControlsTheme(
                normal: MaterialVideoControlsThemeData(
                  seekBarPositionColor: AppColors.cyan,
                  seekBarBufferColor: AppColors.cyan.withValues(alpha: 0.35),
                  seekBarThumbColor: AppColors.cyan,
                  buttonBarButtonColor: Colors.white,
                  topButtonBarMargin: const EdgeInsets.all(8),
                  bottomButtonBarMargin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                fullscreen: MaterialVideoControlsThemeData(
                  seekBarPositionColor: AppColors.cyan,
                  seekBarBufferColor: AppColors.cyan.withValues(alpha: 0.35),
                  seekBarThumbColor: AppColors.cyan,
                  buttonBarButtonColor: Colors.white,
                ),
                child: Video(
                  controller: _controller,
                  controls: MaterialVideoControls,
                ),
              ),

              // Celestial buffering state while loading
              if (!_isInitialized)
                Container(
                  color: const Color(0xFF030712).withValues(alpha: 0.85),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: AppColors.cyan,
                              ),
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.cyan.withValues(alpha: 0.15),
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: AppColors.cyan,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'INITIALIZING STREAM...',
                          style: AppColors.geistBold(10).copyWith(
                            color: AppColors.cyan,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 3. HERO DETAILS & ACTION BAR BENTO
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeroDetailsBento() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.surfaceBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              widget.title,
              style: AppColors.soraBold(20).copyWith(
                color: AppColors.textPrimary,
                height: 1.3,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle with Star Badge
            Row(
              children: [
                Icon(
                  Icons.verified_rounded,
                  color: AppColors.cyan.withValues(alpha: 0.8),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.subtitle,
                    style: AppColors.geistMedium(13).copyWith(
                      color: AppColors.cyan,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            Container(height: 1, color: AppColors.surfaceBorder),
            const SizedBox(height: 14),

            // ── Interactive Action Bar ──
            Row(
              children: [
                // Animated Like Button
                GestureDetector(
                  onTap: _toggleLike,
                  child: ScaleTransition(
                    scale: _likePulseController,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isLiked
                            ? AppColors.pink.withValues(alpha: 0.15)
                            : AppColors.surfaceBorder,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isLiked
                              ? AppColors.pink.withValues(alpha: 0.45)
                              : AppColors.surfaceBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border_rounded,
                            color: _isLiked ? AppColors.pink : AppColors.textMuted,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$_likeCount',
                            style: AppColors.geistBold(13).copyWith(
                              color: _isLiked ? AppColors.pink : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 4. COMMUNITY DISCUSSION BENTO
  // ─────────────────────────────────────────────────────────────
  Widget _buildDiscussionBento() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.forum_outlined, color: AppColors.cyan, size: 16),
                const SizedBox(width: 8),
                Text(
                  'COMMUNITY DISCUSSION',
                  style: AppColors.geistBold(11).copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBorder,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_comments.length}',
                    style: AppColors.geistBold(11).copyWith(color: AppColors.cyan),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Comment Input Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      enabled: !_isPostingComment,
                      style: AppColors.geistMedium(13).copyWith(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Share your thoughts with the community...',
                        hintStyle: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      maxLines: null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isPostingComment ? null : _submitComment,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isPostingComment ? AppColors.cyan.withValues(alpha: 0.5) : AppColors.cyan,
                      ),
                      child: _isPostingComment
                          ? const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: AppColors.background,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : const Icon(Icons.arrow_upward_rounded, color: AppColors.background, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            // Comments Feed Preview
            if (_comments.isNotEmpty) ...[
              const SizedBox(height: 18),
              Column(
                children: [
                  for (int i = 0; i < _comments.length && i < 3; i++)
                    _commentTile(_comments[i]),
                  if (_comments.length > 3)
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _CommentsScreen(
                              videoType: widget.videoType,
                              videoId: widget.videoId,
                              token: _token,
                              onCommentAdded: _loadComments,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'View all ${_comments.length} comments',
                              style: AppColors.geistBold(12).copyWith(color: AppColors.cyan),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right_rounded, color: AppColors.cyan, size: 16),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _commentTile(Map<String, dynamic> c) {
    final userName = c['user_name'] ?? 'User';
    final content = c['content'] ?? '';
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cyan.withValues(alpha: 0.15),
              border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                initial,
                style: AppColors.geistBold(12).copyWith(color: AppColors.cyan),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: AppColors.soraBold(12).copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  content,
                  style: AppColors.geistMedium(12).copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 5. UP NEXT / MORE VIDEOS BENTO
  // ─────────────────────────────────────────────────────────────
  Widget _buildMoreVideosBento() {
    final list = _moreVideosList.isNotEmpty ? _moreVideosList : (widget.moreVideos ?? []);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.playlist_play_rounded, color: AppColors.cyan, size: 20),
              const SizedBox(width: 8),
              Text(
                'NEXT VIDEO',
                style: AppColors.geistBold(11).copyWith(
                  color: AppColors.textMuted,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 8),
              if (list.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${list.length}',
                    style: AppColors.geistBold(10).copyWith(color: AppColors.cyan),
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 1,
                  color: AppColors.surfaceBorder,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (list.isNotEmpty)
            Column(
              children: list.map((v) => _moreVideoBentoCard(v, list)).toList(),
            )
          else
            _buildEmptyMoreVideosCard(),
        ],
      ),
    );
  }

  Widget _buildEmptyMoreVideosCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cyan.withValues(alpha: 0.1),
              border: Border.all(color: AppColors.cyan.withValues(alpha: 0.25)),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: AppColors.cyan, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            'MORE EPISODES IN PRODUCTION',
            style: AppColors.geistBold(11).copyWith(
              color: AppColors.textPrimary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'New podcast episodes, activities, and journal videos are coming soon.',
            style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _moreVideoBentoCard(Map<String, dynamic> video, List<Map<String, dynamic>> currentQueue) {
    final thumbUrl = video['thumbnailUrl'] as String?;
    final hasThumb = thumbUrl != null && thumbUrl.isNotEmpty;
    final resolvedThumb = ApiConfig.resolveUrl(thumbUrl);

    final vType = (video['videoType'] ?? 'podcast').toString().toLowerCase();
    const badgeColor = AppColors.cyan;
    String badgeText;

    if (vType == 'podcast') {
      badgeText = 'PODCAST';
    } else if (vType == 'journal') {
      badgeText = 'JOURNAL';
    } else {
      badgeText = 'ACTIVITY';
    }

    return GestureDetector(
      onTap: () {
        final nextQueue = currentQueue.where((m) {
          final mKey = '${m['videoType']}_${m['videoId']}';
          final currentKey = '${video['videoType']}_${video['videoId']}';
          return mKey != currentKey;
        }).toList();

        Navigator.pushReplacement(
          context,
          AppRoutes.minimalistTransition(
            VideoDetailScreen(
              title: video['title'] ?? '',
              subtitle: video['subtitle'] ?? '',
              videoUrl: video['videoUrl'] ?? '',
              thumbnailUrl: video['thumbnailUrl'],
              moreVideos: nextQueue,
              videoType: video['videoType'] ?? widget.videoType,
              videoId: video['videoId'] ?? widget.videoId,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          children: [
            // Thumbnail with play button overlay
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 120,
                height: 74,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasThumb && resolvedThumb != null)
                      Image.network(
                        resolvedThumb,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(color: AppColors.background),
                      )
                    else
                      Container(color: AppColors.background),

                    // Dark overlay with play badge
                    Container(
                      color: Colors.black.withValues(alpha: 0.35),
                      child: Center(
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.65),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Video Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category pill chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: badgeColor.withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      badgeText,
                      style: AppColors.geistBold(9).copyWith(
                        color: badgeColor,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),

                  // Title
                  Text(
                    video['title'] ?? '',
                    style: AppColors.soraBold(13).copyWith(
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),

                  // Subtitle
                  if (video['subtitle'] != null)
                    Text(
                      video['subtitle']!,
                      style: AppColors.geistMedium(11).copyWith(
                        color: AppColors.textMuted,
                      ),
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

// ─────────────────────────────────────────────────────────────
// FULL COMMENTS DISCUSSION MODAL / SCREEN
// ─────────────────────────────────────────────────────────────
class _CommentsScreen extends StatefulWidget {
  final String videoType;
  final int videoId;
  final String? token;
  final VoidCallback onCommentAdded;

  const _CommentsScreen({
    required this.videoType,
    required this.videoId,
    this.token,
    required this.onCommentAdded,
  });

  @override
  State<_CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<_CommentsScreen> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    final service = CommentService(token: widget.token);
    final comments = await service.getComments(
      videoType: widget.videoType,
      videoId: widget.videoId,
    );
    if (mounted) {
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    }
  }

  bool _isPosting = false;

  Future<void> _addComment() async {
    if (_controller.text.trim().isEmpty || _isPosting) return;
    setState(() => _isPosting = true);
    final service = CommentService(token: widget.token);
    try {
      final newComment = await service.addComment(
        videoType: widget.videoType,
        videoId: widget.videoId,
        content: _controller.text.trim(),
      );
      if (newComment != null && mounted) {
        setState(() {
          _comments.insert(0, newComment);
        });
        _controller.clear();
        FocusScope.of(context).unfocus();
        widget.onCommentAdded();
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Community Discussion (${_comments.length})',
          style: AppColors.soraBold(16).copyWith(color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Comment input
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                bottom: BorderSide(color: AppColors.surfaceBorder),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: TextField(
                      controller: _controller,
                      enabled: !_isPosting,
                      style: AppColors.geistMedium(13).copyWith(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: _isPosting ? 'Posting comment...' : 'Join the conversation...',
                        hintStyle: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      maxLines: null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _isPosting ? null : _addComment,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isPosting ? AppColors.cyan.withValues(alpha: 0.5) : AppColors.cyan,
                    ),
                    child: _isPosting
                        ? const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.background,
                              ),
                            ),
                          )
                        : const Icon(Icons.send_rounded, color: AppColors.background, size: 18),
                  ),
                ),
              ],
            ),
          ),

          // Comments List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.cyan, strokeWidth: 2))
                : _comments.isEmpty
                    ? Center(
                        child: Text(
                          'Be the first to leave a comment!',
                          style: AppColors.geistMedium(13).copyWith(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final c = _comments[index];
                          final userName = c['user_name'] ?? 'User';
                          final content = c['content'] ?? '';
                          final createdAt = c['created_at'] ?? '';
                          final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.cyan.withValues(alpha: 0.15),
                                    border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
                                  ),
                                  child: Center(
                                    child: Text(
                                      initial,
                                      style: AppColors.geistBold(12).copyWith(color: AppColors.cyan),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            userName,
                                            style: AppColors.soraBold(13).copyWith(color: Colors.white),
                                          ),
                                          if (createdAt.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              createdAt,
                                              style: AppColors.geistMedium(10).copyWith(
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        content,
                                        style: AppColors.geistMedium(13).copyWith(
                                          color: AppColors.textSecondary,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
