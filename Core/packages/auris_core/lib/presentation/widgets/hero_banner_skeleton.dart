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

    final bool isIntermediate = context.breakpoint <= Breakpoint.xl;
    final double logoScale = isIntermediate ? 1.1 : 1.35;

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
            // Cinematic: Layout sincronizado con Hero real
            Positioned(
              left: isIntermediate ? 30 : 40,
              bottom: isIntermediate ? 25 : 45,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Icono + Categoría
                  const SkeletonContainer(width: 120, height: 16),
                  SizedBox(height: isIntermediate ? 10 : 16),

                  // 2. Logo imponente (escalado)
                  SkeletonContainer(
                    width: isIntermediate ? 300 : 400,
                    height: ResponsiveUtils.heroLogoHeight(context) * logoScale,
                  ),
                  SizedBox(height: isIntermediate ? 10 : 16),

                  // 3. Metadata row
                  const SkeletonContainer(width: 450, height: 18),
                  SizedBox(height: isIntermediate ? 16 : 20),

                  // 4. Sinopsis
                  SkeletonContainer(
                    width: MediaQuery.of(context).size.width * (isIntermediate ? 0.35 : 0.28),
                    height: isIntermediate ? 45 : 60,
                  ),
                  SizedBox(height: isIntermediate ? 18 : 32),

                  // 5. Botones
                  Row(
                    children: [
                      SkeletonContainer(width: isIntermediate ? 140 : 180, height: isIntermediate ? 44 : 54, borderRadius: 54),
                      const SizedBox(width: 12),
                      SkeletonContainer(width: isIntermediate ? 44 : 54, height: isIntermediate ? 44 : 54, borderRadius: 54),
                      const SizedBox(width: 12),
                      SkeletonContainer(width: isIntermediate ? 44 : 54, height: isIntermediate ? 44 : 54, borderRadius: 54),
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

    // Senior Fix: Aplicar los mismos Padds que el Hero real
    return Padding(
      padding: EdgeInsets.fromLTRB(hPadding, 8, hPadding, 16),
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
