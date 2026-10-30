import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';

class DreamJournalCoverWidget extends StatefulWidget {
  final int totalEntries;
  final VoidCallback? onNewEntryTap;

  const DreamJournalCoverWidget({
    super.key,
    required this.totalEntries,
    this.onNewEntryTap,
  });

  @override
  State<DreamJournalCoverWidget> createState() => _DreamJournalCoverWidgetState();
}

class _DreamJournalCoverWidgetState extends State<DreamJournalCoverWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleCover() {
    if (_controller.isAnimating) return;
    if (_isOpen) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
    setState(() => _isOpen = !_isOpen);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleCover,
      child: Container(
        height: 175,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final progress = _animation.value;
            final angle = progress * math.pi; // 0 to 180 degrees
            final isFlipped = angle >= math.pi / 2;

            return Stack(
              children: [
                // Base Inside Page (Right Page / Underneath)
                Positioned.fill(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1A2E),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.cyan.withOpacity(0.3), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Left binder spine shadow
                        Container(
                          width: 8,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withOpacity(0.6),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Inside Content: Lined paper style
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.cyan.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      'JOURNAL OPEN',
                                      style: AppColors.geistBold(9)
                                          .copyWith(color: AppColors.cyan, letterSpacing: 1.5),
                                    ),
                                  ),
                                  Text(
                                    'Tap to close 📖',
                                    style: AppColors.geistMedium(10)
                                        .copyWith(color: Colors.white.withOpacity(0.3)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'D.R.E.A.M. Framework',
                                style: AppColors.soraBold(16).copyWith(color: Colors.white),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Destination • Reason • Energy • Amigos • Mindset',
                                style: AppColors.hankenMedium(11)
                                    .copyWith(color: AppColors.textMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  _letterBadge('D', const Color(0xFFFFCC00)),
                                  _letterBadge('R', const Color(0xFFFFABF0)),
                                  _letterBadge('E', const Color(0xFF38BDF8)),
                                  _letterBadge('A', const Color(0xFFFACC15)),
                                  _letterBadge('M', const Color(0xFF4ADE80)),
                                  const Spacer(),
                                  if (widget.onNewEntryTap != null)
                                    GestureDetector(
                                      onTap: widget.onNewEntryTap,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                              colors: [AppColors.cyan, Color(0xFF00B8C9)]),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '+ Write',
                                          style: AppColors.soraBold(10)
                                              .copyWith(color: AppColors.background),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3D Flipping Book Cover (Front Cover swinging open)
                Positioned.fill(
                  child: Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // 3D Perspective Depth
                      ..rotateY(angle),
                    alignment: Alignment.centerLeft, // Swings open from left spine
                    child: isFlipped
                        ? _buildInsideCoverBack()
                        : _buildFrontCoverFront(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Front Cover Face (Closed State)
  Widget _buildFrontCoverFront() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F1B2E),
            Color(0xFF080D18),
            Color(0xFF14243B),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cyan.withOpacity(0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyan.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(4, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Spine gold accent line on left
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.cyan, Color(0xFFFFABF0), AppColors.cyan],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              children: [
                // Book Icon Emblem
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.cyan.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.cyan.withOpacity(0.3), width: 1.5),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.cyan,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'OFFICIAL JOURNAL',
                          style: AppColors.geistBold(8)
                              .copyWith(color: AppColors.cyan, letterSpacing: 2),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'D.R.E.A.M. Journal',
                        style: AppColors.soraBold(18).copyWith(
                          color: Colors.white,
                          shadows: [
                            Shadow(color: AppColors.cyan.withOpacity(0.5), blurRadius: 10),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap cover to flip open 📖',
                        style: AppColors.hankenMedium(11)
                            .copyWith(color: Colors.white.withOpacity(0.5)),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.auto_stories_rounded,
                  color: AppColors.cyan,
                  size: 24,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Back of Cover Face (Inside flipped page view)
  Widget _buildInsideCoverBack() {
    return Transform(
      transform: Matrix4.identity()..rotateY(math.pi), // Mirror horizontally for back face
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1322),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MEMORIES & VISIONS',
              style: AppColors.geistBold(9)
                  .copyWith(color: AppColors.cyan.withOpacity(0.6), letterSpacing: 1.5),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.totalEntries} Entries Recorded',
              style: AppColors.soraBold(15).copyWith(color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              'Every entry brings you closer to your destination.',
              style: AppColors.hankenMedium(11).copyWith(color: AppColors.textMuted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _letterBadge(String letter, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Center(
        child: Text(
          letter,
          style: AppColors.geistBold(10).copyWith(color: color),
        ),
      ),
    );
  }
}
