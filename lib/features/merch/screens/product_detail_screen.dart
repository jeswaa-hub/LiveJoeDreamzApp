import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/core/config/api_config.dart';
import 'package:dream_community_app/core/widgets/dream_toast.dart';
import 'package:dream_community_app/features/merch/services/cart_store.dart';
import 'package:dream_community_app/features/merch/screens/cart_screen.dart';
import 'package:dream_community_app/shared/widgets/dream_network_image.dart';
import 'package:dream_community_app/shared/widgets/space_background.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedSize;
  String? _selectedColor;
  String? _selectedPackage;
  int _selectedPackagePrice = 0;
  String? _selectedBundleSize;
  int _qty = 1;
  bool _isFavorite = false;
  bool _isAdding = false;

  AnimationController? _favAnimController;
  Animation<double>? _favScaleAnim;

  bool get _isDonation => widget.product['isDonation'] == true;
  bool get _isSoldOut =>
      widget.product['status'] == 'sold_out' || widget.product['stock'] == 0;
  bool get _isComingSoon => widget.product['status'] == 'coming_soon';
  bool get _hasSizes => (widget.product['sizes'] as List? ?? []).isNotEmpty;
  bool get _hasColors => (widget.product['colors'] as List? ?? []).isNotEmpty;

  int get _maxQty {
    final stock = widget.product['stock'] as int? ?? 0;
    if (stock <= 0) return 1;
    return stock > 10 ? 10 : stock;
  }

  bool get _isVipBundle {
    if (!_isDonation || _selectedPackage == null) return false;
    final packages = widget.product['packages'] as List? ?? [];
    final selected = packages.where((p) => p['name'] == _selectedPackage).toList();
    return selected.isNotEmpty && selected.first['vip'] == true;
  }

  double get _currentUnitPrice {
    if (_isDonation) {
      return _selectedPackage != null
          ? _selectedPackagePrice.toDouble()
          : (widget.product['price'] as num? ?? 0).toDouble();
    }
    return (widget.product['price'] as num? ?? 0).toDouble();
  }

  double get _totalPrice => _currentUnitPrice * (_isDonation ? 1 : _qty);

  void _initFavoriteAnimation() {
    if (_favAnimController != null && _favScaleAnim != null) return;
    _favAnimController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _favScaleAnim ??= TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _favAnimController!, curve: Curves.easeInOut));
  }

  @override
  void initState() {
    super.initState();
    _initFavoriteAnimation();

    // Pre-select first size if available
    final sizes = widget.product['sizes'] as List? ?? [];
    if (!_isDonation && sizes.isNotEmpty) {
      _selectedSize = sizes.first.toString();
    }

    // Pre-select first color if available
    final colors = widget.product['colors'] as List? ?? [];
    if (!_isDonation && colors.isNotEmpty) {
      _selectedColor = colors.first.toString();
    }
  }

  @override
  void dispose() {
    _favAnimController?.dispose();
    super.dispose();
  }

  void _toggleFavorite() {
    _initFavoriteAnimation();
    HapticFeedback.lightImpact();
    setState(() => _isFavorite = !_isFavorite);
    _favAnimController?.forward(from: 0.0);
    DreamToast.info(
      context,
      _isFavorite ? 'Saved to wishlist' : 'Removed from wishlist',
    );
  }

  Future<void> _addToCart() async {
    if (_isDonation && _selectedPackage == null) {
      HapticFeedback.heavyImpact();
      DreamToast.error(context, 'Please select a package first.');
      return;
    }
    if (_isVipBundle && _selectedBundleSize == null) {
      HapticFeedback.heavyImpact();
      DreamToast.error(context, 'Please select a t-shirt size.');
      return;
    }
    if (!_isDonation && _hasSizes && _selectedSize == null) {
      HapticFeedback.heavyImpact();
      DreamToast.error(context, 'Please select a size first.');
      return;
    }

    setState(() => _isAdding = true);
    HapticFeedback.mediumImpact();

    final price = _currentUnitPrice;
    final name = widget.product['name'] as String? ?? 'Item';
    final rawUrl = widget.product['imageUrl'] ?? widget.product['image_url'];
    final imageUrl = ApiConfig.resolveUrl(rawUrl?.toString());

    await CartStore().add({
      'name': name,
      'price': price,
      'qty': _isDonation ? 1 : _qty,
      'size': _isDonation ? _selectedBundleSize : _selectedSize,
      'color': _selectedColor,
      'category': widget.product['category'],
      'isDonation': _isDonation,
      'package': _isDonation ? _selectedPackage : null,
      'imageUrl': imageUrl,
    });

    if (mounted) {
      setState(() => _isAdding = false);
      DreamToast.success(
        context,
        '${_isDonation ? _selectedPackage : name} added to bag!',
      );
    }
  }

  Color _parseColor(dynamic c) {
    if (c is Color) return c;
    if (c is String) {
      var hex = c.replaceAll('#', '').trim();
      if (hex.length == 6) hex = 'FF$hex';
      final val = int.tryParse(hex, radix: 16);
      if (val != null) return Color(val);
    }
    return AppColors.cyan;
  }

  void _showImageLightbox(String? imageUrl) {
    if (imageUrl == null || imageUrl.trim().isEmpty) return;
    HapticFeedback.selectionClick();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 3.5,
              child: Center(
                child: DreamNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 50,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSizeGuideModal() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 34),
        decoration: BoxDecoration(
          color: const Color(0xFF0C1626),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text('Size Guide (Inches)', style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.025),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    children: ['SIZE', 'CHEST', 'WAIST', 'LENGTH'].map((title) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: AppColors.geistBold(10).copyWith(color: AppColors.cyan, letterSpacing: 0.8),
                        ),
                      );
                    }).toList(),
                  ),
                  ...[
                    ['XS', '34 - 36', '28 - 30', '27'],
                    ['S', '36 - 38', '30 - 32', '28'],
                    ['M', '38 - 40', '32 - 34', '29'],
                    ['L', '40 - 42', '34 - 36', '30'],
                    ['XL', '42 - 44', '36 - 38', '31'],
                    ['XXL', '44 - 46', '38 - 40', '32'],
                    ['3XL', '46 - 48', '40 - 42', '33'],
                  ].map((row) {
                    return TableRow(
                      children: row.map((val) {
                        final isSize = val == row.first;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                          child: Text(
                            val,
                            textAlign: TextAlign.center,
                            style: isSize
                                ? GoogleFonts.sora(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)
                                : AppColors.geistMedium(11).copyWith(color: AppColors.textSecondary),
                          ),
                        );
                      }).toList(),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _initFavoriteAnimation();
    final product = widget.product;
    final name = product['name'] as String? ?? 'Product';
    final description = (product['description'] as String?)?.trim() ?? '';
    final hasDesc = description.isNotEmpty && description.toLowerCase() != 'none';
    final rawUrl = product['imageUrl'] ?? product['image_url'];
    final imageUrl = ApiConfig.resolveUrl(rawUrl?.toString());

    return Scaffold(
      backgroundColor: const Color(0xFF05101E),
      body: SpaceBackground(
        child: Stack(
          children: [
            // Main Scrollable Content
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Top Clean Navigation Bar
                  _buildHeader(context),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 110),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Hero Product Showcase (Reverted Container)
                          _buildHeroShowcase(imageUrl),

                          const SizedBox(height: 22),

                          // 2. Product Title & Price
                          _buildTitleAndPrice(name),

                          // 3. Clean Product Description (if available)
                          if (hasDesc) ...[
                            const SizedBox(height: 16),
                            Text(
                              description,
                              style: AppColors.hankenMedium(13.5).copyWith(
                                color: Colors.white.withValues(alpha: 0.72),
                                height: 1.55,
                              ),
                            ),
                          ],

                          const SizedBox(height: 22),

                          // 4. Clean Minimalist Size Selector (NO PILL BADGE)
                          if (!_isDonation && _hasSizes)
                            _buildSizeSelector(product['sizes'] as List),

                          // 5. Clean Minimalist Color Selector (NO PILL BADGE)
                          if (!_isDonation && _hasColors)
                            _buildColorSelector(product['colors'] as List),

                          // 6. Donation Packages (if applicable)
                          if (_isDonation)
                            _buildDonationPackages(product['packages'] as List? ?? []),

                          // 7. VIP Bundle T-Shirt Size (if applicable)
                          if (_isVipBundle)
                            _buildVipBundleSizeSelector(),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Sticky Bottom Checkout Bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildStickyBottomBar(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header Bar ──
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back Button
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

          const Spacer(),

          // Right Action Icons (Wishlist & Cart)
          Row(
            children: [
              // Wishlist Heart Button
              GestureDetector(
                onTap: _toggleFavorite,
                child: ScaleTransition(
                  scale: _favScaleAnim ?? const AlwaysStoppedAnimation<double>(1.0),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _isFavorite
                          ? AppColors.pink.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isFavorite
                            ? AppColors.pink.withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Icon(
                      _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _isFavorite ? AppColors.pink : Colors.white70,
                      size: 19,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Cart Button with Live Count
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
                },
                child: ListenableBuilder(
                  listenable: CartStore(),
                  builder: (context, _) => Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.shopping_bag_outlined, color: AppColors.cyan, size: 19),
                        if (CartStore().items.isNotEmpty)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.cyan,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.cyan.withValues(alpha: 0.5),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                              child: Center(
                                child: Text(
                                  '${CartStore().totalQty}',
                                  style: const TextStyle(
                                    color: Color(0xFF051424),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 1. Hero Product Showcase (Container Reverted) ──
  Widget _buildHeroShowcase(String? imageUrl) {
    return GestureDetector(
      onTap: () => _showImageLightbox(imageUrl),
      child: Container(
        width: double.infinity,
        height: 380,
        decoration: BoxDecoration(
          color: const Color(0xFF081322),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Soft Radial Lighting behind the product
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, 0),
                    radius: 0.85,
                    colors: [
                      AppColors.cyan.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Real Merch Product Image (Full size covering the container)
            Positioned.fill(
              child: Hero(
                tag: 'product_image_${widget.product['name']}',
                child: DreamNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  cacheWidth: 1000,
                  placeholder: (_) => Center(
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.03),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.cyan,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // If sold out, clean minimal overlay (NO BADGE PILL)
            if (_isSoldOut)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.65),
                  alignment: Alignment.center,
                  child: Text(
                    'SOLD OUT',
                    style: GoogleFonts.sora(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── 2. Product Title & Price ──
  Widget _buildTitleAndPrice(String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Product Title
        Text(
          name,
          style: GoogleFonts.sora(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.25,
            letterSpacing: -0.2,
          ),
        ),

        const SizedBox(height: 10),

        // Product Price (Clean, Bold, Electric Cyan — NO "USD" clutter, NO "Express Dispatch" pill)
        Text(
          '\$${_currentUnitPrice.toStringAsFixed(2)}',
          style: GoogleFonts.sora(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.cyan,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  // ── 3. Clean Modern Size Selector (NO PILL BADGE) ──
  Widget _buildSizeSelector(List sizes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Size',
                  style: GoogleFonts.sora(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (_selectedSize != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    _selectedSize!,
                    style: GoogleFonts.sora(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.cyan,
                    ),
                  ),
                ],
              ],
            ),
            GestureDetector(
              onTap: _showSizeGuideModal,
              child: Text(
                'Size Guide',
                style: GoogleFonts.sora(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.cyan,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: sizes.map((s) {
            final sizeStr = s.toString();
            final isSelected = _selectedSize == sizeStr;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedSize = sizeStr);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 52,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.cyan.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppColors.cyan : Colors.white.withValues(alpha: 0.08),
                    width: isSelected ? 1.6 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.cyan.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    sizeStr,
                    style: GoogleFonts.sora(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppColors.cyan : Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── 4. Clean Modern Color Selector (NO PILL BADGE) ──
  Widget _buildColorSelector(List colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Color',
              style: GoogleFonts.sora(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (_selectedColor != null) ...[
              const SizedBox(width: 8),
              Text(
                _selectedColor!,
                style: GoogleFonts.sora(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.cyan,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: colors.map((c) {
            final colorStr = c.toString();
            final isSelected = _selectedColor == colorStr;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedColor = colorStr);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.cyan.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppColors.cyan : Colors.white.withValues(alpha: 0.08),
                    width: isSelected ? 1.6 : 1,
                  ),
                ),
                child: Text(
                  colorStr,
                  style: GoogleFonts.sora(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.cyan : Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── 5. Clean Donation Packages (if applicable) ──
  Widget _buildDonationPackages(List packages) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Package',
          style: GoogleFonts.sora(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        ...packages.map((pkg) {
          final isSelected = _selectedPackage == pkg['name'];
          final color = _parseColor(pkg['color']);
          final isVip = pkg['vip'] == true;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedPackage = pkg['name'];
                _selectedPackagePrice = (pkg['price'] as num? ?? 0).toInt();
                if (!isVip) _selectedBundleSize = null;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? color : Colors.white.withValues(alpha: 0.07),
                  width: isSelected ? 1.6 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Radio dot
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? color : Colors.white.withValues(alpha: 0.25),
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? Center(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pkg['name'] ?? '',
                          style: GoogleFonts.sora(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? color : Colors.white,
                          ),
                        ),
                        if (pkg['desc'] != null && (pkg['desc'] as String).isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            pkg['desc'],
                            style: AppColors.geistMedium(11).copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    '\$${pkg['price']}',
                    style: GoogleFonts.sora(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? color : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 18),
      ],
    );
  }

  // ── 6. VIP Bundle T-Shirt Size Selector ──
  Widget _buildVipBundleSizeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Included Tee Size',
              style: GoogleFonts.sora(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFFBBF24),
              ),
            ),
            if (_selectedBundleSize != null) ...[
              const SizedBox(width: 8),
              Text(
                _selectedBundleSize!,
                style: GoogleFonts.sora(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFBBF24),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: ['S', 'M', 'L', 'XL', 'XXL'].map((s) {
            final isSelected = _selectedBundleSize == s;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedBundleSize = s);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 52,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFFBBF24).withValues(alpha: 0.16)
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFFBBF24) : Colors.white.withValues(alpha: 0.08),
                    width: isSelected ? 1.6 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    s,
                    style: GoogleFonts.sora(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? const Color(0xFFFBBF24) : Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── 7. Sticky Bottom Action Bar ──
  Widget _buildStickyBottomBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(18, 12, 18, MediaQuery.of(context).padding.bottom + 12),
          decoration: BoxDecoration(
            color: const Color(0xFF07101E).withValues(alpha: 0.92),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: (_isSoldOut || _isComingSoon)
              ? Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _isSoldOut ? 'SOLD OUT' : 'COMING SOON',
                    style: GoogleFonts.sora(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.4),
                      letterSpacing: 1,
                    ),
                  ),
                )
              : Row(
                  children: [
                    // Quantity Stepper (Non-donation only)
                    if (!_isDonation) ...[
                      Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _qtyButton(
                              icon: Icons.remove_rounded,
                              enabled: _qty > 1,
                              onTap: () {
                                if (_qty > 1) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _qty--);
                                }
                              },
                            ),
                            Container(
                              constraints: const BoxConstraints(minWidth: 32),
                              alignment: Alignment.center,
                              child: Text(
                                '$_qty',
                                style: GoogleFonts.sora(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            _qtyButton(
                              icon: Icons.add_rounded,
                              enabled: _qty < _maxQty,
                              onTap: () {
                                if (_qty < _maxQty) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _qty++);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],

                    // Dominant Add to Bag CTA
                    Expanded(
                      child: GestureDetector(
                        onTap: _isAdding ? null : _addToCart,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF00E5FF),
                                Color(0xFF00B4D8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.cyan.withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isAdding)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF051424),
                                    strokeWidth: 2.2,
                                  ),
                                )
                              else ...[
                                const Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 18,
                                  color: Color(0xFF051424),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isDonation
                                      ? (_selectedPackage != null
                                          ? 'ADD PACKAGE • \$${_totalPrice.toStringAsFixed(2)}'
                                          : 'SELECT A PACKAGE')
                                      : 'ADD TO BAG • \$${_totalPrice.toStringAsFixed(2)}',
                                  style: GoogleFonts.sora(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF051424),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _qtyButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 38,
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.2),
          size: 16,
        ),
      ),
    );
  }
}
