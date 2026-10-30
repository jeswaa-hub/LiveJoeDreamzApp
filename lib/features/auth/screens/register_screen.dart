import 'package:flutter/material.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/features/auth/services/auth_service.dart';
import 'package:dream_community_app/core/widgets/dream_toast.dart';
import 'package:dream_community_app/shared/widgets/space_background.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isCheckingEmail = false;
  String? _emailExistsError;

  AnimationController? _driftController;
  AnimationController? _twinkleController;

  static const Color bgDark = Color(0xFF020205);

  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _driftController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _twinkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _emailFocusNode.addListener(() {
      if (!_emailFocusNode.hasFocus) {
        _validateEmailAvailability();
      }
      setState(() {});
    });

    _passwordFocusNode.addListener(() => setState(() {}));
    _confirmPasswordFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _driftController?.dispose();
    _twinkleController?.dispose();
    super.dispose();
  }

  Future<void> _validateEmailAvailability() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      if (mounted) setState(() => _emailExistsError = null);
      return;
    }

    if (mounted) {
      setState(() {
        _isCheckingEmail = true;
        _emailExistsError = null;
      });
    }

    try {
      final exists = await _authService.checkEmailExists(email);
      if (mounted) {
        setState(() {
          _isCheckingEmail = false;
          if (exists) {
            _emailExistsError = 'This email is already registered';
          } else {
            _emailExistsError = null;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isCheckingEmail = false);
      }
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_emailExistsError != null) {
      DreamToast.error(context, _emailExistsError!);
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      DreamToast.error(context, 'Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final registerTask = _authService.register(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
      );

      final result = await registerTask;

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result.isSuccess) {
        DreamToast.success(context, 'Free account activated successfully!');
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      } else {
        DreamToast.error(context, result.error ?? 'Registration failed');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        DreamToast.error(context, 'An unexpected error occurred');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          // Dynamic space background
          SpaceBackground(
            driftController: _driftController,
            twinkleController: _twinkleController,
            child: const SizedBox.expand(),
          ),

          // Ambient Cyan Radial Glow
          Positioned(
            top: 40,
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Bar Back Button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D172A).withOpacity(0.8),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.12),
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Central Hero Emblem
                    Center(
                      child: Image.asset(
                        'assets/images/LiveJoeDreamzLogo.png',
                        width: 80,
                        height: 80,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Image.asset(
                          'assets/images/DreamCommunityLogo.webp',
                          width: 80,
                          height: 80,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Headline
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: AppColors.soraBold(24).copyWith(color: Colors.white),
                        children: [
                          const TextSpan(text: 'Create '),
                          TextSpan(
                            text: 'Account',
                            style: AppColors.soraBold(24).copyWith(
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
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        'Join the official D.R.E.A.M. community today',
                        style: AppColors.geistMedium(13).copyWith(
                          color: Colors.white.withOpacity(0.55),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Master Glass Bento Form Card
                    Container(
                      padding: const EdgeInsets.all(22),
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
                          // Full Name Input
                          Text(
                            'FULL NAME',
                            style: AppColors.geistBold(10).copyWith(
                              color: AppColors.cyan,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameController,
                            style: AppColors.geistMedium(14).copyWith(color: Colors.white),
                            decoration: _buildInputDecoration(
                              'Enter your full name',
                              Icons.person_outline_rounded,
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Please enter your name' : null,
                          ),
                          const SizedBox(height: 18),

                          // Email Address Input
                          Text(
                            'EMAIL ADDRESS',
                            style: AppColors.geistBold(10).copyWith(
                              color: AppColors.cyan,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            focusNode: _emailFocusNode,
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (_) {
                              if (_emailExistsError != null) {
                                setState(() => _emailExistsError = null);
                              }
                            },
                            style: AppColors.geistMedium(14).copyWith(color: Colors.white),
                            decoration: _buildInputDecoration(
                              'name@example.com',
                              Icons.mail_outline_rounded,
                              suffixIcon: _isCheckingEmail
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Center(
                                        child: SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.cyan,
                                          ),
                                        ),
                                      ),
                                    )
                                  : (_emailExistsError != null
                                      ? const Icon(Icons.error_outline_rounded, color: AppColors.pink, size: 20)
                                      : (!_emailFocusNode.hasFocus &&
                                              _emailController.text.isNotEmpty &&
                                              _emailController.text.contains('@') &&
                                              _emailController.text.contains('.')
                                          ? const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20)
                                          : null)),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Please enter your email';
                              if (!v.contains('@') || !v.contains('.')) return 'Please enter a valid email address';
                              if (_emailExistsError != null) return _emailExistsError;
                              return null;
                            },
                          ),
                          if (_isCheckingEmail)
                            _buildRequirementItem(
                              isSatisfied: false,
                              label: 'Checking email availability...',
                            )
                          else if (_emailExistsError != null)
                            _buildRequirementItem(
                              isSatisfied: false,
                              isError: true,
                              label: _emailExistsError!,
                            )
                          else if (!_emailFocusNode.hasFocus &&
                              _emailController.text.isNotEmpty &&
                              _emailController.text.contains('@') &&
                              _emailController.text.contains('.'))
                            _buildRequirementItem(
                              isSatisfied: true,
                              label: 'Email is available',
                            ),
                          const SizedBox(height: 18),

                          // Password Input
                          Text(
                            'PASSWORD',
                            style: AppColors.geistBold(10).copyWith(
                              color: AppColors.cyan,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            onChanged: (_) => setState(() {}),
                            obscureText: _obscurePassword,
                            style: AppColors.geistMedium(14).copyWith(color: Colors.white),
                            decoration: _buildInputDecoration(
                              'At least 6 characters',
                              Icons.lock_outline_rounded,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: Colors.white.withOpacity(0.4),
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (v) => v == null || v.length < 6 ? 'Password must be at least 6 characters' : null,
                          ),
                          if (_passwordFocusNode.hasFocus || _passwordController.text.isNotEmpty)
                            _buildRequirementItem(
                              isSatisfied: _passwordController.text.length >= 6,
                              label: 'Minimum 6 characters',
                            ),
                          const SizedBox(height: 18),

                          // Confirm Password Input
                          Text(
                            'CONFIRM PASSWORD',
                            style: AppColors.geistBold(10).copyWith(
                              color: AppColors.cyan,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _confirmPasswordController,
                            focusNode: _confirmPasswordFocusNode,
                            onChanged: (_) => setState(() {}),
                            obscureText: _obscureConfirmPassword,
                            style: AppColors.geistMedium(14).copyWith(color: Colors.white),
                            decoration: _buildInputDecoration(
                              'Re-enter your password',
                              Icons.lock_reset_rounded,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: Colors.white.withOpacity(0.4),
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                              ),
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'Please confirm your password' : null,
                          ),
                          if (_confirmPasswordFocusNode.hasFocus || _confirmPasswordController.text.isNotEmpty)
                            Builder(
                              builder: (context) {
                                final pass = _passwordController.text;
                                final confirm = _confirmPasswordController.text;
                                final hasConfirmText = confirm.isNotEmpty;
                                final isMatch = hasConfirmText && pass.isNotEmpty && confirm == pass;
                                final isMismatch = hasConfirmText && confirm != pass;

                                return _buildRequirementItem(
                                  isSatisfied: isMatch,
                                  isError: isMismatch,
                                  label: isMatch
                                      ? 'Passwords match'
                                      : (isMismatch ? 'Passwords do not match' : 'Must match password'),
                                );
                              },
                            ),
                          const SizedBox(height: 24),

                          // Create Account Button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleRegister,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.cyan,
                                foregroundColor: const Color(0xFF040A12),
                                elevation: 4,
                                shadowColor: AppColors.cyan.withOpacity(0.45),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Color(0xFF040A12),
                                      ),
                                    )
                                  : Text(
                                      'CREATE FREE ACCOUNT',
                                      style: AppColors.soraBold(13).copyWith(
                                        color: const Color(0xFF040A12),
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Already have an account? Login Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: AppColors.geistMedium(13).copyWith(
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Text(
                            'Log In',
                            style: AppColors.soraBold(13).copyWith(
                              color: AppColors.cyan,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.cyan,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementItem({
    required bool isSatisfied,
    required String label,
    bool isError = false,
  }) {
    final color = isSatisfied
        ? AppColors.success
        : (isError ? const Color(0xFFF43F5E) : Colors.white.withOpacity(0.35));
    final icon = isSatisfied
        ? Icons.check_circle_rounded
        : (isError ? Icons.cancel_rounded : Icons.radio_button_unchecked_rounded);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(top: 8, left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppColors.geistMedium(11).copyWith(
              color: isSatisfied
                  ? const Color(0xFF4ADE80)
                  : (isError ? const Color(0xFFFB7185) : Colors.white.withOpacity(0.5)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(
    String hint,
    IconData prefixIcon, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppColors.geistMedium(13).copyWith(color: Colors.white.withOpacity(0.3)),
      prefixIcon: Icon(prefixIcon, color: AppColors.cyan, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFF060B14).withOpacity(0.7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.cyan, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.pink, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.pink, width: 1.5),
      ),
    );
  }
}

