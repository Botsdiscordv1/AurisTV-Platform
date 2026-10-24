import 'package:flutter/material.dart';
import 'package:auris_core/auris_core.dart';
import '../../core/utils/tv_responsive_utils.dart';

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
    final double screenWidth = MediaQuery.of(context).size.width;
    final double horizontalPadding = TVResponsiveUtils.horizontalPadding(context);
    final double aspectRatio = TVResponsiveUtils.heroAspectRatio(context);

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        color: const Color(0xFF000000),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Shimmering Background Base
            const SkeletonContainer(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 0,
            ),

            // 2. Viñeta cinematográfica idéntica al HeroBanner (Netflix TV)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFF000000),
                    Color(0xF2000000),
                    Color(0xB3000000),
                    Color(0x33000000),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.28, 0.48, 0.70, 0.95],
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Color(0xFF000000),
                    Color(0xEB000000),
                    Color(0x80000000),
                    Color(0x26000000),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.12, 0.32, 0.58, 0.85],
                ),
              ),
            ),

            // 3. Contenido en esqueleto alineado con el HeroBanner real
            Positioned(
              left: horizontalPadding,
              bottom: 28,
              right: horizontalPadding,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // A. Branding Header (Logo + Medio + TOP 10)
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SkeletonContainer(width: 80, height: 14, borderRadius: 3),
                        SizedBox(width: 12),
                        SkeletonContainer(width: 48, height: 16, borderRadius: 2),
                        SizedBox(width: 8),
                        SkeletonContainer(width: 130, height: 14, borderRadius: 3),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // B. Title / Logo Placeholder
                    SkeletonContainer(
                      width: (screenWidth * 0.32).clamp(280.0, 480.0),
                      height: 72,
                      borderRadius: 6,
                    ),
                    const SizedBox(height: 14),

                    // C. Netflix TV Metadata Badges Row
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SkeletonContainer(width: 75, height: 15, borderRadius: 3),
                        SizedBox(width: 10),
                        SkeletonContainer(width: 40, height: 15, borderRadius: 3),
                        SizedBox(width: 10),
                        SkeletonContainer(width: 32, height: 18, borderRadius: 2),
                        SizedBox(width: 10),
                        SkeletonContainer(width: 70, height: 15, borderRadius: 3),
                        SizedBox(width: 10),
                        SkeletonContainer(width: 46, height: 18, borderRadius: 2),
                        SizedBox(width: 6),
                        SkeletonContainer(width: 34, height: 18, borderRadius: 2),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // D. Synopsis (3 lines matching Netflix TV)
                    SkeletonContainer(
                      width: (screenWidth * 0.44).clamp(340.0, 620.0),
                      height: 13,
                      borderRadius: 3,
                    ),
                    const SizedBox(height: 6),
                    SkeletonContainer(
                      width: (screenWidth * 0.38).clamp(300.0, 540.0),
                      height: 13,
                      borderRadius: 3,
                    ),
                    const SizedBox(height: 6),
                    SkeletonContainer(
                      width: (screenWidth * 0.24).clamp(200.0, 360.0),
                      height: 13,
                      borderRadius: 3,
                    ),
                    const SizedBox(height: 20),

                    // E. Action Buttons (Netflix TV Style: Rectangles with 4px border radius)
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Reproducir
                        SkeletonContainer(width: 135, height: 42, borderRadius: 4),
                        SizedBox(width: 10),
                        // Mi lista
                        SkeletonContainer(width: 110, height: 42, borderRadius: 4),
                        SizedBox(width: 10),
                        // Tráiler
                        SkeletonContainer(width: 100, height: 42, borderRadius: 4),
                      ],
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
