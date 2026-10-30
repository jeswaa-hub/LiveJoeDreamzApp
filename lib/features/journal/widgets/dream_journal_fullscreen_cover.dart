import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/features/auth/services/auth_service.dart';

class DreamJournalFullScreenCover extends StatefulWidget {
  final VoidCallback onOpenComplete;
  final int totalEntries;
  final String? userName;

  const DreamJournalFullScreenCover({
    super.key,
    required this.onOpenComplete,
    required this.totalEntries,
    this.userName,
  });

  @override
  State<DreamJournalFullScreenCover> createState() => _DreamJournalFullScreenCoverState();
}

class _DreamJournalFullScreenCoverState extends State<DreamJournalFullScreenCover>
    with TickerProviderStateMixin {
  late AnimationController _openController;
  late Animation<double> _rotateAnimation;
  late Animation<double> _fadeAnimation;
  late AnimationController _twinkleController;

  bool _hasStarted = false;
  late String _userName;

  @override
  void initState() {
    super.initState();
    _userName = (widget.userName != null && widget.userName!.isNotEmpty)
        ? widget.userName!
        : 'Joshua';
    _loadUserName();

    _twinkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _openController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    // Realistic Notebook Opening: Swings PALABAS (outward towards user from 0 to 180 degrees)
    _rotateAnimation = Tween<double>(begin: 0.0, end: math.pi).animate(
      CurvedAnimation(
        parent: _openController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _openController,
        curve: const Interval(0.93, 1.0, curve: Curves.easeOut),
      ),
    );

    _openController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onOpenComplete();
      }
    });

    // Auto-open after ~1.3 seconds pause so user sees cover then transitions to page itself
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted && !_hasStarted) {
        _startOpening();
      }
    });
  }

  Future<void> _loadUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('user_data');
      if (data != null) {
        final json = jsonDecode(data);
        final name = (json['name'] ?? '').toString().trim();
        if (name.isNotEmpty && mounted) {
          setState(() {
            _userName = name.split(' ').first;
          });
          return;
        }
      }

      final user = await AuthService().getCurrentUser();
      if (user != null && user.name.isNotEmpty && mounted) {
        setState(() {
          _userName = user.name.split(' ').first;
        });
      }
    } catch (_) {}
  }

  void _startOpening() {
    if (_hasStarted) return;
    setState(() => _hasStarted = true);
    _openController.forward();
  }

  @override
  void dispose() {
    _twinkleController.dispose();
    _openController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 380;

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: _startOpening,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _openController,
          builder: (context, child) {
            final progress = _openController.value;
            final angle = _rotateAnimation.value;
            final isOpening = progress > 0.01;
            final isFlipped = angle >= math.pi / 2; // Swung past 90 degrees outward

            // 2. 3D Hinged Notebook Cover (Sways PALABAS toward viewer & lifts UPWARDS)
            final liftAmount = -progress * (screenSize.height * 0.16) - math.sin(progress * math.pi) * 45;
            final upwardTilt = -progress * 0.08;

            return Stack(
              children: [
                // 1. Physical Spine Shadow cast on the journal page underneath as cover lifts
                if (isOpening)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.black.withOpacity((0.65 * (1.0 - progress)).clamp(0.0, 0.65)),
                            Colors.transparent,
                          ],
                          stops: [0.0, (0.15 + progress * 0.55).clamp(0.0, 1.0)],
                        ),
                      ),
                    ),
                  ),

                // 2. Hinged Cover lifting PALABAS (outward towards camera) & swaying UPWARDS
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0008) // 3D Perspective Depth (Swings PALABAS toward user)
                      ..translate(0.0, liftAmount, 0.0) // Sways/lifts UPWARDS
                      ..rotateZ(upwardTilt) // Leading edge lifts UP
                      ..rotateY(angle), // Swings PALABAS from right to left
                    alignment: const Alignment(-1.0, -0.3), // Left Spine Hinge (Notebook Binding)
                    child: Stack(
                      children: [
                        // When opening: Front face (0-90 deg) or Inside of Cover (90-180 deg)
                        if (!isFlipped) ...[
                          _buildCoverContent(screenSize, isSmallScreen),

                          // Dynamic shading as front cover angles away from viewer
                          if (isOpening)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withOpacity(
                                  (progress * 0.45).clamp(0.0, 0.45),
                                ),
                              ),
                            ),

                          // Light Seeping Glint on opening right edge
                          if (isOpening)
                            Positioned(
                              top: 0,
                              bottom: 0,
                              right: 0,
                              width: 14,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Colors.transparent,
                                      AppColors.cyan.withOpacity(0.6),
                                      Colors.white.withOpacity(0.9),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.cyan.withOpacity(0.8),
                                      blurRadius: 18,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ] else ...[
                          // Inside face of the notebook cover (flipped horizontally for correct perspective)
                          _buildInsideCoverBack(screenSize, isSmallScreen),

                          // Dynamic shading as inside cover settles open
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withOpacity(
                                ((1.0 - progress) * 0.4).clamp(0.0, 0.4),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Inside Face of the Notebook Cover (when swung past 90 degrees)
  Widget _buildInsideCoverBack(Size screenSize, bool isSmallScreen) {
    return Transform(
      transform: Matrix4.identity()..rotateY(math.pi), // Mirror horizontally for reverse face
      alignment: Alignment.center,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF070B16),
              Color(0xFF0E1626),
              Color(0xFF090E1B),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Left Spine binding crease
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 16,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Inner notebook lining bookplate
            Center(
              child: Container(
                width: isSmallScreen ? 260 : 295,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.cyan.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_stories_rounded,
                      color: AppColors.cyan.withOpacity(0.85),
                      size: 34,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'D.R.E.A.M. JOURNAL',
                      style: AppColors.soraBold(16).copyWith(
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'PERSONAL REFLECTION ARCHIVE',
                      style: AppColors.geistBold(9).copyWith(
                        color: AppColors.cyan,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 1,
                      width: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.cyan.withOpacity(0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'JOURNAL HOLDER',
                      style: AppColors.geistBold(9).copyWith(
                        color: Colors.white38,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _userName.toUpperCase(),
                      style: AppColors.soraBold(17).copyWith(
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Destination • Reason • Energy • Amigos • Mindset',
                      style: AppColors.hankenMedium(10).copyWith(
                        color: Colors.white54,
                      ),
                      textAlign: TextAlign.center,
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

  Widget _buildCoverContent(Size screenSize, bool isSmallScreen) {
    return Container(
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
        children: [
          // Nebula background glow
          Positioned(
            top: screenSize.height * 0.15,
            left: screenSize.width * 0.1,
            right: screenSize.width * 0.1,
            height: screenSize.height * 0.45,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7832C8).withOpacity(0.18),
                    blurRadius: 120,
                    spreadRadius: 30,
                  ),
                  BoxShadow(
                    color: const Color(0xFF00B4DC).withOpacity(0.14),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                  BoxShadow(
                    color: const Color(0xFFFF50A0).withOpacity(0.1),
                    blurRadius: 90,
                    spreadRadius: 15,
                  ),
                ],
              ),
            ),
          ),

          // Twinkling Star Particles (Galaxy Effect)
          ..._buildSparkles(screenSize),

          // Foreground Content (100% exact parity with Image 1 website cover)
          SafeArea(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 16 : 24,
                  vertical: isSmallScreen ? 10 : 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: isSmallScreen ? 12 : 24),

                    // Top Logo: Live Joe Dreamz
                    Image.asset(
                      'assets/images/LiveJoeDreamzLogo.webp',
                      height: isSmallScreen ? 44 : 52,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/images/LiveJoeDreamzLogo.png',
                        height: isSmallScreen ? 44 : 52,
                        fit: BoxFit.contain,
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? 20 : 32),

                    // Center Hero: 3D DREAM Logo with golden glow
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withOpacity(0.28),
                            blurRadius: 32,
                            spreadRadius: 4,
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

                    // Five Pillars in row: Destination, Reason, Energy, Amigos, Mindset
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _pillarText('Destination', const Color(0xFFFFCC00)),
                          _pillarSpacer(),
                          _pillarText('Reason', const Color(0xFFFFABF0)),
                          _pillarSpacer(),
                          _pillarText('Energy', const Color(0xFF00DBE9)),
                          _pillarSpacer(),
                          _pillarText('Amigos', const Color(0xFFFACC15)),
                          _pillarSpacer(),
                          _pillarText('Mindset', const Color(0xFF38BDF8)),
                        ],
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? 18 : 26),

                    // ✨ JOURNAL ✨
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('✨', style: TextStyle(fontSize: 16, color: Color(0xFFFFABF0))),
                        const SizedBox(width: 8),
                        Text(
                          'JOURNAL',
                          style: AppColors.soraBlack(isSmallScreen ? 28 : 34).copyWith(
                            color: Colors.white,
                            letterSpacing: 4,
                            shadows: [
                              Shadow(
                                color: Colors.white.withOpacity(0.4),
                                blurRadius: 24,
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
                      style: AppColors.soraBold(isSmallScreen ? 10 : 11).copyWith(
                        color: Colors.white.withOpacity(0.6),
                        letterSpacing: 2.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'THAT INSPIRES YOU TO',
                      textAlign: TextAlign.center,
                      style: AppColors.soraBold(isSmallScreen ? 10 : 11).copyWith(
                        color: Colors.white.withOpacity(0.6),
                        letterSpacing: 2.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text.rich(
                      TextSpan(
                        text: 'LIVE YOUR ',
                        style: AppColors.soraBlack(isSmallScreen ? 17 : 20).copyWith(
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                        children: [
                          TextSpan(
                            text: 'DREAM',
                            style: AppColors.soraBlack(isSmallScreen ? 17 : 20).copyWith(
                              color: AppColors.cyan,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? 18 : 26),

                    // Name Card Badge
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
                                style: AppColors.soraBold(11).copyWith(
                                  color: Colors.white.withOpacity(0.55),
                                  letterSpacing: 1.5,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _userName,
                                  style: AppColors.soraBold(14).copyWith(
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Multi-color gradient underline (Yellow -> Pink -> Cyan)
                          Container(
                            height: 2.5,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFFCC00),
                                  Color(0xFFFFABF0),
                                  Color(0xFF00DBE9),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? 16 : 22),

                    // Bottom 3 Diamond Star Accents (Yellow, Pink, Cyan)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text('✦', style: TextStyle(color: Color(0xFFFFCC00), fontSize: 13)),
                        SizedBox(width: 16),
                        Text('✦', style: TextStyle(color: Color(0xFFFFABF0), fontSize: 13)),
                        SizedBox(width: 16),
                        Text('✦', style: TextStyle(color: Color(0xFF00DBE9), fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillarText(String title, Color color) {
    return Text(
      title,
      style: AppColors.soraBold(11).copyWith(
        color: color,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _pillarSpacer() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text(' ', style: TextStyle(fontSize: 10)),
    );
  }

  List<Widget> _buildSparkles(Size screenSize) {
    final List<Map<String, dynamic>> starCoords = [
      {'top': 0.08, 'left': 0.12, 'color': const Color(0xFFFFCC00), 'size': 3.5},
      {'top': 0.14, 'right': 0.15, 'color': const Color(0xFFFFABF0), 'size': 4.0},
      {'top': 0.28, 'left': 0.08, 'color': const Color(0xFF00DBE9), 'size': 3.0},
      {'top': 0.42, 'right': 0.09, 'color': const Color(0xFF00DBE9), 'size': 4.0},
      {'top': 0.58, 'left': 0.18, 'color': const Color(0xFFFFCC00), 'size': 3.0},
      {'top': 0.72, 'right': 0.14, 'color': const Color(0xFFFFABF0), 'size': 3.5},
      {'top': 0.84, 'left': 0.14, 'color': const Color(0xFFFFABF0), 'size': 3.0},
      {'top': 0.88, 'right': 0.22, 'color': const Color(0xFF00DBE9), 'size': 3.0},
    ];

    return starCoords.map((s) {
      return Positioned(
        top: screenSize.height * (s['top'] as double),
        left: s['left'] != null ? screenSize.width * (s['left'] as double) : null,
        right: s['right'] != null ? screenSize.width * (s['right'] as double) : null,
        child: AnimatedBuilder(
          animation: _twinkleController,
          builder: (context, child) {
            final opacity = (0.3 + 0.7 * math.sin(_twinkleController.value * math.pi)).clamp(0.1, 1.0);
            return Container(
              width: (s['size'] as double),
              height: (s['size'] as double),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (s['color'] as Color).withOpacity(opacity),
                boxShadow: [
                  BoxShadow(
                    color: (s['color'] as Color).withOpacity(opacity * 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            );
          },
        ),
      );
    }).toList();
  }
}
