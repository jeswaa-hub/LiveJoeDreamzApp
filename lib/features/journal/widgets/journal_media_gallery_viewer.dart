import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/core/models/journal_entry_model.dart';

/// Full-screen Interactive Media Gallery Viewer with swipe left/right gesture
class JournalMediaGalleryViewer extends StatefulWidget {
  final List<JournalEntryMediaModel> mediaList;
  final int initialIndex;

  const JournalMediaGalleryViewer({
    super.key,
    required this.mediaList,
    this.initialIndex = 0,
  });

  static void show(
    BuildContext context, {
    required List<JournalEntryMediaModel> mediaList,
    int initialIndex = 0,
  }) {
    if (mediaList.isEmpty) return;
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.94),
      barrierDismissible: true,
      builder: (_) => JournalMediaGalleryViewer(
        mediaList: mediaList,
        initialIndex: initialIndex,
      ),
    );
  }

  @override
  State<JournalMediaGalleryViewer> createState() => _JournalMediaGalleryViewerState();
}

class _JournalMediaGalleryViewerState extends State<JournalMediaGalleryViewer> {
  late final PageController _pageController;
  late final ScrollController _thumbnailScrollController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.mediaList.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _thumbnailScrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollThumbnailIntoView(_currentIndex);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailScrollController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _scrollThumbnailIntoView(index);
  }

  void _scrollThumbnailIntoView(int index) {
    if (!_thumbnailScrollController.hasClients) return;
    final targetOffset = (index * 62.0) - 100.0;
    final clampedOffset = targetOffset.clamp(
      0.0,
      _thumbnailScrollController.position.maxScrollExtent,
    );
    _thumbnailScrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNext() {
    if (_currentIndex < widget.mediaList.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _isVideo(JournalEntryMediaModel media) {
    return media.fileType == 'video' ||
        media.fileUrl.endsWith('.mp4') ||
        media.fileUrl.endsWith('.mov') ||
        media.fileUrl.endsWith('.webm') ||
        media.fileUrl.endsWith('.mkv');
  }

  @override
  Widget build(BuildContext context) {
    final currentMedia = widget.mediaList[_currentIndex];
    final isCurrentVideo = _isVideo(currentMedia);
    final hasMultiple = widget.mediaList.length > 1;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            // Main Swipable Gallery PageView
            Positioned.fill(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.mediaList.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  final media = widget.mediaList[index];
                  final isVideo = _isVideo(media);

                  if (isVideo) {
                    return _GalleryVideoSlide(
                      videoUrl: media.fileUrl,
                      isActive: _currentIndex == index,
                    );
                  } else {
                    return _GalleryImageSlide(
                      imageUrl: media.fileUrl,
                    );
                  }
                },
              ),
            ),

            // Top Header Bar: Counter, Type Badge, and Close Button
            Positioned(
              top: 10,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page Counter & Media Type
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Text(
                          '${_currentIndex + 1} / ${widget.mediaList.length}',
                          style: AppColors.soraBold(12).copyWith(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isCurrentVideo
                              ? const Color(0xFFEC4899).withValues(alpha: 0.25)
                              : AppColors.cyan.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCurrentVideo
                                ? const Color(0xFFEC4899)
                                : AppColors.cyan.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Text(
                          isCurrentVideo ? 'VIDEO' : 'PHOTO',
                          style: AppColors.geistBold(9).copyWith(
                            color: isCurrentVideo ? const Color(0xFFEC4899) : AppColors.cyan,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Close Button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // Left Arrow Indicator
            if (hasMultiple && _currentIndex > 0)
              Positioned(
                left: 12,
                top: 0,
                bottom: 80,
                child: Center(
                  child: GestureDetector(
                    onTap: _goToPrevious,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),

            // Right Arrow Indicator
            if (hasMultiple && _currentIndex < widget.mediaList.length - 1)
              Positioned(
                right: 12,
                top: 0,
                bottom: 80,
                child: Center(
                  child: GestureDetector(
                    onTap: _goToNext,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),

            // Bottom Thumbnail Strip for Fast Navigation
            if (hasMultiple)
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: Container(
                  height: 60,
                  alignment: Alignment.center,
                  child: ListView.builder(
                    controller: _thumbnailScrollController,
                    scrollDirection: Axis.horizontal,
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: widget.mediaList.length,
                    itemBuilder: (context, idx) {
                      final item = widget.mediaList[idx];
                      final isSelected = idx == _currentIndex;
                      final isVid = _isVideo(item);

                      return GestureDetector(
                        onTap: () {
                          _pageController.animateToPage(
                            idx,
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 52,
                          height: 52,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? (isVid ? const Color(0xFFEC4899) : AppColors.cyan)
                                  : Colors.white.withValues(alpha: 0.25),
                              width: isSelected ? 2.5 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: (isVid ? const Color(0xFFEC4899) : AppColors.cyan)
                                          .withValues(alpha: 0.4),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              isVid
                                  ? Container(
                                      color: const Color(0xFF0F172A),
                                      child: const Center(
                                        child: Icon(Icons.play_circle_fill_rounded,
                                            color: AppColors.cyan, size: 22),
                                      ),
                                    )
                                  : Image.network(
                                      item.fileUrl,
                                      fit: BoxFit.cover,
                                      width: 52,
                                      height: 52,
                                      errorBuilder: (context, error, stackTrace) => const Icon(
                                        Icons.broken_image_rounded,
                                        color: Colors.white38,
                                        size: 18,
                                      ),
                                    ),
                              if (isVid)
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEC4899),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: const Text('VID',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 7,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Image Slide with Interactive Pinch-to-Zoom
class _GalleryImageSlide extends StatefulWidget {
  final String imageUrl;

  const _GalleryImageSlide({required this.imageUrl});

  @override
  State<_GalleryImageSlide> createState() => _GalleryImageSlideState();
}

class _GalleryImageSlideState extends State<_GalleryImageSlide> {
  final TransformationController _transformController = TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    if (_transformController.value != Matrix4.identity()) {
      _transformController.value = Matrix4.identity();
    } else {
      _transformController.value = Matrix4.diagonal3Values(2.2, 2.2, 1.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _onDoubleTap,
      child: Center(
        child: InteractiveViewer(
          transformationController: _transformController,
          minScale: 0.8,
          maxScale: 4.5,
          child: Image.network(
            widget.imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    color: AppColors.cyan,
                    strokeWidth: 2.5,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image_rounded, size: 56, color: Colors.white54),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to load image',
                    style: AppColors.geistMedium(12).copyWith(color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Video Slide with In-Gallery Player
class _GalleryVideoSlide extends StatefulWidget {
  final String videoUrl;
  final bool isActive;

  const _GalleryVideoSlide({
    required this.videoUrl,
    required this.isActive,
  });

  @override
  State<_GalleryVideoSlide> createState() => _GalleryVideoSlideState();
}

class _GalleryVideoSlideState extends State<_GalleryVideoSlide> {
  late final Player _player;
  late final VideoController _controller;
  double _aspectRatio = 16 / 9;
  StreamSubscription<int?>? _widthSub;
  StreamSubscription<int?>? _heightSub;
  int _videoW = 0;
  int _videoH = 0;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        enableHardwareAcceleration: true,
      ),
    );

    _widthSub = _player.stream.width.listen((w) {
      if (w != null && w > 0) {
        _videoW = w;
        _updateAspectRatio();
      }
    });

    _heightSub = _player.stream.height.listen((h) {
      if (h != null && h > 0) {
        _videoH = h;
        _updateAspectRatio();
      }
    });

    _player.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });

    _player.open(Media(widget.videoUrl), play: widget.isActive);
  }

  @override
  void didUpdateWidget(covariant _GalleryVideoSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Pause video if user swiped away from this slide
    if (oldWidget.isActive && !widget.isActive) {
      _player.pause();
    }
  }

  void _updateAspectRatio() {
    if (_videoW > 0 && _videoH > 0 && mounted) {
      setState(() => _aspectRatio = _videoW / _videoH);
    }
  }

  @override
  void dispose() {
    _widthSub?.cancel();
    _heightSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 20,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: _aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Video(
                controller: _controller,
                controls: MaterialVideoControls,
              ),
              if (!_isPlaying)
                GestureDetector(
                  onTap: () => _player.play(),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.cyan, width: 2),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: AppColors.cyan, size: 40),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
