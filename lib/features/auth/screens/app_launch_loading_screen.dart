import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/features/home/screens/community_hub_screen.dart';
import 'package:dream_community_app/features/community_tier/screens/community_tier_screen.dart';
import 'package:dream_community_app/shared/widgets/space_background.dart';
import 'package:dream_community_app/core/services/pending_approval_sync_service.dart';

/// Cinematic App Launch Loading Screen
/// Features:
/// 1. Deep space background with drifting stars and subtle cyan ambient aura.
/// 2. LiveJoeDreamz Crest with smooth breathing pulse.
/// 3. "LIVEJOEDREAMZ" typographic loading bar that fills with glowing electric cyan.
/// 4. Horizontal center laser split upon 100% completion.
/// 5. Top shutter slides UP and bottom shutter slides DOWN, parting to reveal the Home Screen.
class AppLaunchLoadingScreen extends StatefulWidget {
  const AppLaunchLoadingScreen({super.key});

  @override
  State<AppLaunchLoadingScreen> createState() => _AppLaunchLoadingScreenState();
}

class _AppLaunchLoadingScreenState extends State<AppLaunchLoadingScreen>
    with TickerProviderStateMixin {
  // Cosmic animations
  late AnimationController _driftController;
  late AnimationController _twinkleController;

  // Logo breathing animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Text loading fill animation (0% -> 100%)
  late AnimationController _fillController;
  late Animation<double> _fillAnimation;

  // Connecting 3-dot animation
  late AnimationController _dotsController;

  // Shutter parting animation (Mahahati sa gitna: Top moves up, Bottom moves down)
  late AnimationController _splitController;
  late Animation<double> _splitAnimation;

  // State flags
  bool _isSplitting = false;
  bool _isConnected = false;
  Widget? _destinationWidget;
  Completer<void>? _authCheckCompleter;

  @override
  void initState() {
    super.initState();

    // 1. Cosmic drifting and twinkling
    _driftController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    )..repeat();

    _twinkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // 2. Logo breathing scale
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // 3. Fill controller (1600ms smooth fill)
    _fillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _fillAnimation = CurvedAnimation(
      parent: _fillController,
      curve: Curves.easeInOutCubic,
    );

    // 4. Connecting 3 dots animation
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    // 5. Split controller (700ms parting blast shutters)
    _splitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _splitAnimation = CurvedAnimation(
      parent: _splitController,
      curve: Curves.easeInOutCubic,
    );

    _splitController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted && _destinationWidget != null) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => _destinationWidget!,
            transitionDuration: Duration.zero,
          ),
        );
      }
    });

    // Trigger auth check and sequence
    _authCheckCompleter = Completer<void>();
    _checkAuth();
    _startAnimationSequence();
  }

  Future<void> _checkAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (!mounted) return;
      if (token != null && token.isNotEmpty) {
        PendingApprovalSyncService.instance.checkAndResumePending();
        _destinationWidget = const CommunityHubScreen(initialIndex: 0);
      } else {
        _destinationWidget = const CommunityTierScreen();
      }
    } catch (_) {
      _destinationWidget = const CommunityTierScreen();
    } finally {
      if (!(_authCheckCompleter?.isCompleted ?? true)) {
        _authCheckCompleter?.complete();
      }
    }
  }

  Future<void> _startAnimationSequence() async {
    // Brief initial cosmic settling pause
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    // Start filling LIVEJOEDREAMZ text bar
    await _fillController.forward();
    if (!mounted) return;

    // Ensure auth resolution is finished
    if (_destinationWidget == null) {
      await _authCheckCompleter?.future;
    }
    if (!mounted) return;

    // Pause briefly at 100% full so user sees "Connected!" and the laser cut
    setState(() {
      _isConnected = true;
      _isSplitting = true;
    });
    await Future.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;

    // Part the screen horizontally (top up, bottom down)
    _splitController.forward();
  }

  @override
  void dispose() {
    _driftController.dispose();
    _twinkleController.dispose();
    _pulseController.dispose();
    _fillController.dispose();
    _dotsController.dispose();
    _splitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final screenH = screenSize.height;
    final screenW = screenSize.width;
    final halfH = screenH / 2;

    return Scaffold(
      backgroundColor: const Color(0xFF040A12),
      body: Stack(
        children: [
          // LAYER 0: Revealed Home Screen (ready behind the parting shutters)
          if (_destinationWidget != null)
            Positioned.fill(
              child: _destinationWidget!,
            ),

          // LAYER 1: Top Shutter (Clips top half, slides UP)
          AnimatedBuilder(
            animation: _splitAnimation,
            builder: (context, _) {
              final splitVal = _splitAnimation.value;
              final offsetY = -halfH * 1.15 * splitVal;

              return Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: halfH,
                child: Transform.translate(
                  offset: Offset(0, offsetY),
                  child: ClipRect(
                    child: Stack(
                      children: [
                        // OverflowBox renders the complete splash aligned to the top
                        OverflowBox(
                          alignment: Alignment.topCenter,
                          minWidth: screenW,
                          maxWidth: screenW,
                          minHeight: screenH,
                          maxHeight: screenH,
                          child: _buildFullSplashContent(screenSize),
                        ),

                        // Glowing electric cyan laser seam on the bottom edge
                        if (_isSplitting)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 2,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.cyan,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.cyan.withOpacity(0.95),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                  const BoxShadow(
                                    color: Colors.white,
                                    blurRadius: 4,
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
            },
          ),

          // LAYER 2: Bottom Shutter (Clips bottom half, slides DOWN)
          AnimatedBuilder(
            animation: _splitAnimation,
            builder: (context, _) {
              final splitVal = _splitAnimation.value;
              final offsetY = halfH * 1.15 * splitVal;

              return Positioned(
                top: halfH,
                left: 0,
                right: 0,
                height: halfH,
                child: Transform.translate(
                  offset: Offset(0, offsetY),
                  child: ClipRect(
                    child: Stack(
                      children: [
                        // OverflowBox renders the complete splash aligned to the bottom
                        OverflowBox(
                          alignment: Alignment.bottomCenter,
                          minWidth: screenW,
                          maxWidth: screenW,
                          minHeight: screenH,
                          maxHeight: screenH,
                          child: _buildFullSplashContent(screenSize),
                        ),

                        // Glowing electric cyan laser seam on the top edge
                        if (_isSplitting)
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            height: 2,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.cyan,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.cyan.withOpacity(0.95),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                  const BoxShadow(
                                    color: Colors.white,
                                    blurRadius: 4,
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
            },
          ),
        ],
      ),
    );
  }

  /// Full Splash Screen content (Identical instance for both top & bottom shutters)
  /// Positioned so the exact horizontal cut line (Y = screenH / 2) passes right
  /// through the horizontal equator of "LIVEJOEDREAMZ".
  Widget _buildFullSplashContent(Size screenSize) {
    final centerY = screenSize.height / 2;

    return Container(
      width: screenSize.width,
      height: screenSize.height,
      color: const Color(0xFF040A12),
      child: Stack(
        children: [
          // 1. Cosmic Drifting Stars & Nebula
          SpaceBackground(
            driftController: _driftController,
            twinkleController: _twinkleController,
            child: const SizedBox.expand(),
          ),

          // 2. Central Cyan Ambient Glow Aura
          Center(
            child: IgnorePointer(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.cyan.withOpacity(0.16),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Live Joe Dreamz Crest Logo (Positioned above the center cut)
          Positioned(
            bottom: (screenSize.height - centerY) + 38,
            left: 0,
            right: 0,
            child: Center(
              child: ScaleTransition(
                scale: _pulseAnimation,
                child: Image.asset(
                  'assets/images/LiveJoeDreamzLogo.png',
                  width: 125,
                  height: 125,
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),

          // 4. LIVEJOEDREAMZ Text Loading Bar (Centered exactly on the cut line Y = centerY)
          Positioned(
            top: centerY - 18,
            left: 0,
            right: 0,
            height: 36,
            child: Center(
              child: _buildLiveJoeDreamzLoadingBar(),
            ),
          ),

          // 5. Dynamic Status & Percentage (Positioned below the center cut)
          Positioned(
            top: centerY + 34,
            left: 0,
            right: 0,
            child: Center(
              child: _buildProgressDetails(),
            ),
          ),
        ],
      ),
    );
  }

  /// "LIVEJOEDREAMZ" Athletic Typography Loading Bar
  /// Dim base layer + glowing electric cyan fill clipped to progress (0.0 -> 1.0)
  Widget _buildLiveJoeDreamzLoadingBar() {
    return AnimatedBuilder(
      animation: _fillAnimation,
      builder: (context, _) {
        final progress = _fillAnimation.value;

        return IntrinsicWidth(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Base unfilled dim text
              Text(
                'LIVEJOEDREAMZ',
                textAlign: TextAlign.center,
                style: GoogleFonts.russoOne(
                  fontSize: 24,
                  letterSpacing: 4.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withOpacity(0.18),
                ),
              ),

              // Filled electric cyan text clipped horizontally
              ClipRect(
                clipper: _TextFillClipper(progress),
                child: Text(
                  'LIVEJOEDREAMZ',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.russoOne(
                    fontSize: 24,
                    letterSpacing: 4.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.cyan,
                    shadows: [
                      Shadow(
                        color: AppColors.cyan.withOpacity(0.9),
                        blurRadius: 18,
                      ),
                      const Shadow(
                        color: AppColors.cyan,
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),

              // Glowing laser cursor sweep along the fill leading edge
              if (progress > 0.02 && progress < 0.98)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment(-1.0 + (progress * 2.0), 0.0),
                    child: Container(
                      width: 2.5,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.cyan,
                            blurRadius: 8,
                            spreadRadius: 2.5,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Progress Percentage & "Connecting..." / "Connected!" Status
  Widget _buildProgressDetails() {
    return AnimatedBuilder(
      animation: _fillAnimation,
      builder: (context, _) {
        final percent = (_fillAnimation.value * 100).toInt().clamp(0, 100);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Percentage readout
            Text(
              '$percent%',
              style: GoogleFonts.sora(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.cyan,
                letterSpacing: 2.0,
              ),
            ),

            const SizedBox(height: 6),

            // Dynamic Status: "Connecting • • •" or "Connected!"
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _isConnected
                  ? Row(
                      key: const ValueKey('connected'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(
                            color: AppColors.cyan,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.cyan,
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Connected!',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.cyan,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      key: const ValueKey('connecting'),
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Connecting',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.65),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 4),
                        _buildAnimatedDot(0),
                        const SizedBox(width: 3),
                        _buildAnimatedDot(1),
                        const SizedBox(width: 3),
                        _buildAnimatedDot(2),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnimatedDot(int index) {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (context, _) {
        // Sequential staggered sine wave for smooth 3-dot pulse
        final t = (_dotsController.value - (index * 0.25)) % 1.0;
        final opacity = (sin(t * 2 * pi) * 0.45 + 0.55).clamp(0.2, 1.0);
        return Container(
          width: 3.5,
          height: 3.5,
          decoration: BoxDecoration(
            color: AppColors.cyan.withOpacity(opacity),
            shape: BoxShape.circle,
            boxShadow: [
              if (opacity > 0.65)
                BoxShadow(
                  color: AppColors.cyan.withOpacity(0.7),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Precise horizontal clipper for text fill
class _TextFillClipper extends CustomClipper<Rect> {
  final double progress;
  _TextFillClipper(this.progress);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * progress.clamp(0.0, 1.0), size.height);
  }

  @override
  bool shouldReclip(_TextFillClipper oldClipper) => oldClipper.progress != progress;
}
