import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dream_community_app/core/route/app_routes.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/features/auth/screens/login_screen.dart';
import 'package:dream_community_app/features/community_tier/screens/community_tier_screen.dart';
import 'package:dream_community_app/features/merch/services/cart_store.dart';
import 'package:dream_community_app/shared/widgets/space_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _driftController;
  late AnimationController _twinkleController;

  static const Color bgDark = Color(0xFF020205);
  static const Color cyan = Color(0xFF00DBE9);
  static const Color magenta = Color(0xFFFD18F5);
  static const Color cardBg = Color(0x660F1729);
  static const Color borderLight = Color(0x0DFFFFFF);

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0, 0.4)),
    );
    _logoController.forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _pulseController.repeat(reverse: true);
    });

    _driftController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 80),
    )..repeat();

    _twinkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);

    CartStore().load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _logoController.dispose();
    _pulseController.dispose();
    _driftController.dispose();
    _twinkleController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) => setState(() => _currentPage = index);

  Future<void> _markOnboardingComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_onboarding', true);
    } catch (_) {}
  }

  void _nextPage() async {
    if (_currentPage < 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      await _markOnboardingComplete();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        AppRoutes.slideFromBottom(const CommunityTierScreen()),
      );
    }
  }

  void _skip() async {
    await _markOnboardingComplete();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      AppRoutes.slideFromBottom(const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          _buildAnimatedSpace(size),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: GestureDetector(
                      onTap: _skip,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                          color: AppColors.surface.withOpacity(0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.login_rounded, size: 14, color: AppColors.cyan),
                            const SizedBox(width: 6),
                            Text(
                              'LOGIN',
                              style: AppColors.geistBold(11).copyWith(
                                color: Colors.white,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _buildPage1(size),
                      _buildPage2(size),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: List.generate(2, (index) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 6),
                            width: _currentPage == index ? 24 : 8,
                            height: 4,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: _currentPage == index ? AppColors.cyan : Colors.white.withOpacity(0.15),
                            ),
                          );
                        }),
                      ),
                      GestureDetector(
                        onTap: _nextPage,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                          decoration: BoxDecoration(
                            color: _currentPage == 1 ? AppColors.cyan : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: (_currentPage == 1 ? AppColors.cyan : Colors.white).withOpacity(0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _currentPage == 1 ? 'JOIN NOW' : 'NEXT',
                                style: AppColors.soraBold(12).copyWith(
                                  letterSpacing: 1.5,
                                  color: const Color(0xFF040A12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF040A12)),
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
        ],
      ),
    );
  }

  // ==================== PAGE 1: Welcome ====================
  Widget _buildPage1(Size size) {
    return Stack(
      children: [
        // Ambient Cyan Glow behind hero emblem
        Positioned(
          top: 60,
          left: size.width * 0.5 - 140,
          child: IgnorePointer(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.cyan.withOpacity(0.14),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Foreground Content
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Central Live Joe Dreamz Hero Logo (Clean, No Background Box)
              ScaleTransition(
                scale: _logoScale,
                child: FadeTransition(
                  opacity: _logoOpacity,
                  child: ScaleTransition(
                    scale: _pulseAnimation,
                    child: Image.asset(
                      'assets/images/LiveJoeDreamzLogo.png',
                      width: 160,
                      height: 160,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Headline with Cyan Accent Glow
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Are you living your\n',
                      style: AppColors.soraBold(26).copyWith(
                        color: Colors.white,
                        letterSpacing: -0.5,
                        height: 1.25,
                      ),
                    ),
                    TextSpan(
                      text: 'D.R.E.A.M?',
                      style: AppColors.soraBold(28).copyWith(
                        color: AppColors.cyan,
                        letterSpacing: -0.5,
                        shadows: [
                          Shadow(
                            color: AppColors.cyan.withOpacity(0.6),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Glass Statement Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF0D172A).withOpacity(0.75),
                      const Color(0xFF070D18).withOpacity(0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.cyan.withOpacity(0.2),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cyan.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  'Join a community of people who are\nstriving to live their D.R.E.A.M!',
                  textAlign: TextAlign.center,
                  style: AppColors.geistMedium(13).copyWith(
                    color: Colors.white.withOpacity(0.85),
                    height: 1.55,
                  ),
                ),
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== PAGE 2: What You Get + JOIN NOW ====================
  Widget _buildPage2(Size size) {
    final benefits = [
      {
        'icon': Icons.podcasts_rounded,
        'title': 'D.R.E.A.M Journal Episodes',
        'color': AppColors.cyan,
      },
      {
        'icon': Icons.smart_display_rounded,
        'title': 'D.R.E.A.M Activities Videos',
        'color': AppColors.cyan,
      },
      {
        'icon': Icons.auto_stories_rounded,
        'title': 'D.R.E.A.M Book Club',
        'color': AppColors.cyan,
      },
      {
        'icon': Icons.forum_rounded,
        'title': 'D.R.E.A.M Book Club Chat',
        'color': AppColors.cyan,
      },
      {
        'icon': Icons.local_offer_rounded,
        'title': 'Discounted on Merch 10% Off',
        'color': AppColors.cyan,
      },
    ];

    return Stack(
      children: [
        // Ambient Cyan Brand Glow
        Positioned(
          top: 40,
          left: size.width * 0.5 - 140,
          child: IgnorePointer(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.cyan.withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Main Foreground Layout
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Glowing Logo with Cyan Halo
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.cyan.withOpacity(0.20),
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cyan.withOpacity(0.25),
                      blurRadius: 36,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: _buildLogo(68),
              ),
              const SizedBox(height: 12),

              // Eyebrow Capsule (Single Theme Color)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.cyan.withOpacity(0.3),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 11, color: AppColors.cyan),
                    const SizedBox(width: 6),
                    Text(
                      'ALL-IN-ONE PASS',
                      style: AppColors.geistBold(10).copyWith(
                        color: AppColors.cyan,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Headline with Cyan Accent Glow
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'What You ',
                      style: AppColors.soraBold(26).copyWith(
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    TextSpan(
                      text: 'Get',
                      style: AppColors.soraBold(26).copyWith(
                        color: AppColors.cyan,
                        letterSpacing: -0.5,
                        shadows: [
                          Shadow(
                            color: AppColors.cyan.withOpacity(0.6),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Master Bento Glass Showcase
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF0D172A).withOpacity(0.85),
                      const Color(0xFF070D18).withOpacity(0.92),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppColors.cyan.withOpacity(0.2),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cyan.withOpacity(0.12),
                      blurRadius: 30,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Card Top Meta Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.cyan,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.cyan,
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'MEMBERSHIP INCLUSIONS',
                              style: AppColors.geistBold(10).copyWith(
                                color: Colors.white70,
                                letterSpacing: 1.3,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.cyan.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.cyan.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            '5 UNLOCKED',
                            style: AppColors.geistBold(9).copyWith(
                              color: AppColors.cyan,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Divider(color: Colors.white.withOpacity(0.07), height: 1),
                    const SizedBox(height: 10),

                    // The 5 Micro-Cards (All in Cyan Brand Color)
                    ...benefits.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final b = entry.value;
                      final isLast = idx == benefits.length - 1;

                      return Padding(
                        padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.025),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.cyan.withOpacity(0.18),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Glowing Cyan Icon Capsule
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.cyan.withOpacity(0.22),
                                      AppColors.cyan.withOpacity(0.06),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                    color: AppColors.cyan.withOpacity(0.35),
                                    width: 1.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.cyan.withOpacity(0.15),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  b['icon'] as IconData,
                                  size: 17,
                                  color: AppColors.cyan,
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Title
                              Expanded(
                                child: Text(
                                  b['title'] as String,
                                  style: AppColors.soraBold(13).copyWith(
                                    color: Colors.white,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Cyan Checkmark
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.cyan.withOpacity(0.12),
                                  border: Border.all(
                                    color: AppColors.cyan.withOpacity(0.4),
                                    width: 1.0,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: AppColors.cyan,
                                  size: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== LOGO ====================
  Widget _buildLogo(double size) {
    return Image.asset(
      'assets/images/DreamCommunityLogo.webp',
      width: size,
      height: size,
      fit: BoxFit.contain,
      gaplessPlayback: true,
    );
  }

  // ==================== SPACE ====================
  Widget _buildAnimatedSpace(Size size) {
    return SpaceBackground(
      driftController: _driftController,
      twinkleController: _twinkleController,
      child: const SizedBox.expand(),
    );
  }
}
