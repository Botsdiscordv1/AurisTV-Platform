import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auris_core/auris_core.dart';
import 'watch_screen_base.dart';

/// Pantalla WatchScreen para Web.
///
/// Reutiliza `WatchScreenBase` (UI compartida) e inyecta el `PlayerScreen`
/// de Web como el widget de reproductor.
class WatchScreen extends ConsumerWidget {
  const WatchScreen({
    super.key,
    required this.contentId,
    required this.sourceUrl,
    required this.source,
    this.episode,
    this.season,
    this.serverName,
    this.category,
    this.title,
    this.metadataTitle,
    this.episodeTitle,
    this.posterUrl,
    this.bannerUrl,
    this.logoUrl,
    this.year,
    this.certification,
    this.totalEpisodes,
    this.skipResume = false,
    this.isLive = false,
    this.playlistEpisodes,
    this.playlistIndex = 0,
    this.playerWidget,
    this.synopsis,
    this.onNextEpisode,
    this.onPreviousEpisode,
    this.onEpisodeSelected,
  });

  final String contentId;
  final String sourceUrl;
  final String source;
  final String? episode;
  final int? season;
  final String? serverName;
  final String? category;
  final String? title;
  final String? metadataTitle;
  final String? episodeTitle;
  final String? posterUrl;
  final String? bannerUrl;
  final String? logoUrl;
  final int? year;
  final String? certification;
  final int? totalEpisodes;
  final bool skipResume;
  final bool isLive;
  final List<EpisodeInfo>? playlistEpisodes;
  final int playlistIndex;
  final Widget? playerWidget;
  final String? synopsis;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onPreviousEpisode;
  final ValueChanged<EpisodeInfo>? onEpisodeSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return WatchScreenBase(
      contentId: contentId,
      sourceUrl: sourceUrl,
      source: source,
      episode: episode,
      season: season,
      serverName: serverName,
      category: category,
      title: title,
      metadataTitle: metadataTitle,
      episodeTitle: episodeTitle,
      posterUrl: posterUrl,
      bannerUrl: bannerUrl,
      logoUrl: logoUrl,
      year: year,
      certification: certification,
      totalEpisodes: totalEpisodes,
      skipResume: skipResume,
      isLive: isLive,
      playlistEpisodes: playlistEpisodes,
      playlistIndex: playlistIndex,
      playerWidget: playerWidget ?? const Center(child: CircularProgressIndicator()),
      synopsis: synopsis,
      onNextEpisode: onNextEpisode,
      onPreviousEpisode: onPreviousEpisode,
      onEpisodeSelected: onEpisodeSelected,
    );
  }
}