import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/core/widgets/dream_toast.dart';
import 'package:dream_community_app/features/newsletter/services/newsletter_service.dart';

class NewsletterScreen extends StatefulWidget {
  const NewsletterScreen({super.key});

  @override
  State<NewsletterScreen> createState() => _NewsletterScreenState();
}

class _NewsletterScreenState extends State<NewsletterScreen> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user_data');
    if (userData == null || !mounted) return;

    try {
      final user = jsonDecode(userData) as Map<String, dynamic>;
      final email = user['email'] as String?;
      final phone = user['phone'] as String?;

      if (email != null && email.isNotEmpty) {
        _emailController.text = email;
      }
      if (phone != null && phone.isNotEmpty) {
        _phoneController.text = phone;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _subscribe() async {
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      DreamToast.error(context, 'Please enter a valid email');
      return;
    }

    if (phone.isEmpty) {
      DreamToast.error(context, 'Phone number is required');
      return;
    }

    setState(() => _isSubmitting = true);

    final message = await NewsletterService().subscribe(
      email: email,
      phone: phone,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (message != null && (message.contains('success') || message.contains('Welcome') || message.contains('Already'))) {
      DreamToast.success(context, message);
      Navigator.pop(context);
    } else {
      DreamToast.error(context, message ?? 'Subscription failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const SizedBox.shrink(),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          Text('Stay in the Loop', textAlign: TextAlign.center, style: AppColors.soraBold(24)),
          const SizedBox(height: 8),
          Text(
            'Get the latest updates on events, new content, and community news delivered to your inbox.',
            style: AppColors.hankenMedium(14).copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 32),

          // Email field
          Text('EMAIL', style: AppColors.geistBold(10).copyWith(color: AppColors.textMuted, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: AppColors.geistMedium(14).copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'you@email.com',
              hintStyle: AppColors.geistMedium(14).copyWith(color: AppColors.textMuted.withOpacity(0.5)),
              prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textMuted, size: 18),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.surfaceBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.surfaceBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.cyan),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Phone field
          Text('PHONE', style: AppColors.geistBold(10).copyWith(color: AppColors.textMuted, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: AppColors.geistMedium(14).copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: '+63 9XX XXX XXXX',
              hintStyle: AppColors.geistMedium(14).copyWith(color: AppColors.textMuted.withOpacity(0.5)),
              prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.textMuted, size: 18),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.surfaceBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.surfaceBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.cyan),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Subscribe button — brutalist style like website login
          GestureDetector(
            onTap: _isSubmitting ? null : _subscribe,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1F2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.white, offset: Offset(3, 3)),
                ],
              ),
              child: Center(
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        'SUBSCRIBE',
                        style: AppColors.geistBold(13).copyWith(
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'We respect your privacy. Unsubscribe anytime.',
            textAlign: TextAlign.center,
            style: AppColors.geistMedium(11).copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
