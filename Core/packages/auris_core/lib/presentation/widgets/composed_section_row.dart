import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auris_core.dart';
import '../../core/utils/responsive_utils.dart';

/// Widget reutilizable que renderiza una fila completa de la Home (`ComposedHomeSection`)
/// manejando automáticamente todas las presentaciones visuales (wide, poster, posterLarge, top10, top10Wide).
class ComposedSectionRow extends ConsumerWidget {
  final ComposedHomeSection section;
  final void Function(MediaItem item)? onItemTap;

  const ComposedSectionRow({
    super.key,
    required this.section,
    this.onItemTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final horizontalPadding = ResponsiveUtils.horizontalPadding(context);

    // Altura del contenedor de la fila según la presentación
    double rowHeight;
    if (section.presentation == SectionPresentation.wide) {
      rowHeight = ResponsiveUtils.bannerRowHeight(context);
    } else if (section.presentation == SectionPresentation.posterLarge || section.presentation == SectionPresentation.expandablePoster) {
      rowHeight = ResponsiveUtils.largePosterRowHeight(context, hasInfo: false);
    } else if (section.presentation == SectionPresentation.top10Wide) {
      rowHeight = ResponsiveUtils.bannerHeight(context) + 20;
    } else {
      rowHeight = ResponsiveUtils.rowHeight(context, hasInfo: false);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Título de la sección
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Text(
            section.title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: ResponsiveUtils.rowTitleFontSize(context),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Fila horizontal scrolleable de tarjetas
        SizedBox(
          height: rowHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            itemCount: section.items.length,
            itemBuilder: (context, index) {
              final item = section.items[index];
              final rightMargin = index == section.items.length - 1 ? 0.0 : (isMobile ? 12.0 : 16.0);

              Widget cardWidget;

              if (section.presentation == SectionPresentation.top10Wide) {
                // Top 10 Wide (TV)
                cardWidget = FocusableTop10WideCard(
                  rank: index + 1,
                  title: item.title,
                  imageUrl: item.bannerUrl ?? item.posterUrl,
                  onTap: () => onItemTap?.call(item),
                  subtitle: item.subtitle,
                  rating: formatRating(item.rating),
                  mediaItem: item,
                  width: ResponsiveUtils.bannerWidth(context),
                  height: ResponsiveUtils.bannerHeight(context),
                );
              } else if (section.presentation == SectionPresentation.wide) {
                // Wide Card (widecard)
                cardWidget = FocusableWideCard(
                  title: item.title,
                  imageUrl: item.bannerUrl ?? item.posterUrl,
                  onTap: () => onItemTap?.call(item),
                  subtitle: item.subtitle,
                  rating: formatRating(item.rating),
                  mediaItem: item,
                  width: ResponsiveUtils.bannerWidth(context),
                  height: ResponsiveUtils.bannerHeight(context),
                );
              } else if (section.presentation == SectionPresentation.posterLarge || section.presentation == SectionPresentation.expandablePoster) {
                // Expandable Poster / Large Poster
                cardWidget = FocusableExpandablePosterCard(
                  title: item.title,
                  posterUrl: item.posterUrl,
                  bannerUrl: item.bannerUrl,
                  onTap: () => onItemTap?.call(item),
                  subtitle: item.subtitle,
                  rating: formatRating(item.rating),
                  mediaItem: item,
                );
              } else if (section.presentation == SectionPresentation.top10) {
                // Top 10 Poster (Mobile/Web) - Sin título debajo de la tarjeta
                cardWidget = FocusablePosterCard(
                  title: item.title,
                  posterUrl: item.posterUrl,
                  onTap: () => onItemTap?.call(item),
                  subtitle: item.subtitle,
                  rating: formatRating(item.rating),
                  mediaItem: item,
                  showInfo: false,
                );
              } else {
                // Poster normal
                cardWidget = FocusablePosterCard(
                  title: item.title,
                  posterUrl: item.posterUrl,
                  onTap: () => onItemTap?.call(item),
                  subtitle: item.subtitle,
                  rating: formatRating(item.rating),
                  mediaItem: item,
                );
              }

              return Padding(
                padding: EdgeInsets.only(right: rightMargin),
                child: cardWidget,
              );
            },
          ),
        ),
      ],
    );
  }
}
