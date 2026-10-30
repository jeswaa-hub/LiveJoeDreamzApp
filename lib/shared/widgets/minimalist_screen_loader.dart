import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';

/// Dream Pulse Loader — Simple, clean, interactive.
///
/// A breathing logo center with staggered sonar-pulse rings
/// and a smooth gradient progress bar. Minimal but alive.
class MinimalistScreenLoader extends StatefulWidget {
  final String? message;
  final VoidCallback? onComplete;
  final Duration duration;

  const MinimalistScreenLoader({
    super.key,
    this.message,
    this.onComplete,
    this.duration = const Duration(milliseconds: 400),
  });

  /// Show a fast interactive loading overlay
  static Future<void> show(
    BuildContext context, {
    String? message,
    Duration duration = const Duration(milliseconds: 380),
  }) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => MediaQuery.removePadding(
        context: ctx,
        removeTop: true,
        removeBottom: true,
        removeLeft: true,
        removeRight: true,
        child: Positioned.fill(
          child: MinimalistScreenLoader(
            message: message,
            duration: duration,
            onComplete: () {
              entry.remove();
            },
          ),
        ),
      ),
    );

    overlay.insert(entry);
    await Future.delayed(duration);
  }

  /// Show a loading overlay that stays visible until [future] completes
  static Future<T> showUntil<T>(
    BuildContext context, {
    required Future<T> future,
    String? message,
  }) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => MediaQuery.removePadding(
        context: ctx,
        removeTop: true,
        removeBottom: true,
        removeLeft: true,
        removeRight: true,
        child: Positioned.fill(
          child: MinimalistScreenLoader(
            message: message,
            duration: const Duration(minutes: 5),
          ),
        ),
      ),
    );

    overlay.insert(entry);

    try {
      final result = await future;
      await Future.delayed(const Duration(milliseconds: 120));
      return result;
    } finally {
      entry.remove();
    }
  }

  @override
  State<MinimalistScreenLoader> createState() => _MinimalistScreenLoaderState();
}

class _MinimalistScreenLoaderState extends State<MinimalistScreenLoader>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;    // Logo breathing
  late AnimationController _ringController;     // Sonar rings expand
  late AnimationController _dotController;      // Orbiting dots
  late AnimationController _fadeController;     // Entrance / exit
  late AnimationController _progressController; // Progress bar
  late Animation<double> _progressAnimation;
  Timer? _creepTimer;
  double _creepProgress = 0.0;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Gentle breathing pulse for logo
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Sonar ring expansion — continuous loop
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // 3 small dots orbiting — smooth
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Entrance / exit
    _fadeController = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.72, 1.0, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
      ),
    );

    // Progress
    final bool isLongLived = widget.duration >= const Duration(seconds: 10);

    _progressController = AnimationController(
      vsync: this,
      duration: isLongLived ? const Duration(milliseconds: 1400) : widget.duration,
    );

    _progressAnimation = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    );

    _progressController.forward().then((_) {
      if (isLongLived && mounted) {
        _creepTimer = Timer.periodic(const Duration(milliseconds: 280), (timer) {
          if (!mounted) {
            timer.cancel();
            return;
          }
          if (_creepProgress < 0.045) {
            setState(() => _creepProgress += 0.007);
          } else {
            timer.cancel();
          }
        });
      }
    });

    _fadeController.forward().then((_) {
      if (mounted && widget.onComplete != null) {
        widget.onComplete!();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ringController.dispose();
    _dotController.dispose();
    _fadeController.dispose();
    _progressController.dispose();
    _creepTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeController,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value.clamp(0.0, 1.0),
          child: Material(
            color: const Color(0xFF030712),
            child: SizedBox.expand(
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── Interactive Pulse Center ──
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _pulseController,
                          _ringController,
                          _dotController,
                        ]),
                        builder: (context, _) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // Sonar rings (3 staggered)
                              ..._buildSonarRings(),

                              // 3 orbiting dots
                              ..._buildOrbitingDots(),

                              // Central breathing logo
                              _buildBreathingLogo(),
                            ],
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Progress Bar ──
                    _buildProgressBar(),

                    const SizedBox(height: 14),

                    // ── Status Text ──
                    _buildStatusText(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SONAR RINGS — 3 staggered expanding + fading circles
  // ─────────────────────────────────────────────────────────────
  List<Widget> _buildSonarRings() {
    return List.generate(3, (i) {
      // Stagger each ring by 0.33 phase
      final phase = (_ringController.value + i * 0.33) % 1.0;
      final scale = Curves.easeOutCubic.transform(phase);
      final opacity = (1.0 - phase).clamp(0.0, 0.35);
      final size = 50.0 + scale * 130.0;

      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.cyan.withValues(alpha: opacity),
            width: 1.5 - phase * 0.8,
          ),
        ),
      );
    });
  }

  // ─────────────────────────────────────────────────────────────
  // ORBITING DOTS — 3 small glowing dots circling the logo
  // ─────────────────────────────────────────────────────────────
  List<Widget> _buildOrbitingDots() {
    const colors = [AppColors.cyan, AppColors.pink, Color(0xFF8B5CF6)];

    return List.generate(3, (i) {
      final angle = _dotController.value * 2 * math.pi + (i * 2 * math.pi / 3);
      const radius = 52.0;
      final x = radius * math.cos(angle);
      final y = radius * math.sin(angle);

      return Transform.translate(
        offset: Offset(x, y),
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors[i],
            boxShadow: [
              BoxShadow(
                color: colors[i].withValues(alpha: 0.7),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      );
    });
  }

  // ─────────────────────────────────────────────────────────────
  // BREATHING LOGO — Gentle scale pulse with soft glow
  // ─────────────────────────────────────────────────────────────
  Widget _buildBreathingLogo() {
    final p = _pulseController.value;
    final breathScale = 0.95 + 0.05 * p;

    return Transform.scale(
      scale: breathScale,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0A1020),
          border: Border.all(
            color: AppColors.cyan.withValues(alpha: 0.3 + p * 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.cyan.withValues(alpha: 0.15 + p * 0.15),
              blurRadius: 20 + p * 8,
              spreadRadius: 2,
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Image.asset(
          'assets/images/DreamCommunityLogo.webp',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.auto_awesome_rounded,
            color: AppColors.cyan,
            size: 24,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PROGRESS BAR — Thin gradient line
  // ─────────────────────────────────────────────────────────────
  Widget _buildProgressBar() {
    final isLongLived = widget.duration >= const Duration(seconds: 10);
    final double base = _progressAnimation.value * (isLongLived ? 0.95 : 1.0);
    final double progress = (base + _creepProgress).clamp(0.0, 1.0);

    return Container(
      width: 180,
      height: 3,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 180 * progress,
          height: 3,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00DBE9), Color(0xFFFF2E93)],
            ),
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: AppColors.cyan.withValues(alpha: 0.6),
                blurRadius: 6,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // STATUS TEXT — Label + percentage capsule
  // ─────────────────────────────────────────────────────────────
  Widget _buildStatusText() {
    final isLongLived = widget.duration >= const Duration(seconds: 10);
    final double base = _progressAnimation.value * (isLongLived ? 0.95 : 1.0);
    final double progress = (base + _creepProgress).clamp(0.0, 1.0);
    final int percent = (progress * 100).toInt().clamp(0, 100);

    return AnimatedBuilder(
      animation: _progressController,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.message ?? 'LOADING...',
              style: AppColors.geistBold(10).copyWith(
                color: AppColors.cyan.withValues(alpha: 0.85),
                letterSpacing: 2.2,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.cyan.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.cyan.withValues(alpha: 0.3),
                  width: 0.8,
                ),
              ),
              child: Text(
                '$percent%',
                style: AppColors.geistBold(10).copyWith(
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Instant PageRouteBuilder with zero transition and zero loading delay
class MinimalistPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  MinimalistPageRoute({required this.page, super.settings})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        );
}
