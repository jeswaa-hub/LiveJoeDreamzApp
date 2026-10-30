import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dream_community_app/features/auth/services/auth_service.dart';
import 'package:dream_community_app/features/journal/screens/journal_screen.dart';
import 'package:dream_community_app/features/home/screens/community_hub_screen.dart';

class StarParticle {
  final double xRatio;
  final double yRatio;
  final double size;
  final double speed;
  final double twinklePhase;
  final Color color;

  StarParticle({
    required this.xRatio,
    required this.yRatio,
    required this.size,
    required this.speed,
    required this.twinklePhase,
    required this.color,
  });
}

class ShootingStarParticle {
  final double startXRatio;
  final double startYRatio;
  final double length;
  final double angle; // angle in radians
  final double timeOffset; // phase offset [0..1]
  final Color headColor;

  ShootingStarParticle({
    required this.startXRatio,
    required this.startYRatio,
    required this.length,
    required this.angle,
    required this.timeOffset,
    required this.headColor,
  });
}

class SpaceStarfieldPainter extends CustomPainter {
  final double progress;
  final List<StarParticle> stars;
  final List<ShootingStarParticle> shootingStars;

  SpaceStarfieldPainter({
    required this.progress,
    required this.stars,
    required this.shootingStars,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Deep Dark Space Void Base Gradient
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(0.1 + 0.15 * math.sin(progress * 2 * math.pi), -0.4),
        radius: 1.5,
        colors: const [
          Color(0xFF190B38),
          Color(0xFF070B1F),
          Color(0xFF020308),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 2. Cosmic Nebula Clouds
    final nebula1 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00DBE9).withOpacity(0.12 + 0.04 * math.sin(progress * 2 * math.pi)),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.8, size.height * 0.2),
        radius: size.width * 0.6,
      ));
    canvas.drawRect(rect, nebula1);

    final nebula2 = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFABF0).withOpacity(0.10 + 0.03 * math.cos(progress * 2 * math.pi)),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.15, size.height * 0.7),
        radius: size.width * 0.65,
      ));
    canvas.drawRect(rect, nebula2);

    // 3. Drifting & Twinkling Background Stars (60 Stars)
    for (final star in stars) {
      final dx = ((star.xRatio + progress * star.speed) % 1.0) * size.width;
      final dy = star.yRatio * size.height;
      final twinkle = 0.4 + 0.6 * math.sin((progress * 2 * math.pi * 3) + star.twinklePhase);
      final currentSize = star.size * (0.8 + 0.4 * twinkle);

      final starPaint = Paint()
        ..color = star.color.withOpacity(twinkle.clamp(0.2, 1.0));
      canvas.drawCircle(Offset(dx, dy), currentSize, starPaint);

      if (star.size > 2.0) {
        final glowPaint = Paint()
          ..color = star.color.withOpacity((twinkle * 0.3).clamp(0.0, 0.4))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawCircle(Offset(dx, dy), currentSize * 2.2, glowPaint);
      }
    }

    // 4. Diagonal Shooting Stars Engine (☄️ Periodic Light Trails)
    for (final ss in shootingStars) {
      final cycleTime = (progress + ss.timeOffset) % 1.0;
      if (cycleTime > 0.45) continue;

      final normT = cycleTime / 0.45;
      final headX = (ss.startXRatio * size.width) + (normT * 320 * math.cos(ss.angle));
      final headY = (ss.startYRatio * size.height) + (normT * 320 * math.sin(ss.angle));

      final tailX = headX - (ss.length * math.cos(ss.angle));
      final tailY = headY - (ss.length * math.sin(ss.angle));

      final headPos = Offset(headX, headY);
      final tailPos = Offset(tailX, tailY);

      final tailPaint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.5
        ..shader = LinearGradient(
          colors: [
            ss.headColor.withOpacity(0.0),
            ss.headColor.withOpacity(0.6),
            Colors.white.withOpacity(0.95),
          ],
          stops: const [0.0, 0.7, 1.0],
        ).createShader(Rect.fromPoints(tailPos, headPos));

      canvas.drawLine(tailPos, headPos, tailPaint);

      final headPaint = Paint()..color = Colors.white;
      canvas.drawCircle(headPos, 2.8, headPaint);

      final headGlow = Paint()
        ..color = ss.headColor.withOpacity(0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
        canvas.drawCircle(headPos, 6.0, headGlow);
    }
  }

  @override
  bool shouldRepaint(covariant SpaceStarfieldPainter oldDelegate) => true;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _coverController;
  late Animation<double> _flipAnimation;
  late AnimationController _spaceAnimationController;

  bool _isJournalCoverOpen = false;
  String _userName = 'CHAMP';

  final List<StarParticle> _stars = [];
  final List<ShootingStarParticle> _shootingStars = [];

  static const bgDark = Color(0xFF060913);
  static const cyan = Color(0xFF00DBE9);

  @override
  void initState() {
    super.initState();
    _loadUser();

    _coverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );

    _flipAnimation = CurvedAnimation(
      parent: _coverController,
      curve: Curves.easeInOutCubic,
    );

    _spaceAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _generateStarfield();
  }

  void _generateStarfield() {
    final rng = math.Random(42);
    for (int i = 0; i < 60; i++) {
      _stars.add(StarParticle(
        xRatio: rng.nextDouble(),
        yRatio: rng.nextDouble(),
        size: 0.8 + rng.nextDouble() * 2.4,
        speed: 0.02 + rng.nextDouble() * 0.05,
        twinklePhase: rng.nextDouble() * 2 * math.pi,
        color: i % 5 == 0
            ? cyan
            : i % 7 == 0
                ? const Color(0xFFFFABF0)
                : Colors.white,
      ));
    }

    _shootingStars.addAll([
      ShootingStarParticle(
        startXRatio: 0.05,
        startYRatio: 0.1,
        length: 110,
        angle: math.pi / 4, // 45 deg downwards right
        timeOffset: 0.0,
        headColor: Colors.white,
      ),
      ShootingStarParticle(
        startXRatio: 0.2,
        startYRatio: -0.1,
        length: 130,
        angle: math.pi / 4, // 45 deg downwards right
        timeOffset: 0.35,
        headColor: cyan,
      ),
      ShootingStarParticle(
        startXRatio: 0.4,
        startYRatio: 0.05,
        length: 95,
        angle: math.pi / 4.5,
        timeOffset: 0.7,
        headColor: const Color(0xFFFFABF0),
      ),
    ]);
  }

  Future<void> _loadUser() async {
    final user = await AuthService().getCurrentUser();
    if (user != null && user.name.isNotEmpty && mounted) {
      setState(() {
        _userName = user.name;
      });
    }
  }

  @override
  void dispose() {
    _coverController.dispose();
    _spaceAnimationController.dispose();
    super.dispose();
  }

  void _toggleJournalCover() {
    if (_coverController.isAnimating) return;
    if (_isJournalCoverOpen) {
      _coverController.reverse().then((_) {
        if (mounted) setState(() => _isJournalCoverOpen = false);
      });
    } else {
      _coverController.forward().then((_) {
        if (mounted) setState(() => _isJournalCoverOpen = true);
      });
    }
  }

  void _navigateToCommunityHub([int initialIndex = 0]) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CommunityHubScreen(initialIndex: initialIndex)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Root Standalone Journal Screen (NO bottom navigation bar!)
        Scaffold(
          backgroundColor: bgDark,
          body: JournalScreen(
            onToggleCover: _toggleJournalCover,
            onNavigateCommunity: () => _navigateToCommunityHub(0),
          ),
        ),

        // 2. 100% Full-Viewport 3D Cover Overlay
        AnimatedBuilder(
          animation: _flipAnimation,
          builder: (context, child) {
            final progress = _flipAnimation.value;
            final angle = progress * math.pi; // 0 to 180 deg
            final isFlipped = angle >= math.pi / 2;
            final isFullyOpen = progress >= 0.99;

            if (isFullyOpen) return const SizedBox.shrink();

            return Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012) // 3D Perspective Depth
                    ..rotateY(angle),
                  alignment: Alignment.centerLeft, // Left Spine Hinge
                  child: isFlipped
                      ? _buildInsideCoverBack()
                      : _buildProgrammaticDreamJournalCover(),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // 100% Exact Parity with Image 1 Website Cover Page
  Widget _buildProgrammaticDreamJournalCover() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 380;
    final firstName = _userName.trim().isNotEmpty ? _userName.trim().split(' ').first : 'Joshua';

    return GestureDetector(
      onTap: _toggleJournalCover,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF050810),
              Color(0xFF0A0E1A),
              Color(0xFF111833),
              Color(0xFF1A1040),
              Color(0xFF0F1A30),
              Color(0xFF0A0E1A),
            ],
            stops: [0.0, 0.15, 0.35, 0.55, 0.75, 1.0],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Infinite Moving & Twinkling Space Starfield & Shooting Stars Canvas
            AnimatedBuilder(
              animation: _spaceAnimationController,
              builder: (context, child) {
                return CustomPaint(
                  painter: SpaceStarfieldPainter(
                    progress: _spaceAnimationController.value,
                    stars: _stars,
                    shootingStars: _shootingStars,
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),

            // Nebula Soft Glow behind DREAM logo
            Center(
              child: Container(
                width: screenSize.width * 0.75,
                height: screenSize.height * 0.4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7832C8).withOpacity(0.18),
                      blurRadius: 100,
                      spreadRadius: 20,
                    ),
                    BoxShadow(
                      color: const Color(0xFF00B4DC).withOpacity(0.12),
                      blurRadius: 80,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
            ),

            // Left Spine Accent Ribbon
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 5,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [cyan, Color(0xFFFFABF0), cyan],
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Foreground Content: Exact match to Image 1
            SafeArea(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 16 : 24,
                    vertical: isSmallScreen ? 8 : 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: isSmallScreen ? 10 : 20),

                      // Top Logo: Live Joe Dreamz
                      Image.asset(
                        'assets/images/LiveJoeDreamzLogo.webp',
                        height: isSmallScreen ? 44 : 54,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/images/LiveJoeDreamzLogo.png',
                          height: isSmallScreen ? 44 : 54,
                          fit: BoxFit.contain,
                        ),
                      ),

                      SizedBox(height: isSmallScreen ? 20 : 32),

                      // Center Hero: 3D DREAM Logo
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withOpacity(0.3),
                              blurRadius: 28,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/dreamLgo.webp',
                          width: isSmallScreen ? 240 : 285,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/images/dreamLgo.png',
                            width: isSmallScreen ? 240 : 285,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // 5 Pillars Row: Destination, Reason, Energy, Amigos, Mindset
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Destination', style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFFFCC00))),
                            _pillarSpacer(),
                            Text('Reason', style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFFFABF0))),
                            _pillarSpacer(),
                            Text('Energy', style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF00DBE9))),
                            _pillarSpacer(),
                            Text('Amigos', style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFFACC15))),
                            _pillarSpacer(),
                            Text('Mindset', style: GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8))),
                          ],
                        ),
                      ),

                      SizedBox(height: isSmallScreen ? 16 : 24),

                      // ✨ JOURNAL ✨
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('✨', style: TextStyle(fontSize: 16, color: Color(0xFFFFABF0))),
                          const SizedBox(width: 8),
                          Text(
                            'JOURNAL',
                            style: GoogleFonts.sora(
                              fontSize: isSmallScreen ? 28 : 34,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 4,
                              shadows: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.35),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('✨', style: TextStyle(fontSize: 16, color: Color(0xFFFFABF0))),
                        ],
                      ),

                      SizedBox(height: isSmallScreen ? 14 : 20),

                      // Subtitle & Quote
                      Text(
                        'A DAILY WRITING EXERCISES',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.sora(
                          fontSize: isSmallScreen ? 10 : 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withOpacity(0.6),
                          letterSpacing: 2.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'THAT INSPIRES YOU TO',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.sora(
                          fontSize: isSmallScreen ? 10 : 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withOpacity(0.6),
                          letterSpacing: 2.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          text: 'LIVE YOUR ',
                          style: GoogleFonts.sora(
                            fontSize: isSmallScreen ? 17 : 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                          children: [
                            TextSpan(
                              text: 'DREAM',
                              style: GoogleFonts.sora(
                                fontSize: isSmallScreen ? 17 : 20,
                                fontWeight: FontWeight.w900,
                                color: cyan,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isSmallScreen ? 18 : 26),

                      // Name Card Badge: Rounded card with gradient underline
                      Container(
                        width: isSmallScreen ? 250 : 280,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.24),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'NAME: ',
                                  style: GoogleFonts.sora(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white.withOpacity(0.55),
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    firstName,
                                    style: GoogleFonts.sora(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 2,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFFCC00),
                                    Color(0xFFFF50A0),
                                    Color(0xFF00E5FF),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: isSmallScreen ? 16 : 24),

                      // 3 Bottom Diamond Stars: ✦ (yellow) ✦ (pink) ✦ (cyan)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text('✦', style: TextStyle(color: Color(0xFFFFCC00), fontSize: 13)),
                          SizedBox(width: 16),
                          Text('✦', style: TextStyle(color: Color(0xFFFF50A0), fontSize: 13)),
                          SizedBox(width: 16),
                          Text('✦', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 13)),
                        ],
                      ),
                      SizedBox(height: isSmallScreen ? 12 : 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pillarSpacer() {
    return const SizedBox(width: 10);
  }

  Widget _buildInsideCoverBack() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF090D1A),
      ),
      child: Center(
        child: Text(
          'D.R.E.A.M JOURNAL',
          style: GoogleFonts.sora(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: cyan,
          ),
        ),
      ),
    );
  }
}
