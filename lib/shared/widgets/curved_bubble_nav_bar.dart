import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';

class CurvedBubbleNavItem {
  final IconData outlineIcon;
  final IconData filledIcon;
  final String label;
  final bool isLocked;

  const CurvedBubbleNavItem({
    required this.outlineIcon,
    required this.filledIcon,
    required this.label,
    this.isLocked = false,
  });
}

class CurvedBubbleNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<CurvedBubbleNavItem> items;
  final double height;

  const CurvedBubbleNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.height = 78.0,
  });

  @override
  State<CurvedBubbleNavBar> createState() => _CurvedBubbleNavBarState();
}

class _CurvedBubbleNavBarState extends State<CurvedBubbleNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _positionAnimation;
  double _currentPosition = 0.0;

  static const double _edgeInset = 16.0;
  static const double _barTop = 16.0;
  static const double _bubbleSize = 48.0;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.currentIndex.toDouble();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _positionAnimation = Tween<double>(
      begin: _currentPosition,
      end: _currentPosition,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void didUpdateWidget(covariant CurvedBubbleNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      final startPos = _positionAnimation.value;
      final targetPos = widget.currentIndex.toDouble();
      _animationController.reset();
      _positionAnimation = Tween<double>(
        begin: startPos,
        end: targetPos,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ));
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.items.length;
    if (count == 0) return const SizedBox.shrink();

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final totalHeight = widget.height + bottomInset;

    return SizedBox(
      height: totalHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final availableWidth = width - (_edgeInset * 2);
          final slotWidth = availableWidth / count;

          return AnimatedBuilder(
            animation: _positionAnimation,
            builder: (context, child) {
              final animatedIndex = _positionAnimation.value;
              final centerX = _edgeInset + (animatedIndex + 0.5) * slotWidth;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // 1. Frosted Glassmorphism Backdrop
                  Positioned.fill(
                    child: ClipPath(
                      clipper: _CurvedBarClipper(
                        centerX: centerX,
                        barTop: _barTop,
                      ),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(
                          color: const Color(0xFF071220).withValues(alpha: 0.88),
                        ),
                      ),
                    ),
                  ),

                  // 2. Curved Full-Width Outline and Drop Shadow Painter
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CurvedBarPainter(
                        centerX: centerX,
                        barTop: _barTop,
                        height: totalHeight,
                      ),
                    ),
                  ),

                  // 3. Inactive Icons & Text Labels across all slots
                  Positioned(
                    top: _barTop,
                    left: _edgeInset,
                    right: _edgeInset,
                    height: widget.height - _barTop,
                    child: Row(
                      children: List.generate(count, (index) {
                        final item = widget.items[index];
                        final isSelected = widget.currentIndex == index;
                        // Fade out the in-bar icon as the elevated notch arrives
                        final distance = (animatedIndex - index).abs();
                        final iconOpacity = (distance * 1.6).clamp(0.0, 1.0);

                        return Expanded(
                          child: GestureDetector(
                            onTap: () => widget.onTap(index),
                            behavior: HitTestBehavior.opaque,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Inactive Icon slot (fades out under active notch)
                                SizedBox(
                                  height: 22,
                                  child: Opacity(
                                    opacity: iconOpacity,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      alignment: Alignment.center,
                                      children: [
                                        Icon(
                                          item.outlineIcon,
                                          size: 20,
                                          color: Colors.white.withValues(alpha: 0.55),
                                        ),
                                        if (item.isLocked)
                                          Positioned(
                                            top: -3,
                                            right: -6,
                                            child: Container(
                                              padding: const EdgeInsets.all(2.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF16101E),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: AppColors.pink.withValues(alpha: 0.85),
                                                  width: 1,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AppColors.pink.withValues(alpha: 0.35),
                                                    blurRadius: 5,
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.lock_rounded,
                                                size: 8,
                                                color: AppColors.pink,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                // Label (Bold Electric Cyan when active, muted white when inactive)
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 200),
                                  style: GoogleFonts.sora(
                                    fontSize: 10,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected
                                        ? AppColors.cyan
                                        : Colors.white.withValues(alpha: 0.55),
                                    letterSpacing: isSelected ? 0.3 : 0.1,
                                  ),
                                  child: Text(
                                    item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  // 4. Floating Elevated Bubble Button
                  Positioned(
                    left: centerX - (_bubbleSize / 2),
                    top: 0.0,
                    child: GestureDetector(
                      onTap: () => widget.onTap(widget.currentIndex),
                      child: Container(
                        width: _bubbleSize,
                        height: _bubbleSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF081322),
                          border: Border.all(
                            color: AppColors.cyan,
                            width: 2.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.cyan.withValues(alpha: 0.55),
                              blurRadius: 14,
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.75),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, anim) => ScaleTransition(
                              scale: anim,
                              child: child,
                            ),
                            child: Icon(
                              widget.items[widget.currentIndex].filledIcon,
                              key: ValueKey<int>(widget.currentIndex),
                              color: AppColors.cyan,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _CurvedBarPainter extends CustomPainter {
  final double centerX;
  final double barTop;
  final double height;

  const _CurvedBarPainter({
    required this.centerX,
    required this.barTop,
    required this.height,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final barBottom = size.height;
    const r = 20.0; // Outward convex rounded top corner radius
    const halfNotch = 27.0;
    const notchBottomY = 48.0; // Smooth cradle depth hugging the floating circle

    // Symmetrical cradle notch boundaries on top edge
    final notchStart = (centerX - halfNotch).clamp(r, w - r);
    final notchEnd = (centerX + halfNotch).clamp(r, w - r);

    final path = Path();

    // 1. Start at top-left edge below top-left corner
    path.moveTo(0, barTop + r);

    // 2. Top-Left Corner (curving OUTWARD to upper-left)
    path.quadraticBezierTo(0, barTop, r, barTop);

    // 3. Top horizontal edge to cradle start
    path.lineTo(notchStart, barTop);

    // 4. Smooth C1 scooped cradle notch dipping down around the elevated circle
    final dXLeft = centerX - notchStart;
    path.cubicTo(
      notchStart + dXLeft * 0.5, barTop,
      centerX - dXLeft * 0.5, notchBottomY,
      centerX, notchBottomY,
    );

    final dXRight = notchEnd - centerX;
    path.cubicTo(
      centerX + dXRight * 0.5, notchBottomY,
      notchEnd - dXRight * 0.5, barTop,
      notchEnd, barTop,
    );

    // 5. Top horizontal edge from cradle exit to top-right corner
    path.lineTo(w - r, barTop);

    // 6. Top-Right Corner (curving OUTWARD to upper-right)
    path.quadraticBezierTo(w, barTop, w, barTop + r);

    // 7. Right edge straight down to bottom of screen
    path.lineTo(w, barBottom);

    // 8. Bottom edge straight across the bottom of screen
    path.lineTo(0, barBottom);

    // 9. Left edge straight up to top-left corner
    path.lineTo(0, barTop + r);

    path.close();

    // Drop Shadow for floating elevation
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.70), 16.0, true);

    // Deep Obsidian Dark Space Fill
    final fillPaint = Paint()
      ..color = const Color(0xFF081220).withValues(alpha: 0.92)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Top Glowing Hairline Stroke
    final topBorderPath = Path();
    topBorderPath.moveTo(0, barTop + r);
    topBorderPath.quadraticBezierTo(0, barTop, r, barTop);
    topBorderPath.lineTo(notchStart, barTop);
    topBorderPath.cubicTo(
      notchStart + dXLeft * 0.5, barTop,
      centerX - dXLeft * 0.5, notchBottomY,
      centerX, notchBottomY,
    );
    topBorderPath.cubicTo(
      centerX + dXRight * 0.5, notchBottomY,
      notchEnd - dXRight * 0.5, barTop,
      notchEnd, barTop,
    );
    topBorderPath.lineTo(w - r, barTop);
    topBorderPath.quadraticBezierTo(w, barTop, w, barTop + r);

    final strokePaint = Paint()
      ..color = AppColors.cyan.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawPath(topBorderPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _CurvedBarPainter oldDelegate) {
    return oldDelegate.centerX != centerX ||
        oldDelegate.barTop != barTop ||
        oldDelegate.height != height;
  }
}

class _CurvedBarClipper extends CustomClipper<Path> {
  final double centerX;
  final double barTop;

  const _CurvedBarClipper({
    required this.centerX,
    required this.barTop,
  });

  @override
  Path getClip(Size size) {
    final w = size.width;
    final barBottom = size.height;
    const r = 20.0;
    const halfNotch = 27.0;
    const notchBottomY = 48.0;

    final notchStart = (centerX - halfNotch).clamp(r, w - r);
    final notchEnd = (centerX + halfNotch).clamp(r, w - r);

    final path = Path();
    path.moveTo(0, barTop + r);
    path.quadraticBezierTo(0, barTop, r, barTop);
    path.lineTo(notchStart, barTop);

    final dXLeft = centerX - notchStart;
    path.cubicTo(
      notchStart + dXLeft * 0.5, barTop,
      centerX - dXLeft * 0.5, notchBottomY,
      centerX, notchBottomY,
    );

    final dXRight = notchEnd - centerX;
    path.cubicTo(
      centerX + dXRight * 0.5, notchBottomY,
      notchEnd - dXRight * 0.5, barTop,
      notchEnd, barTop,
    );

    path.lineTo(w - r, barTop);
    path.quadraticBezierTo(w, barTop, w, barTop + r);
    path.lineTo(w, barBottom);
    path.lineTo(0, barBottom);
    path.lineTo(0, barTop + r);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant _CurvedBarClipper oldClipper) {
    return oldClipper.centerX != centerX || oldClipper.barTop != barTop;
  }
}
