import 'package:flutter/material.dart';
import '../../core/utils/responsive_utils.dart';

class SkeletonContainer extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonContainer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<SkeletonContainer> createState() => _SkeletonContainerState();
}

class _SkeletonContainerState extends State<SkeletonContainer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    _animation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.05),
                Colors.white.withValues(alpha: 0.12),
                Colors.white.withValues(alpha: 0.05),
              ],
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

class RowSkeleton extends StatelessWidget {
  final bool isWide;
  final int itemCount;

  const RowSkeleton({
    super.key,
    this.isWide = false,
    this.itemCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final hPadding = ResponsiveUtils.horizontalPadding(context);
    
    final cardWidth = isWide 
        ? (isMobile ? ResponsiveUtils.sp(context, 280.0) : ResponsiveUtils.sp(context, 420.0)) 
        : (isMobile ? ResponsiveUtils.sp(context, 140.0) : ResponsiveUtils.sp(context, 200.0));
    final cardHeight = isWide 
        ? (isMobile ? ResponsiveUtils.sp(context, 160.0) : ResponsiveUtils.sp(context, 200.0)) 
        : (isMobile ? ResponsiveUtils.sp(context, 230.0) : ResponsiveUtils.sp(context, 340.0));
    
    final totalHeight = isWide 
        ? (isMobile ? ResponsiveUtils.sp(context, 215) : ResponsiveUtils.sp(context, 280))
        : (isMobile ? ResponsiveUtils.sp(context, 280) : ResponsiveUtils.sp(context, 400));

    return Padding(
      padding: EdgeInsets.only(bottom: isWide ? (isMobile ? 24 : 48) : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPadding),
            child: const SkeletonContainer(width: 200, height: 24),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: totalHeight,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 10),
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: itemCount,
              separatorBuilder: (_, __) => SizedBox(width: isMobile ? 16 : 30),
              itemBuilder: (_, __) => SizedBox(
                width: cardWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SkeletonContainer(width: cardWidth, height: double.infinity),
                    ),
                    const SizedBox(height: 12),
                    const SkeletonContainer(width: 120, height: 16),
                    const SizedBox(height: 6),
                    const SkeletonContainer(width: 80, height: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HeroBannerSkeleton extends StatelessWidget {
  const HeroBannerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final hPadding = ResponsiveUtils.horizontalPadding(context);
    final aspectRatio = isMobile ? 16 / 11 : 2.8 / 1;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        children: [
          const SkeletonContainer(
            width: double.infinity, 
            height: double.infinity, 
            borderRadius: 0,
          ),
          Positioned(
            left: hPadding,
            bottom: isMobile ? 40 : 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SkeletonContainer(
                  width: isMobile ? 180 : 500, 
                  height: isMobile ? 24 : 64, // Título más grande en desktop
                ),
                const SizedBox(height: 16),
                // Línea de metadatos sutil
                if (!isMobile) ...[
                  const SkeletonContainer(width: 300, height: 20),
                  const SizedBox(height: 24),
                ],
                Row(
                  children: [
                    SkeletonContainer(
                      width: isMobile ? 100 : 180, 
                      height: isMobile ? 36 : 56,
                    ),
                    const SizedBox(width: 12),
                    const SkeletonContainer(width: 56, height: 56, borderRadius: 28),
                    const SizedBox(width: 12),
                    const SkeletonContainer(width: 56, height: 56, borderRadius: 28),
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
