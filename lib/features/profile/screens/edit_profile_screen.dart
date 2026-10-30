import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/core/models/user_model.dart';
import 'package:dream_community_app/core/widgets/dream_toast.dart';
import 'package:dream_community_app/features/auth/services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;

  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _locationController;
  late final TextEditingController _bioController;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;
  bool _isSavingPassword = false;
  bool _isUploadingAvatar = false;
  Uint8List? _pickedAvatarBytes;
  String _pickedAvatarName = 'avatar.jpg';

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nameController = TextEditingController(text: u.name);
    _usernameController = TextEditingController(text: u.username ?? '');
    _emailController = TextEditingController(text: u.email);
    _phoneController = TextEditingController(text: u.phone ?? '');
    _locationController = TextEditingController(text: u.location ?? '');
    _bioController = TextEditingController(text: u.bio ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _hasProfileChanges() {
    final u = widget.user;
    return _nameController.text != u.name ||
        _usernameController.text != (u.username ?? '') ||
        _emailController.text != u.email ||
        _phoneController.text != (u.phone ?? '') ||
        _locationController.text != (u.location ?? '') ||
        _bioController.text != (u.bio ?? '');
  }

  Future<void> _save() async {
    if (!_hasProfileChanges()) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isSaving = true);

    final data = <String, dynamic>{};
    final u = widget.user;
    if (_nameController.text != u.name) data['name'] = _nameController.text;
    if (_usernameController.text != (u.username ?? '')) data['username'] = _usernameController.text;
    if (_emailController.text != u.email) data['email'] = _emailController.text;
    if (_phoneController.text != (u.phone ?? '')) data['phone'] = _phoneController.text;
    if (_locationController.text != (u.location ?? '')) data['location'] = _locationController.text;
    if (_bioController.text != (u.bio ?? '')) data['bio'] = _bioController.text;

    final updated = await AuthService().updateProfile(data);
    if (!mounted) return;

    setState(() => _isSaving = false);

    if (updated != null) {
      DreamToast.success(context, 'Profile updated!');
      Navigator.pop(context, true);
    } else {
      DreamToast.error(context, 'Failed to update profile');
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512, imageQuality: 80);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _isUploadingAvatar = true;
      _pickedAvatarBytes = bytes;
      _pickedAvatarName = picked.name;
    });

    final updated = await AuthService().uploadAvatarBytes(bytes, picked.name);
    if (!mounted) return;

    setState(() => _isUploadingAvatar = false);

    if (updated != null) {
      DreamToast.success(context, 'Avatar updated!');
      Navigator.pop(context, true);
    } else {
      DreamToast.error(context, 'Failed to upload avatar');
      setState(() { _pickedAvatarBytes = null; });
    }
  }

  Future<void> _savePassword() async {
    final current = _currentPasswordController.text.trim();
    final newPass = _newPasswordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      DreamToast.error(context, 'All password fields are required');
      return;
    }
    if (newPass != confirm) {
      DreamToast.error(context, 'New passwords do not match');
      return;
    }
    if (newPass.length < 8) {
      DreamToast.error(context, 'Password must be at least 8 characters');
      return;
    }

    setState(() => _isSavingPassword = true);

    final error = await AuthService().changePassword(
      currentPassword: current,
      newPassword: newPass,
    );
    if (!mounted) return;

    setState(() => _isSavingPassword = false);

    if (error == null) {
      DreamToast.success(context, 'Password changed!');
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } else {
      DreamToast.error(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final initial = u.initials;
    final hasAvatar = _pickedAvatarBytes != null || (u.resolvedAvatarUrl != null && u.resolvedAvatarUrl!.isNotEmpty);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Edit Profile', style: AppColors.soraBold(16)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyan))
                : Text('Save', style: AppColors.geistBold(13).copyWith(color: AppColors.cyan)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Avatar
          Center(
            child: Stack(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x2600DBE9), Color(0x1AFFABF0)]),
                  ),
                  child: Center(
                    child: _pickedAvatarBytes != null
                        ? ClipOval(
                            child: Image.memory(
                              _pickedAvatarBytes!,
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          )
                        : hasAvatar
                            ? ClipOval(
                                child: Image.network(
                                  u.resolvedAvatarUrl!,
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Text(initial, style: AppColors.soraBlack(32)),
                                ),
                              )
                            : Container(
                                width: 72,
                                height: 72,
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.background),
                                child: Center(child: Text(initial, style: AppColors.soraBlack(32))),
                              ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: GestureDetector(
                    onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1A1F2E),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: _isUploadingAvatar
                          ? const SizedBox(width: 14, height: 14, child: Padding(padding: EdgeInsets.all(3), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                          : const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Profile fields
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _profileField('Full name', _nameController),
                _divider(),
                _profileField('Username', _usernameController),
                _divider(),
                _profileField('Email', _emailController, keyboardType: TextInputType.emailAddress),
                _divider(),
                _profileField('Phone number', _phoneController, keyboardType: TextInputType.phone),
                _divider(),
                _profileField('Location', _locationController),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Bio
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bio', style: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 8),
                TextField(
                  controller: _bioController,
                  maxLines: 3,
                  style: AppColors.geistMedium(14).copyWith(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Tell us about yourself...',
                    hintStyle: AppColors.geistMedium(14).copyWith(color: AppColors.textMuted.withOpacity(0.5)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Password
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Password', style: AppColors.geistMedium(12).copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 16),
                _passwordField('Current password', _currentPasswordController, _obscureCurrent, () {
                  setState(() => _obscureCurrent = !_obscureCurrent);
                }),
                const SizedBox(height: 12),
                _passwordField('New password', _newPasswordController, _obscureNew, () {
                  setState(() => _obscureNew = !_obscureNew);
                }),
                const SizedBox(height: 12),
                _passwordField('Confirm password', _confirmPasswordController, _obscureConfirm, () {
                  setState(() => _obscureConfirm = !_obscureConfirm);
                }),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _isSavingPassword ? null : _savePassword,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Center(
                      child: _isSavingPassword
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyan))
                          : Text('Change Password', style: AppColors.geistBold(13).copyWith(color: AppColors.textPrimary)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Save button
          GestureDetector(
            onTap: _isSaving ? null : _save,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: _isSaving ? AppColors.surface : const Color(0xFF1A1F2E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Center(
                child: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyan))
                    : Text('Save Changes', style: AppColors.soraBold(14).copyWith(color: Colors.white)),
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _profileField(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text, bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: AppColors.geistMedium(13).copyWith(color: AppColors.textMuted)),
          ),
          Expanded(
            flex: 3,
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              enabled: enabled,
              textAlign: TextAlign.right,
              style: AppColors.geistMedium(14).copyWith(color: enabled ? AppColors.textPrimary : AppColors.textMuted),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(height: 1, color: Colors.white.withOpacity(0.05));
  }

  Widget _passwordField(String label, TextEditingController controller, bool obscure, VoidCallback onToggle) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: AppColors.geistMedium(14).copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: AppColors.geistMedium(13).copyWith(color: AppColors.textMuted.withOpacity(0.5)),
          prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMuted, size: 18),
          suffixIcon: IconButton(
            icon: Icon(
              obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppColors.textMuted,
              size: 18,
            ),
            onPressed: onToggle,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
