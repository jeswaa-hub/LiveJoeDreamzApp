import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/features/auth/services/auth_service.dart';
import 'package:dream_community_app/features/home/screens/community_hub_screen.dart';
import 'package:dream_community_app/core/widgets/dream_toast.dart';
import 'package:dream_community_app/shared/widgets/space_background.dart';

import 'package:dream_community_app/core/services/pending_approval_sync_service.dart';

class LoggedInPaymentSuccessScreen extends StatefulWidget {
  final int? purchaseId;
  final String accessCode;
  final String userName;
  final String planName;
  final String billingCycle;
  final double amount;
  final String paymentMethod;
  final bool isManualPending;

  const LoggedInPaymentSuccessScreen({
    super.key,
    this.purchaseId,
    required this.accessCode,
    required this.userName,
    required this.planName,
    required this.billingCycle,
    required this.amount,
    required this.paymentMethod,
    this.isManualPending = false,
  });

  @override
  State<LoggedInPaymentSuccessScreen> createState() => _LoggedInPaymentSuccessScreenState();
}

class _LoggedInPaymentSuccessScreenState extends State<LoggedInPaymentSuccessScreen>
    with TickerProviderStateMixin {
  late AnimationController _driftController;
  late AnimationController _twinkleController;
  late AnimationController _scaleController;
  bool _isApproved = false;

  bool get isPending =>
      !_isApproved &&
      (widget.isManualPending ||
          widget.paymentMethod.toLowerCase().contains('venmo') ||
          widget.paymentMethod.toLowerCase().contains('cash') ||
          widget.accessCode.toUpperCase().contains('PENDING'));

  @override
  void initState() {
    super.initState();
    _driftController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _twinkleController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _scaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scaleController.forward();
    AuthService().getCurrentUser(); // Refresh user profile and state from server

    // Start fast active polling (every 2.5s) if manual payment is pending
    if (widget.purchaseId != null && isPending) {
      final isMerch = widget.planName.toLowerCase().contains('merch');
      final isJournal = widget.planName.toLowerCase().contains('journal');
      final type = isMerch ? 'merch' : (isJournal ? 'journal' : 'community');

      PendingApprovalSyncService.instance.startPolling(
        purchaseId: widget.purchaseId!,
        type: type,
        onApproved: (data) {
          if (mounted) {
            setState(() {
              _isApproved = true;
            });
            HapticFeedback.heavyImpact();
            final msg = isMerch
                ? 'Order Approved! Your Merch is being prepared 🎉'
                : 'Payment Approved! Welcome to D.R.E.A.M. Community 🎉';
            DreamToast.success(context, msg);
          }
        },
      );
    }

    // Also listen to global access unlocked event
    PendingApprovalSyncService.instance.onAccessUnlocked.addListener(_onGlobalAccessUnlocked);
  }

  void _onGlobalAccessUnlocked() {
    if (PendingApprovalSyncService.instance.onAccessUnlocked.value && mounted && !_isApproved) {
      setState(() {
        _isApproved = true;
      });
      HapticFeedback.heavyImpact();
      DreamToast.success(context, 'Payment Approved! Access Unlocked 🎉');
    }
  }

  @override
  void dispose() {
    PendingApprovalSyncService.instance.onAccessUnlocked.removeListener(_onGlobalAccessUnlocked);
    _driftController.dispose();
    _twinkleController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _copyCode() {
    final code = isPending && widget.accessCode.contains('PENDING') ? 'PENDING REVIEW' : widget.accessCode;
    Clipboard.setData(ClipboardData(text: code));
    DreamToast.success(context, 'Reference code copied to clipboard!');
  }

  Future<void> _handlePrimaryAction() async {
    await AuthService().getCurrentUser();
    if (!mounted) return;

    final targetIndex = widget.planName.toLowerCase().contains('journal') ? 2 : 0;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => CommunityHubScreen(initialIndex: targetIndex)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMerch = widget.planName.toLowerCase().contains('merch');
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SpaceBackground(
            driftController: _driftController,
            twinkleController: _twinkleController,
            child: const SizedBox.expand(),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isPending
                              ? const LinearGradient(
                                  colors: [Color(0xFFFFB74D), Color(0xFFFF9800)],
                                )
                              : const LinearGradient(
                                  colors: [Color(0xFF69F0AE), Color(0xFF00E5FF)],
                                ),
                          boxShadow: [
                            BoxShadow(
                              color: (isPending ? const Color(0xFFFFB74D) : const Color(0xFF69F0AE)).withOpacity(0.4),
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          isPending ? Icons.schedule_rounded : Icons.check_rounded,
                          color: const Color(0xFF051424),
                          size: 50,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isPending ? 'Payment Submitted!' : 'Payment Successful!',
                      textAlign: TextAlign.center,
                      style: AppColors.soraBold(26).copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isPending
                          ? (isMerch ? "We're reviewing your order & payment" : "We're reviewing your payment")
                          : (isMerch ? 'Thank you for your order! Your merch is being prepared.' : 'Welcome to the D.R.E.A.M. Community Membership!'),
                      textAlign: TextAlign.center,
                      style: AppColors.geistMedium(13).copyWith(
                        color: isPending ? const Color(0xFFFFB74D) : AppColors.cyan,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildReceiptCard(),
                    if (isPending) ...[
                      const SizedBox(height: 16),
                      _buildPendingNoticeCard(),
                    ],
                    const SizedBox(height: 28),
                    _buildActionButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingNoticeCard() {
    final isMerch = widget.planName.toLowerCase().contains('merch');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB74D).withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFB74D).withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB74D).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.info_outline_rounded, color: Color(0xFFFFB74D), size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'What happens next?',
                style: AppColors.soraBold(14).copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _stepRow('1', 'Our team checks and confirms your ${widget.paymentMethod} transfer.'),
          const SizedBox(height: 8),
          _stepRow('2', isMerch ? 'Your merch order will be prepared and confirmed automatically.' : 'Your membership will unlock automatically once confirmed.'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFFFB74D),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isMerch
                        ? 'Listening live for Super Admin approval. Order will confirm in real-time!'
                        : 'Listening live for Super Admin approval. Access will unlock in real-time!',
                    style: AppColors.geistMedium(11.5).copyWith(
                      color: const Color(0xFFFFB74D),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepRow(String num, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFFB74D).withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Text(
            num,
            style: AppColors.soraBold(10).copyWith(color: const Color(0xFFFFB74D)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: AppColors.geistMedium(12.5).copyWith(
              color: Colors.white.withOpacity(0.9),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptCard() {
    final isMerch = widget.planName.toLowerCase().contains('merch');
    final displayCode = isPending && widget.accessCode.contains('PENDING')
        ? 'PENDING REVIEW'
        : widget.accessCode;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF071829),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPending
              ? const Color(0xFFFFB74D).withOpacity(0.3)
              : AppColors.cyan.withOpacity(0.3),
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
        children: [
          Text(
            'TRANSACTION RECEIPT',
            style: AppColors.geistBold(11).copyWith(color: AppColors.textMuted, letterSpacing: 1.5),
          ),
          const SizedBox(height: 16),
          _receiptRow(isMerch ? 'Customer Name' : 'Member Name', widget.userName),
          _receiptRow(isMerch ? 'Order Item(s)' : 'Plan Purchased', widget.planName),
          _receiptRow(isMerch ? 'Order Type' : 'Billing Cycle', widget.billingCycle),
          _receiptRow('Payment Method', widget.paymentMethod),
          _receiptRow('Amount Paid', '\$${widget.amount.toStringAsFixed(2)}'),
          _receiptRow(
            isMerch ? 'Order Status' : 'Access Status',
            isPending ? 'Under Review' : (isMerch ? 'CONFIRMED' : 'ACTIVE (UNLOCKED)'),
            valueColor: isPending ? const Color(0xFFFFB74D) : const Color(0xFF69F0AE),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: Colors.white12),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isMerch ? 'ORDER #' : 'REF CODE', style: AppColors.geistBold(9).copyWith(color: AppColors.textMuted, letterSpacing: 1)),
                  Text(
                    displayCode,
                    style: AppColors.soraBold(14).copyWith(
                      color: isPending ? const Color(0xFFFFB74D) : AppColors.cyan,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _copyCode,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: (isPending ? const Color(0xFFFFB74D) : AppColors.cyan).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (isPending ? const Color(0xFFFFB74D) : AppColors.cyan).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.copy_rounded,
                        color: isPending ? const Color(0xFFFFB74D) : AppColors.cyan,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isMerch ? 'Copy Order #' : 'Copy Code',
                        style: AppColors.geistBold(11).copyWith(
                          color: isPending ? const Color(0xFFFFB74D) : AppColors.cyan,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppColors.geistMedium(12.5).copyWith(color: AppColors.textMuted)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppColors.soraBold(12.5).copyWith(color: valueColor ?? Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    final isMerch = widget.planName.toLowerCase().contains('merch');
    return GestureDetector(
      onTap: _handlePrimaryAction,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: isPending
              ? const LinearGradient(colors: [Color(0xFFFFB74D), Color(0xFFFF9800)])
              : const LinearGradient(colors: [Color(0xFF00DBE9), Color(0xFF00B0FF)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (isPending ? const Color(0xFFFFB74D) : AppColors.cyan).withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            isPending ? 'RETURN TO HOME' : (isMerch ? 'CONTINUE EXPLORING' : 'EXPLORE COMMUNITY HUB'),
            style: AppColors.soraBold(14).copyWith(color: const Color(0xFF051424), letterSpacing: 0.5),
          ),
        ),
      ),
    );
  }
}
