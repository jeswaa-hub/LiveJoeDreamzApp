import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dream_community_app/core/route/app_routes.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/core/api/api_endpoints.dart';
import 'package:dream_community_app/core/api/dio_client.dart';
import 'package:dream_community_app/features/auth/screens/register_screen.dart';
import 'package:dream_community_app/features/auth/services/auth_service.dart';
import 'package:dream_community_app/features/home/screens/community_hub_screen.dart';
import 'package:dream_community_app/shared/widgets/space_background.dart';
import 'package:dream_community_app/shared/widgets/app_toast.dart';
import 'package:dream_community_app/shared/widgets/loading_overlay.dart';
import 'package:dream_community_app/core/services/pending_approval_sync_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;

  String? _emailError;
  String? _passwordError;

  late AnimationController _driftController;
  late AnimationController _twinkleController;

  static const Color bgDark = Color(0xFF020205);
  static const Color cyan = Color(0xFF00DBE9);
  static const Color cardBg = Color(0xFF0C1220);

  @override
  void initState() {
    super.initState();
    _driftController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _twinkleController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _loadRememberedEmail();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _driftController.dispose();
    _twinkleController.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('remembered_email');
    if (savedEmail != null && savedEmail.isNotEmpty) {
      setState(() { _rememberMe = true; _emailController.text = savedEmail; });
    }
  }

  Future<void> _saveRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('remembered_email', _emailController.text.trim());
    } else {
      await prefs.remove('remembered_email');
    }
  }

  bool _validate() {
    bool valid = true;
    final email = _emailController.text.trim();
    final pass = _passwordController.text;

    setState(() {
      if (email.isEmpty) { _emailError = 'Email is required'; valid = false; }
      else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) { _emailError = 'Invalid email format'; valid = false; }
      else { _emailError = null; }

      if (pass.isEmpty) { _passwordError = 'Password is required'; valid = false; }
      else { _passwordError = null; }
    });
    return valid;
  }

  void _login() async {
    if (!_validate()) {
      final firstError = _emailError ?? _passwordError ?? 'Please fix the errors';
      AppToast.show(context, firstError, type: ToastType.error);
      return;
    }
    setState(() => _isLoading = true);

    final result = await AuthService().login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (result.isSuccess) {
        await _saveRememberedEmail();
        PendingApprovalSyncService.instance.checkAndResumePending();
        AppToast.show(context, 'Welcome back, ${result.user!.name}!', type: ToastType.success);
        if (mounted) {
          Navigator.of(context).pushReplacement(AppRoutes.minimalistTransition(const CommunityHubScreen(initialIndex: 0)));
        }
      } else {
        AppToast.show(context, result.error ?? 'Login failed', type: ToastType.error);
      }
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController();
    bool isLoading = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0D172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.cyan.withOpacity(0.25), width: 1.2),
          ),
          title: Text(
            'Reset Password',
            style: AppColors.soraBold(18).copyWith(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your email address and we\'ll send you a link to reset your password.',
                style: AppColors.geistMedium(13).copyWith(color: Colors.white.withOpacity(0.6)),
              ),
              const SizedBox(height: 20),
              Text(
                'ACCOUNT EMAIL',
                style: AppColors.geistBold(10).copyWith(
                  color: AppColors.cyan,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF060B14).withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: TextField(
                  controller: resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  style: AppColors.geistMedium(14).copyWith(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'you@email.com',
                    hintStyle: AppColors.geistMedium(14).copyWith(color: Colors.white.withOpacity(0.3)),
                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.cyan, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: AppColors.geistMedium(13).copyWith(color: AppColors.textMuted)),
            ),
            GestureDetector(
              onTap: isLoading ? null : () async {
                final email = resetEmailController.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  AppToast.show(context, 'Please enter a valid email.', type: ToastType.error);
                  return;
                }
                setDialogState(() => isLoading = true);
                try {
                  final response = await DioClient().dio.post(
                    ApiEndpoints.forgotPassword,
                    data: {'email': email},
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    AppToast.show(context, response.data['message'] ?? 'Reset link sent!', type: ToastType.success);
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    AppToast.show(context, 'Something went wrong. Please try again.', type: ToastType.error);
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: isLoading ? AppColors.surface : AppColors.cyan,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isLoading
                      ? []
                      : [
                          BoxShadow(
                            color: AppColors.cyan.withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: isLoading
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF040A12)))
                    : Text('Send Reset Link', style: AppColors.soraBold(12).copyWith(color: const Color(0xFF040A12))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          SpaceBackground(driftController: _driftController, twinkleController: _twinkleController, child: const SizedBox.expand()),

          // Ambient Cyan Glow behind hero emblem
          Positioned(
            top: 50,
            left: size.width * 0.5 - 130,
            child: IgnorePointer(
              child: Container(
                width: 260,
                height: 260,
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

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Central Hero Emblem
                          Center(
                            child: Image.asset(
                              'assets/images/LiveJoeDreamzLogo.png',
                              width: 96,
                              height: 96,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Image.asset(
                                'assets/images/DreamCommunityLogo.webp',
                                width: 100,
                                height: 100,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),

                          // Headline with Cyan Accent
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: AppColors.soraBold(26).copyWith(color: Colors.white),
                              children: [
                                const TextSpan(text: 'Welcome '),
                                TextSpan(
                                  text: 'Back',
                                  style: AppColors.soraBold(26).copyWith(
                                    color: AppColors.cyan,
                                    shadows: [
                                      Shadow(
                                        color: AppColors.cyan.withOpacity(0.5),
                                        blurRadius: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Center(
                            child: Text(
                              'Sign in to access your exclusive D.R.E.A.M content',
                              style: AppColors.geistMedium(13).copyWith(
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // ==================== MASTER GLASS BENTO CARD ====================
                          Container(
                            padding: const EdgeInsets.all(26),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF0D172A),
                                  Color(0xFF070D18),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppColors.cyan.withOpacity(0.22),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.cyan.withOpacity(0.08),
                                  blurRadius: 30,
                                  offset: const Offset(0, 8),
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Email Input
                                _buildLabel('EMAIL'),
                                const SizedBox(height: 10),
                                _buildInput(
                                  controller: _emailController,
                                  hint: 'you@email.com',
                                  icon: Icons.email_outlined,
                                  error: _emailError,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 18),

                                // Password Input
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildLabel('PASSWORD'),
                                    GestureDetector(
                                      onTap: _showForgotPasswordDialog,
                                      behavior: HitTestBehavior.opaque,
                                      child: Text(
                                        'Forgot Password?',
                                        style: AppColors.geistMedium(11).copyWith(
                                          color: AppColors.cyan,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _buildInput(
                                  controller: _passwordController,
                                  hint: '••••••••••••',
                                  icon: Icons.lock_outline_rounded,
                                  error: _passwordError,
                                  obscure: true,
                                ),
                                const SizedBox(height: 14),

                                // Remember Me
                                GestureDetector(
                                  onTap: () => setState(() => _rememberMe = !_rememberMe),
                                  behavior: HitTestBehavior.opaque,
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: Checkbox(
                                          value: _rememberMe,
                                          onChanged: (v) => setState(() => _rememberMe = v ?? false),
                                          activeColor: AppColors.cyan,
                                          checkColor: const Color(0xFF040A12),
                                          side: BorderSide(color: Colors.white.withOpacity(0.25)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Remember me',
                                        style: AppColors.geistMedium(12).copyWith(
                                          color: Colors.white.withOpacity(0.65),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // ==================== DOMINANT CTA (HICK'S LAW) ====================
                                GestureDetector(
                                  onTap: _isLoading ? null : _login,
                                  behavior: HitTestBehavior.opaque,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: double.infinity,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: _isLoading ? AppColors.cyan.withOpacity(0.5) : AppColors.cyan,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: _isLoading
                                          ? []
                                          : [
                                              BoxShadow(
                                                color: AppColors.cyan.withOpacity(0.4),
                                                blurRadius: 18,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                    ),
                                    child: Center(
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.2,
                                                color: Color(0xFF040A12),
                                              ),
                                            )
                                          : Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'LOGIN',
                                                  style: AppColors.soraBold(13).copyWith(
                                                    color: const Color(0xFF040A12),
                                                    letterSpacing: 1.8,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                const Icon(
                                                  Icons.arrow_forward_rounded,
                                                  size: 16,
                                                  color: Color(0xFF040A12),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Secondary Action (Sign Up)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Don't have an account? ",
                                      style: AppColors.geistMedium(13).copyWith(
                                        color: Colors.white.withOpacity(0.5),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                                      ),
                                      behavior: HitTestBehavior.opaque,
                                      child: Text(
                                        'Sign Up',
                                        style: AppColors.soraBold(13).copyWith(
                                          color: AppColors.cyan,
                                          decoration: TextDecoration.underline,
                                          decorationColor: AppColors.cyan,
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
                  ),
                ],
              ),
            );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: AppColors.geistBold(10).copyWith(
        color: AppColors.cyan,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? error,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF060B14).withOpacity(0.7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: error != null
                  ? const Color(0xFFFF5252).withOpacity(0.7)
                  : Colors.white.withOpacity(0.12),
              width: 1.0,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscure && _obscurePassword,
            style: AppColors.geistMedium(14).copyWith(color: Colors.white),
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            onChanged: (_) {
              if (error != null) {
                setState(() {
                  if (controller == _emailController) {
                    _emailError = null;
                  } else {
                    _passwordError = null;
                  }
                });
              }
            },
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppColors.geistMedium(14).copyWith(
                color: Colors.white.withOpacity(0.25),
              ),
              prefixIcon: Icon(
                icon,
                color: error != null
                    ? const Color(0xFFFF5252)
                    : AppColors.cyan.withOpacity(0.85),
                size: 20,
              ),
              suffixIcon: obscure
                  ? IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.white.withOpacity(0.4),
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 14, top: 6),
            child: Text(
              error,
              style: AppColors.geistMedium(11).copyWith(
                color: const Color(0xFFFF5252),
              ),
            ),
          ),
      ],
    );
  }
}

