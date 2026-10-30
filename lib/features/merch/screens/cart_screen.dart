import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/features/merch/services/cart_store.dart';
import 'package:dream_community_app/features/merch/screens/checkout_screen.dart';
import 'package:dream_community_app/features/auth/services/auth_service.dart';
import 'package:dream_community_app/shared/widgets/dream_network_image.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isMember = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await AuthService().getCurrentUser();
    if (mounted && user != null) {
      setState(() => _isMember = user.hasCommunityAccess);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05101E),
      body: ListenableBuilder(
        listenable: CartStore(),
        builder: (context, _) {
          final items = CartStore().items;
          final subtotal = CartStore().subtotal;
          final discount = _isMember ? subtotal * 0.10 : 0.0;
          final total = subtotal - discount;

          return SafeArea(
            child: items.isEmpty
                ? _buildEmptyState()
                : Stack(
                    children: [
                      // Atmospheric subtle glow
                      Positioned(
                        top: -60,
                        right: -40,
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.cyan.withValues(alpha: 0.05),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.cyan.withValues(alpha: 0.06),
                                blurRadius: 100,
                                spreadRadius: 30,
                              ),
                            ],
                          ),
                        ),
                      ),

                      Column(
                        children: [
                          // 1. Clean Navigation Header
                          _buildHeader(),

                          // 2. Cart Items List
                          Expanded(
                            child: ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(18, 12, 18, 260),
                              itemCount: items.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                return _buildCartItemCard(items[index], index);
                              },
                            ),
                          ),
                        ],
                      ),

                      // 3. Floating Bottom Checkout Bar
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _buildBottomSummary(subtotal, discount, total),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  // ── Clean Header (NO BADGE PILL) ──
  Widget _buildHeader() {
    final count = CartStore().totalQty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          // Minimalist Back Button
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 15),
            ),
          ),
          const SizedBox(width: 14),

          // Title & Count
          Text(
            'Cart',
            style: GoogleFonts.sora(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '($count)',
            style: GoogleFonts.sora(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.cyan,
            ),
          ),

          const Spacer(),

          // Clear All Button
          if (CartStore().items.isNotEmpty)
            GestureDetector(
              onTap: () async {
                HapticFeedback.mediumImpact();
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF0C1626),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    title: Text('Clear Bag?', style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                    content: Text('Remove all items from your bag?', style: AppColors.geistMedium(13).copyWith(color: AppColors.textSecondary)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Cancel', style: AppColors.geistMedium(13).copyWith(color: AppColors.textMuted)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text('Clear', style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.error)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await CartStore().clear();
                  if (mounted) setState(() {});
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  'Clear',
                  style: GoogleFonts.sora(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Cart Item Card (Clean, Simple, Product-Led — NO BADGE PILLS) ──
  Widget _buildCartItemCard(Map<String, dynamic> item, int index) {
    final isDonation = item['isDonation'] == true;
    final name = item['name'] as String? ?? 'Item';
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final qty = (item['qty'] as int?) ?? 1;
    final size = item['size'] as String?;
    final color = item['color'] as String?;
    final imageUrl = item['imageUrl'] as String?;
    final lineTotal = price * qty;

    // Build variant description string (e.g. "Size: XL • Black")
    final variantParts = <String>[];
    if (size != null && size.isNotEmpty) variantParts.add('Size: $size');
    if (color != null && color.isNotEmpty) variantParts.add(color);
    if (isDonation && item['package'] != null) variantParts.add(item['package'].toString());
    final variantText = variantParts.join(' • ');

    return Dismissible(
      key: ValueKey('$name-$size-$color-$index'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) async {
        HapticFeedback.lightImpact();
        await CartStore().remove(index);
        if (mounted) setState(() {});
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 22),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF081322),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Product Thumbnail (Loaded with resilient DreamNetworkImage)
            Container(
              width: 78,
              height: 84,
              decoration: BoxDecoration(
                color: const Color(0xFF050D18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              clipBehavior: Clip.antiAlias,
              child: DreamNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                cacheWidth: 350,
                placeholder: (_) => Center(
                  child: Icon(
                    isDonation ? Icons.mic_rounded : Icons.checkroom_rounded,
                    size: 26,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 14),

            // Item Meta & Stepper
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name
                  Text(
                    name,
                    style: GoogleFonts.sora(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Variant info (Clean text — NO PILL BADGES)
                  if (variantText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      variantText,
                      style: GoogleFonts.sora(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Bottom row: Stepper + Line Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Quantity Stepper (Non-donation only)
                      if (!isDonation)
                        Container(
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _stepperBtn(
                                icon: Icons.remove_rounded,
                                enabled: qty > 1,
                                onTap: () async {
                                  if (qty > 1) {
                                    HapticFeedback.selectionClick();
                                    await CartStore().updateQty(index, qty - 1);
                                    if (mounted) setState(() {});
                                  }
                                },
                              ),
                              Container(
                                constraints: const BoxConstraints(minWidth: 28),
                                alignment: Alignment.center,
                                child: Text(
                                  '$qty',
                                  style: GoogleFonts.sora(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              _stepperBtn(
                                icon: Icons.add_rounded,
                                enabled: qty < 10,
                                onTap: () async {
                                  if (qty < 10) {
                                    HapticFeedback.selectionClick();
                                    await CartStore().updateQty(index, qty + 1);
                                    if (mounted) setState(() {});
                                  }
                                },
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          'Qty: 1',
                          style: GoogleFonts.sora(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),

                      // Single, Clean Price Display
                      Text(
                        '\$${lineTotal.toStringAsFixed(2)}',
                        style: GoogleFonts.sora(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.cyan,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Remove Item Trash Icon
            GestureDetector(
              onTap: () async {
                HapticFeedback.lightImpact();
                await CartStore().remove(index);
                if (mounted) setState(() {});
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepperBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 28,
        height: 32,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 14,
          color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.2),
        ),
      ),
    );
  }

  // ── Floating Bottom Summary & Primary CTA ──
  Widget _buildBottomSummary(double subtotal, double discount, double total) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 14),
          decoration: BoxDecoration(
            color: const Color(0xFF07101E).withValues(alpha: 0.94),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 28,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Subtotal
              _summaryRow('Subtotal', '\$${subtotal.toStringAsFixed(2)}'),

              // Member Discount (if applicable)
              if (_isMember && discount > 0) ...[
                const SizedBox(height: 8),
                _summaryRow(
                  'Member Discount (10%)',
                  '-\$${discount.toStringAsFixed(2)}',
                  valueColor: AppColors.success,
                ),
              ],

              const SizedBox(height: 8),

              // Shipping
              _summaryRow('Shipping', 'Free', valueColor: AppColors.success),

              const SizedBox(height: 12),

              Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.06),
              ),

              const SizedBox(height: 12),

              // Total Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: GoogleFonts.sora(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '\$${total.toStringAsFixed(2)}',
                    style: GoogleFonts.sora(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.cyan,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Dominant High-Impact CTA Button
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                  );
                },
                child: Container(
                  height: 50,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF00E5FF),
                        Color(0xFF00B4D8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cyan.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 17,
                        color: Color(0xFF051424),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Proceed to Checkout • \$${total.toStringAsFixed(2)}',
                        style: GoogleFonts.sora(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF051424),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.sora(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.sora(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? Colors.white,
          ),
        ),
      ],
    );
  }

  // ── Clean Minimalist Empty State ──
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Center(
                child: Icon(
                  Icons.shopping_bag_outlined,
                  size: 32,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your bag is empty',
              style: GoogleFonts.sora(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Explore the exclusive D.R.E.A.M collection and add items to your bag.',
              style: AppColors.hankenMedium(12.5).copyWith(
                color: AppColors.textMuted,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context);
              },
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cyan.withValues(alpha: 0.4)),
                  color: AppColors.cyan.withValues(alpha: 0.08),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.cyan),
                    const SizedBox(width: 8),
                    Text(
                      'Explore Merch',
                      style: GoogleFonts.sora(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.cyan,
                      ),
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
}
