import 'package:flutter/material.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/core/widgets/dream_toast.dart';
import 'package:dream_community_app/features/auth/services/auth_service.dart';

class ChangePasswordModal extends StatefulWidget {
  const ChangePasswordModal({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ChangePasswordModal(),
    );
  }

  @override
  State<ChangePasswordModal> createState() => _ChangePasswordModalState();
}

class _ChangePasswordModalState extends State<ChangePasswordModal> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isLoading) return;
    setState(() => _errorMessage = null);

    final current = _currentPasswordController.text.trim();
    final newPass = _newPasswordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (current.isEmpty) {
      setState(() => _errorMessage = 'Please enter your current password');
      return;
    }
    if (newPass.isEmpty) {
      setState(() => _errorMessage = 'Please enter your new password');
      return;
    }
    if (newPass.length < 6) {
      setState(() => _errorMessage = 'New password must be at least 6 characters');
      return;
    }
    if (newPass != confirm) {
      setState(() => _errorMessage = 'New password and confirmation do not match');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final error = await AuthService().changePassword(
        currentPassword: current,
        newPassword: newPass,
      );

      if (!mounted) return;

      if (error == null) {
        Navigator.pop(context, true);
        DreamToast.success(context, 'Password changed successfully!');
      } else {
        setState(() {
          _errorMessage = error;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to change password. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottomInset),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1527),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: const Color(0x28FFFFFF)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle pill
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Header with icon
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.cyan.withOpacity(0.12),
                        border: Border.all(color: AppColors.cyan.withOpacity(0.35)),
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: AppColors.cyan,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Change Password', style: AppColors.soraBold(18)),
                          const SizedBox(height: 2),
                          Text(
                            'Update your account login credentials',
                            style: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 18,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Error message banner if any
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withOpacity(0.35)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: AppColors.geistMedium(12).copyWith(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 1. Current Password
                _buildFieldLabel('Current Password'),
                const SizedBox(height: 6),
                _buildPasswordField(
                  controller: _currentPasswordController,
                  hintText: 'Enter current password',
                  obscureText: _obscureCurrent,
                  onToggleObscure: () => setState(() => _obscureCurrent = !_obscureCurrent),
                ),

                const SizedBox(height: 16),

                // 2. New Password
                _buildFieldLabel('New Password (min. 6 characters)'),
                const SizedBox(height: 6),
                _buildPasswordField(
                  controller: _newPasswordController,
                  hintText: 'Enter new password',
                  obscureText: _obscureNew,
                  onToggleObscure: () => setState(() => _obscureNew = !_obscureNew),
                ),

                const SizedBox(height: 16),

                // 3. Confirm Password
                _buildFieldLabel('Confirm New Password'),
                const SizedBox(height: 6),
                _buildPasswordField(
                  controller: _confirmPasswordController,
                  hintText: 'Re-type new password',
                  obscureText: _obscureConfirm,
                  onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),

                const SizedBox(height: 26),

                // Dominant CTA Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cyan,
                      disabledBackgroundColor: AppColors.cyan.withOpacity(0.4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      shadowColor: AppColors.cyan.withOpacity(0.5),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Color(0xFF051424),
                              strokeWidth: 2.2,
                            ),
                          )
                        : Text(
                            'Update Password',
                            style: AppColors.soraBold(14).copyWith(
                              color: const Color(0xFF051424),
                              letterSpacing: 0.4,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: AppColors.geistBold(11).copyWith(
        color: AppColors.textMuted,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool obscureText,
    required VoidCallback onToggleObscure,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101A2F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        style: AppColors.geistMedium(14).copyWith(color: Colors.white),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppColors.geistMedium(13).copyWith(color: Colors.white.withOpacity(0.25)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textMuted, size: 18),
          suffixIcon: IconButton(
            icon: Icon(
              obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppColors.textMuted,
              size: 18,
            ),
            onPressed: onToggleObscure,
            splashRadius: 18,
          ),
        ),
      ),
    );
  }
}
