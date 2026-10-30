import 'package:flutter/material.dart';
import 'package:dream_community_app/core/theme/app_theme.dart';

class _ShimmerGradient extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  const _ShimmerGradient({required this.width, required this.height, this.borderRadius = 8});

  @override
  State<_ShimmerGradient> createState() => _ShimmerGradientState();
}

class _ShimmerGradientState extends State<_ShimmerGradient> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(-0.5 + 2.0 * _controller.value, 0),
              colors: [
                AppColors.surface.withOpacity(0.4),
                AppColors.surface.withOpacity(0.1),
                AppColors.surface.withOpacity(0.4),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return _ShimmerGradient(width: width, height: height, borderRadius: borderRadius);
  }
}

class SkeletonVideoRow extends StatelessWidget {
  const SkeletonVideoRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 2,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: SkeletonBox(width: double.infinity, height: double.infinity, borderRadius: 10),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(width: double.infinity, height: 14, borderRadius: 4),
                const SizedBox(height: 8),
                SkeletonBox(width: MediaQuery.of(context).size.width * 0.4, height: 12, borderRadius: 4),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const SkeletonBox(width: 60, height: 12, borderRadius: 4),
                    const SizedBox(width: 10),
                    const SkeletonBox(width: 50, height: 12, borderRadius: 4),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonFeaturedCard extends StatelessWidget {
  const SkeletonFeaturedCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonBox(
      width: double.infinity,
      height: 200,
      borderRadius: 18,
    );
  }
}

class SkeletonEventCard extends StatelessWidget {
  const SkeletonEventCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 48, height: 48, borderRadius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(width: double.infinity, height: 14, borderRadius: 4),
                const SizedBox(height: 8),
                SkeletonBox(width: MediaQuery.of(context).size.width * 0.5, height: 12, borderRadius: 4),
                const SizedBox(height: 6),
                const SkeletonBox(width: 80, height: 12, borderRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonProductCard extends StatelessWidget {
  const SkeletonProductCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: SkeletonBox(width: double.infinity, height: double.infinity, borderRadius: 0),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(width: double.infinity, height: 14, borderRadius: 4),
                const SizedBox(height: 8),
                const SkeletonBox(width: 60, height: 14, borderRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonPostCard extends StatelessWidget {
  const SkeletonPostCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SkeletonBox(width: 32, height: 32, borderRadius: 16),
              const SizedBox(width: 10),
              SkeletonBox(width: MediaQuery.of(context).size.width * 0.3, height: 14, borderRadius: 4),
            ],
          ),
          const SizedBox(height: 12),
          const SkeletonBox(width: double.infinity, height: 16, borderRadius: 4),
          const SizedBox(height: 8),
          SkeletonBox(width: MediaQuery.of(context).size.width * 0.7, height: 12, borderRadius: 4),
          const SizedBox(height: 12),
          Row(
            children: [
              const SkeletonBox(width: 40, height: 12, borderRadius: 4),
              const SizedBox(width: 16),
              const SkeletonBox(width: 40, height: 12, borderRadius: 4),
            ],
          ),
        ],
      ),
    );
  }
}

class SkeletonHomeChatCard extends StatelessWidget {
  const SkeletonHomeChatCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          const SkeletonBox(width: 36, height: 36, borderRadius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: MediaQuery.of(context).size.width * 0.35, height: 14, borderRadius: 4),
                const SizedBox(height: 6),
                SkeletonBox(width: MediaQuery.of(context).size.width * 0.45, height: 11, borderRadius: 4),
              ],
            ),
          ),
          const SkeletonBox(width: 18, height: 18, borderRadius: 4),
        ],
      ),
    );
  }
}

class SkeletonHomeEventCard extends StatelessWidget {
  const SkeletonHomeEventCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        children: [
          const SkeletonBox(width: 48, height: 48, borderRadius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: MediaQuery.of(context).size.width * 0.4, height: 10, borderRadius: 4),
                const SizedBox(height: 8),
                SkeletonBox(width: MediaQuery.of(context).size.width * 0.6, height: 14, borderRadius: 4),
                const SizedBox(height: 6),
                SkeletonBox(width: MediaQuery.of(context).size.width * 0.45, height: 11, borderRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonFeaturedVideoCard extends StatelessWidget {
  const SkeletonFeaturedVideoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: SkeletonBox(width: double.infinity, height: double.infinity, borderRadius: 0),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SkeletonBox(width: 80, height: 12, borderRadius: 6),
                  const SizedBox(height: 4),
                  SkeletonBox(width: MediaQuery.of(context).size.width * 0.35, height: 14, borderRadius: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
