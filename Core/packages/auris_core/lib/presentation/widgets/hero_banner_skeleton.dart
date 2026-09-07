import 'package:flutter/material.dart';
import '../../core/utils/responsive_utils.dart';
import '../../auris_core.dart';
import 'skeleton_container.dart';

class HeroBannerSkeleton extends StatelessWidget {
  final double? aspectRatio;
  final double? horizontalPadding;

  const HeroBannerSkeleton({
    super.key,
    this.aspectRatio,
    this.horizontalPadding,
  });

  @override
  Widget build(BuildContext context) {
    // Senior Strategy: Tablets (MD) usan Layout Mobile para el skeleton para coincidir con el Hero real
    final bool useMobileLayout = context.breakpoint < Breakpoint.lg;
    final double hPadding = horizontalPadding ?? ResponsiveUtils.horizontalPadding(context);
    final double ratio = aspectRatio ?? ResponsiveUtils.heroAspectRatio(context);

    final Widget skeletonContent = AspectRatio(
      aspectRatio: ratio,
      child: Stack(
        children: [
          // Fondo base
          const SkeletonContainer(
            width: double.infinity, 
            height: double.infinity, 
            borderRadius: 0,
          ),

          // Layout adaptativo para el contenido del Skeleton
          if (useMobileLayout)
            // Mobile: Logo abajo a la izquierda, metadata alineada
            Positioned.fill(
              left: 20, top: 20, right: 20, bottom: 35,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo (Izquierda)
                  SkeletonContainer(
                    width: 160,
                    height: ResponsiveUtils.heroLogoHeight(context)
                  ),
                  const SizedBox(height: 12),
                  // Metadata
                  Row(
                    children: [
                      const SkeletonContainer(width: 100, height: 14),
                      const SizedBox(width: 12),
                      const SkeletonContainer(width: 80, height: 14),
                    ],
                  ),
                ],
              ),
            )
          else
            // Cinematic: Layout tradicional de texto y botones a la izquierda
            Positioned(
              left: 80,
              bottom: 45,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SkeletonContainer(
                    width: 400,
                    height: ResponsiveUtils.heroLogoHeight(context)
                  ), // Logo imponente
                  const SizedBox(height: 24),
                  const SkeletonContainer(width: 500, height: 20), // Metadata row
                  const SizedBox(height: 24),
                  const SkeletonContainer(width: 450, height: 60), // Sinopsis
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      const SkeletonContainer(width: 160, height: 50, borderRadius: 25),
                      const SizedBox(width: 12),
                      const SkeletonContainer(width: 50, height: 50, borderRadius: 25),
                      const SizedBox(width: 12),
                      const SkeletonContainer(width: 50, height: 50, borderRadius: 25),
                    ],
                  ),
                ],
              ),
            ),

          // Dots indicator
          Positioned(
            bottom: useMobileLayout ? 15 : 25,
            left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: index == 0 ? 12 : 7, height: 7,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
              )),
            ),
          ),
        ],
      ),
    );

    if (useMobileLayout) return skeletonContent;

    // Senior Fix: Aplicar el mismo Padding que el HeroBanner real para evitar Layout Shifts
    return Padding(
      padding: EdgeInsets.fromLTRB(hPadding, 24, hPadding, 48),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10, width: 2.0),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: skeletonContent,
        ),
      ),
    );
  }
}
