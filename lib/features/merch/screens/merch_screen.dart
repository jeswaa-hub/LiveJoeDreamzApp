import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';
import 'package:dream_community_app/core/models/merch_product_model.dart';
import 'package:dream_community_app/features/merch/services/merch_service.dart';
import 'package:dream_community_app/features/merch/screens/product_detail_screen.dart';
import 'package:dream_community_app/features/merch/screens/cart_screen.dart';
import 'package:dream_community_app/features/merch/services/cart_store.dart';
import 'package:dream_community_app/shared/widgets/skeleton.dart';
import 'package:dream_community_app/shared/widgets/dream_network_image.dart';

class MerchScreen extends StatefulWidget {
  const MerchScreen({super.key});

  @override
  State<MerchScreen> createState() => _MerchScreenState();
}

class _MerchScreenState extends State<MerchScreen> {
  bool _isLoading = true;
  List<MerchProductModel> _products = [];
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final data = await MerchService().getProducts();
    data.sort((a, b) => b.price.compareTo(a.price));
    if (mounted) {
      setState(() {
        _products = data;
        _isLoading = false;
      });
    }
  }

  List<String> get _categories {
    final cats = _products
        .map((p) => p.category)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    cats.sort();
    return ['All', ...cats];
  }

  String _formatCategoryLabel(String cat) {
    final lower = cat.toLowerCase().trim();
    if (lower == 'all') return 'All';
    if (lower == 'apparel') return 'Apparel';
    if (lower == 'journal') return 'Journals';
    if (lower.contains('rap') || lower.contains('freestyle')) return 'Freestyle Rap';
    return cat.isNotEmpty ? '${cat[0].toUpperCase()}${cat.substring(1)}' : cat;
  }

  List<MerchProductModel> get _filtered {
    var list = _selectedCategory == 'All'
        ? _products
        : _products.where((p) => p.category == _selectedCategory).toList();
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      list = list.where((p) {
        final nameMatch = p.name.toLowerCase().contains(query);
        final catMatch = p.category.toLowerCase().contains(query);
        return nameMatch || catMatch;
      }).toList();
    }
    final sorted = List<MerchProductModel>.from(list);
    sorted.sort((a, b) => b.price.compareTo(a.price));
    return sorted;
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = 'All';
      _searchQuery = '';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async => await _loadData(),
        color: AppColors.cyan,
        backgroundColor: AppColors.surface,
        child: _isLoading ? _buildLoadingGrid() : _buildContent(),
      ),
    );
  }

  Widget _buildLoadingGrid() {
    final topPadding = MediaQuery.of(context).padding.top;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPadding + 14, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildSearchBar(),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 14,
              childAspectRatio: 0.70,
              children: List.generate(4, (_) => const SkeletonProductCard()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final topPadding = MediaQuery.of(context).padding.top;
    return CustomScrollView(
      slivers: [
        // App Bar & Search Header
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 14),
                _buildSearchBar(),
              ],
            ),
          ),
        ),

        // Minimalist Category Tabs (NO BADGE PILL)
        SliverToBoxAdapter(
          child: _buildCategoryTabs(),
        ),

        // Products Grid or Empty State
        if (_filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 14,
                childAspectRatio: 0.70,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildProductCard(_filtered[index]),
                childCount: _filtered.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Minimalist Back Button
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: const Center(
              child: Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Title
        Expanded(
          child: Text(
            'D.R.E.A.M Closet',
            style: GoogleFonts.russoOne(
              fontSize: 19,
              letterSpacing: 0.5,
              color: Colors.white,
            ),
          ),
        ),
        // Minimalist Cart Button
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CartScreen()),
          ),
          child: ListenableBuilder(
            listenable: CartStore(),
            builder: (context, _) {
              final count = CartStore().totalQty;
              return Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: count > 0 ? AppColors.cyan.withOpacity(0.4) : Colors.white.withOpacity(0.06),
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      color: count > 0 ? AppColors.cyan : Colors.white.withOpacity(0.85),
                      size: 19,
                    ),
                    if (count > 0)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.cyan,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              style: GoogleFonts.sora(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
              decoration: InputDecoration(
                hintText: 'Search merch...',
                hintStyle: GoogleFonts.sora(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textMuted.withOpacity(0.6),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  // Pure Minimalist Typographic Tabs (NO BADGE PILL)
  Widget _buildCategoryTabs() {
    return Container(
      margin: const EdgeInsets.only(top: 14, bottom: 2),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.06),
            width: 1,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: _categories.map((cat) {
            final isSelected = _selectedCategory == cat;
            final label = _formatCategoryLabel(cat);
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedCategory = cat);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? AppColors.cyan : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.sora(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : AppColors.textMuted,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // Clean, Minimalist Product Card (NO BADGE PILLS, NO CLUTTER)
  Widget _buildProductCard(MerchProductModel product) {
    final detailMap = product.toDetailMap();
    final isSoldOut = product.isSoldOut;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(product: detailMap),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Image Container
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: const Color(0xFF07101E),
                    child: DreamNetworkImage(
                      imageUrl: product.imageUrl,
                      fit: BoxFit.cover,
                      cacheWidth: 450,
                      placeholder: (_) => _buildPlaceholder(),
                    ),
                  ),
                  // If sold out, minimal clean text overlay (NO BADGE PILL)
                  if (isSoldOut)
                    Container(
                      color: Colors.black.withOpacity(0.65),
                      alignment: Alignment.center,
                      child: Text(
                        'SOLD OUT',
                        style: GoogleFonts.sora(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Product Meta
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    style: GoogleFonts.sora(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.isDonation
                        ? 'From \$${product.price.toStringAsFixed(0)}'
                        : '\$${product.price.toStringAsFixed(2)}',
                    style: GoogleFonts.sora(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.cyan,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF07101E),
      child: Center(
        child: Icon(
          Icons.shopping_bag_outlined,
          color: AppColors.cyan.withOpacity(0.35),
          size: 32,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Icon(
                Icons.search_off_rounded,
                color: AppColors.textMuted.withOpacity(0.7),
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No items found',
              style: GoogleFonts.sora(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No products matched "$_searchQuery".'
                  : 'No merchandise available in this category.',
              textAlign: TextAlign.center,
              style: GoogleFonts.sora(
                fontSize: 12.5,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: _clearFilters,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.cyan.withOpacity(0.25)),
                ),
                child: Text(
                  'Reset Filters',
                  style: GoogleFonts.sora(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.cyan,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
