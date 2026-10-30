import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/shared/widgets/app_toast.dart';
import 'package:dream_community_app/shared/widgets/loading_overlay.dart';
import 'package:dream_community_app/features/podcast/services/podcast_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// US Phone number auto-formatter: (XXX) XXX-XXXX
class UsPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 10 ? digits.substring(0, 10) : digits;

    final buffer = StringBuffer();
    for (int i = 0; i < limited.length; i++) {
      if (i == 0) buffer.write('(');
      if (i == 3) buffer.write(') ');
      if (i == 6) buffer.write('-');
      buffer.write(limited[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class PodcastApplyScreen extends StatefulWidget {
  const PodcastApplyScreen({super.key});

  @override
  State<PodcastApplyScreen> createState() => _PodcastApplyScreenState();
}

class _PodcastApplyScreenState extends State<PodcastApplyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _instagramController = TextEditingController();
  final _tiktokController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _instagramController.dispose();
    _tiktokController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final socialLinks = <String, String>{};
    if (_instagramController.text.trim().isNotEmpty) {
      socialLinks['instagram'] = _instagramController.text.trim();
    }
    if (_tiktokController.text.trim().isNotEmpty) {
      socialLinks['tiktok'] = _tiktokController.text.trim();
    }

    // Pass US formatted number: +1 (XXX) XXX-XXXX
    final rawPhone = _phoneController.text.trim();
    final phoneToSend = rawPhone.startsWith('+1') ? rawPhone : '+1 $rawPhone';

    final result = await PodcastService().submitApplication(
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: phoneToSend,
      bio: _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : null,
      socialLinks: socialLinks.isNotEmpty ? socialLinks : null,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (result['success'] == true) {
        AppToast.show(context, result['message'] ?? 'Application submitted successfully!', type: ToastType.success);
        Navigator.pop(context);
      } else {
        AppToast.show(context, result['message'] ?? 'Submission failed. Please try again.', type: ToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            CustomScrollView(
              slivers: [
                // 1. App Bar with Obsidian Glass Back Button
                SliverToBoxAdapter(
                  child: _buildHeaderBar(),
                ),

                // 2. Main Form Content
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                  sliver: SliverToBoxAdapter(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Podcast Emblem & Hero Title
                          _buildHeroSection(),
                          const SizedBox(height: 20),

                          // Featured Episode Showcase Card
                          _buildVideoShowcaseCard(),
                          const SizedBox(height: 28),

                          // Bento Card 1: Contact Information
                          _buildSectionContainer(
                            icon: Icons.person_rounded,
                            title: 'CONTACT INFORMATION',
                            subtitle: 'How our production team will reach you',
                            children: [
                              _buildField(
                                label: 'FULL NAME *',
                                icon: Icons.badge_outlined,
                                child: TextFormField(
                                  controller: _nameController,
                                  style: AppColors.geistMedium(14).copyWith(color: Colors.white),
                                  decoration: _inputDecoration('Joe Dreamz', icon: Icons.person_outline_rounded),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Full name is required' : null,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildField(
                                label: 'EMAIL ADDRESS *',
                                icon: Icons.email_outlined,
                                child: TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: AppColors.geistMedium(14).copyWith(color: Colors.white),
                                  decoration: _inputDecoration('joe@dreamz.com', icon: Icons.mail_outline_rounded),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Email is required';
                                    if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                                      return 'Please enter a valid email address';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildField(
                                label: 'US PHONE NUMBER *',
                                icon: Icons.phone_outlined,
                                child: TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    UsPhoneInputFormatter(),
                                  ],
                                  style: AppColors.geistMedium(14).copyWith(color: Colors.white),
                                  decoration: _inputDecoration(
                                    '(555) 234-5678',
                                    isUsPhone: true,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Phone number is required';
                                    final digits = v.replaceAll(RegExp(r'\D'), '');
                                    if (digits.length != 10) return 'Enter a valid 10-digit US phone number';
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Bento Card 2: Your Story & Bio
                          _buildSectionContainer(
                            icon: Icons.chat_bubble_outline_rounded,
                            title: 'YOUR STORY & TOPIC',
                            subtitle: 'What inspires you and what would you love to discuss?',
                            children: [
                              _buildField(
                                label: 'ABOUT YOU *',
                                icon: Icons.edit_note_rounded,
                                child: TextFormField(
                                  controller: _bioController,
                                  maxLines: 4,
                                  maxLength: 1000,
                                  style: AppColors.geistMedium(13).copyWith(color: Colors.white, height: 1.4),
                                  decoration: _inputDecoration(
                                    'Tell us about yourself, your journey, and why you want to be a guest...',
                                  ),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Please share a brief story about yourself' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Bento Card 3: Social Media (Optional)
                          _buildSectionContainer(
                            icon: Icons.share_rounded,
                            title: 'SOCIAL MEDIA',
                            subtitle: 'Optional profiles to help us feature your work',
                            children: [
                              _buildField(
                                label: 'INSTAGRAM',
                                icon: Icons.camera_alt_outlined,
                                child: TextFormField(
                                  controller: _instagramController,
                                  style: AppColors.geistMedium(14).copyWith(color: Colors.white),
                                  decoration: _inputDecoration('@yourusername', icon: Icons.camera_alt_outlined),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildField(
                                label: 'TIKTOK',
                                icon: Icons.music_note_outlined,
                                child: TextFormField(
                                  controller: _tiktokController,
                                  style: AppColors.geistMedium(14).copyWith(color: Colors.white),
                                  decoration: _inputDecoration('@yourusername', icon: Icons.music_note_outlined),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // Submit Button
                          _buildSubmitButton(),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (_isSubmitting)
              const LoadingOverlay(
                isVisible: true,
                message: 'Submitting your application...',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 19),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Guest Application',
                  style: AppColors.soraBold(18).copyWith(color: Colors.white),
                ),
                Text(
                  'Be featured on the D.R.E.A.M. Podcast',
                  style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted.withOpacity(0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Image.asset(
          'assets/images/dreamPodcast.webp',
          height: 84,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildVideoShowcaseCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A1424).withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.09)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          GestureDetector(
            onTap: () async {
              final url = Uri.parse('https://www.youtube.com/watch?v=MHpmw-HQbhE');
              if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
            },
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      'https://img.youtube.com/vi/MHpmw-HQbhE/hqdefault.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0A1424)),
                    ),
                    // Ambient gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.15),
                            Colors.black.withOpacity(0.55),
                          ],
                        ),
                      ),
                    ),
                    // Center Glowing Play Button
                    Center(
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFF0000).withOpacity(0.92),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF0000).withOpacity(0.45),
                              blurRadius: 18,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                      ),
                    ),
                    // Top-Left Badge
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withOpacity(0.15)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.videocam_rounded, color: Colors.redAccent, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              'FEATURED EPISODE',
                              style: AppColors.geistBold(8).copyWith(color: Colors.white, letterSpacing: 0.8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Action Link Chip
          GestureDetector(
            onTap: () async {
              final url = Uri.parse('https://www.youtube.com/@livejoedreamz');
              if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_circle_fill_rounded, color: Color(0xFFFF0000), size: 15),
                  const SizedBox(width: 6),
                  Text(
                    'Visit Official YouTube Channel ↗',
                    style: AppColors.geistBold(12).copyWith(color: AppColors.cyan),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContainer({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1424).withOpacity(0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 15, color: AppColors.cyan),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppColors.geistBold(11).copyWith(
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppColors.hankenMedium(10).copyWith(
                        color: AppColors.textMuted.withOpacity(0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.white.withOpacity(0.06), height: 1),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildField({required String label, required Widget child, IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppColors.geistBold(10).copyWith(
            color: AppColors.textMuted.withOpacity(0.9),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _isSubmitting ? null : _submit,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: _isSubmitting
              ? LinearGradient(
                  colors: [
                    AppColors.cyan.withOpacity(0.4),
                    AppColors.cyan.withOpacity(0.4),
                  ],
                )
              : const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFF00B4D8)],
                ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.cyan.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF050C16),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'SUBMIT APPLICATION',
                      style: AppColors.soraBold(13).copyWith(
                        color: const Color(0xFF050C16),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, color: Color(0xFF050C16), size: 16),
                  ],
                ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String hint, {
    IconData? icon,
    bool isUsPhone = false,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppColors.geistMedium(13).copyWith(color: AppColors.textMuted.withOpacity(0.55)),
      filled: true,
      fillColor: const Color(0xFF070F1C).withOpacity(0.85),
      prefixIcon: isUsPhone
          ? Container(
              margin: const EdgeInsets.only(left: 12, right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🇺🇸', style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    '+1',
                    style: AppColors.geistBold(13).copyWith(color: AppColors.cyan),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 1,
                    height: 18,
                    color: Colors.white.withOpacity(0.12),
                  ),
                ],
              ),
            )
          : (icon != null
              ? Icon(icon, color: AppColors.textMuted.withOpacity(0.7), size: 18)
              : null),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.cyan.withOpacity(0.55), width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.error.withOpacity(0.55)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.error),
      ),
      counterStyle: AppColors.geistMedium(10).copyWith(color: AppColors.textMuted.withOpacity(0.6)),
    );
  }
}
