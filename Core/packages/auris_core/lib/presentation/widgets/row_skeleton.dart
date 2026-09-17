import 'package:flutter/material.dart';
import '../../core/utils/responsive_utils.dart';
import '../../auris_core.dart';
import 'skeleton_container.dart';

class RowSkeleton extends StatelessWidget {
  final bool isWide;
  final int? itemCount;
  final double? horizontalPadding;

  const RowSkeleton({
    super.key,
    this.isWide = false,
    this.itemCount,
    this.horizontalPadding,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMobile = context.isMobile;
    final double screenWidth = MediaQuery.of(context).size.width;
    
    // Senior Fix: Sincronización absoluta con dimensiones dinámicas
    final double hPadding = horizontalPadding ?? ResponsiveUtils.horizontalPadding(context);
    
    // Dimensiones dinámicas centralizadas en ResponsiveUtils
    final double cardWidth = isWide
        ? ResponsiveUtils.bannerWidth(context)
        : ResponsiveUtils.posterWidth(context);
        
    final double cardHeight = isWide 
        ? ResponsiveUtils.bannerHeight(context)
        : ResponsiveUtils.posterHeight(context);
    
    final double totalHeight = (isWide 
        ? ResponsiveUtils.bannerRowHeight(context)
        : ResponsiveUtils.rowHeight(context, hasInfo: isWide)) + 4.0; // Senior Fix: Buffer de seguridad de 4px

    final double spacing = isMobile ? 12.0 : 18.0;

    // Senior Strategy: Cálculo dinámico de items para llenar la pantalla según el ancho disponible
    final int effectiveItemCount = itemCount ?? ((screenWidth - hPadding) / (cardWidth + spacing)).ceil() + 1;

    return Padding(
      padding: EdgeInsets.only(bottom: context.useMobileLayout ? 18 : 32), // Senior: Adaptativo 18px (Mob/Tab) / 32px (Desktop)
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: hPadding),
            child: SkeletonContainer(
              width: 140,
              height: ResponsiveUtils.rowTitleFontSize(context) * 0.8,
            ),
          ),
          const SizedBox(height: 8), // Senior: Unificado a 8px
          SizedBox(
            height: totalHeight,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 0), // Senior: Zero padding vertical
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: effectiveItemCount,
              separatorBuilder: (_, __) => SizedBox(width: spacing),
              itemBuilder: (_, __) => SizedBox(
                width: cardWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Senior Fix: Evitar expansión vertical innecesaria
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // El póster / banner
                    Container(
                      height: cardHeight,
                      width: cardWidth,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(isWide ? 8 : 12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: const SkeletonContainer(width: double.infinity, height: double.infinity),
                    ),
                    // Título dinámico (Solo para filas Wide / Banners)
                    if (isWide) ...[
                      const SizedBox(height: 8),
                      SkeletonContainer(
                        width: cardWidth * 0.8,
                        height: ResponsiveUtils.bannerTitleFontSize(context),
                      ),
                    ],
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
