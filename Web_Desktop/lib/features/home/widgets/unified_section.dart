import 'package:flutter/material.dart';
import 'package:auris_core/auris_core.dart';
import 'content_row.dart';
import 'editorial_content_row.dart';
import 'wide_content_row.dart';
import '../../../shared/widgets/airing_countdown_badge.dart';

class UnifiedSection extends StatelessWidget {
  final SectionPresentation presentation;
  final String title;
  final String? subtitle;
  final List<MediaItem> items;
  final EditorialBadge? badge;
  final SectionSeeMore? verMas;
  final void Function(MediaItem item) onItemTap;
  final void Function(MediaItem item)? onItemDelete;

  const UnifiedSection({
    super.key,
    required this.presentation,
    required this.title,
    this.subtitle,
    required this.items,
    this.badge,
    this.verMas,
    required this.onItemTap,
    this.onItemDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    switch (presentation) {
      case SectionPresentation.wide:
        return RepaintBoundary(
          child: WideContentRow(
            title: title,
            subtitle: subtitle,
            items: items.map((m) => _mapMediaToWide(m)).toList(),
            verMas: verMas,
            onItemTap: (wideItem) => onItemTap(wideItem.originalItem as MediaItem),
          ),
        );
      case SectionPresentation.top10:
        return RepaintBoundary(
          child: EditorialContentRow(
            title: title,
            subtitle: subtitle,
            items: items,
            badge: badge ?? EditorialBadge.mythical,
            forceTopDesign: true,
            verMas: verMas,
            onItemTap: onItemTap,
          ),
        );
      case SectionPresentation.poster:
      default:
        return RepaintBoundary(
          child: ContentRow(
            title: title,
            subtitle: subtitle,
            items: items,
            verMas: verMas,
            onItemTap: onItemTap,
          ),
        );
    }
  }

  WideContentItem _mapMediaToWide(MediaItem m) {
    // Specialized logic for airing countdowns if present
    Widget? badgeOverlay;
    if (m.airingAt != null) {
      badgeOverlay = AiringCountdownBadge(
        airingAt: m.airingAt!,
        aired: m.aired
      );
    }

    final bool isMovieish = isMovieLike(m.type.name, m.title, m.playbackHistory?.durationInMilliseconds);

    String displayTitle = m.title;
    if (isMovieish) {
      displayTitle = displayTitle.replaceAll(RegExp(r'^[Ee]p\s*\d+\s*[\.\-\•]\s*'), '').trim();
    } else if (m.playbackHistory?.episode != null && m.playbackHistory!.episode!.isNotEmpty) {
      displayTitle = 'Ep ${m.playbackHistory!.episode} • $displayTitle';
    }

    return WideContentItem(
      id: m.id,
      title: displayTitle,
      imageUrl: ApiEndpoints.proxyImage(
        m.bannerUrl ?? m.posterUrl,
        // Senior Optimization: 1280px para películas/movie_anime para nitidez en Wide Cards
        width: isMovieish ? 1280 : 800,
      ),
      logoUrl: m.logoUrl,
      subtitle: m.subtitle,
      rating: _formatRating(m.rating),
      badgeOverlay: badgeOverlay,
      onDelete: onItemDelete != null ? () => onItemDelete!(m) : null,
      originalItem: m,
    );
  }

  String? _formatRating(double? rating) {
    if (rating == null || rating == 0) return null;
    return rating.toStringAsFixed(1);
  }
}
