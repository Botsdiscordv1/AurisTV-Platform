import 'server/search_result.dart';
import 'media_item.dart';
import 'package:flutter/material.dart';
import '../../presentation/widgets/content_sport_screen.dart';
import '../../core/utils/safe_tap.dart';

/// Modelo exclusivo para eventos deportivos en vivo y próximos (`content_sports`),
/// adaptado a los endpoints beta del servidor de deportes (/api/events y /api/home/hero).
class ContentSports {
  final String id;
  final String title;
  final String? sportLabel;
  final String? league;
  final List<String> teams;
  final List<Map<String, dynamic>> channels;
  final String posterUrl;
  final String bannerUrl;
  final String? synopsis;
  final double viewers;
  final int? airingAt;
  final String source;
  final SearchResult? card;

  const ContentSports({
    required this.id,
    required this.title,
    this.sportLabel,
    this.league,
    this.teams = const [],
    this.channels = const [],
    required this.posterUrl,
    required this.bannerUrl,
    this.synopsis,
    this.viewers = 0.0,
    this.airingAt,
    this.source = 'ppv',
    this.card,
  });

  factory ContentSports.fromJson(Map<String, dynamic> json) {
    final channelsList = json['channels'] as List?;
    final parsedChannels = (channelsList != null)
        ? channelsList.map((c) => Map<String, dynamic>.from(c as Map)).toList()
        : <Map<String, dynamic>>[];

    final rawTeams = json['teams'];
    List<String> parsedTeams = [];
    if (rawTeams is List) {
      parsedTeams = rawTeams.map((e) => e.toString()).toList();
    }

    return ContentSports(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Evento deportivo',
      sportLabel: json['sportLabel']?.toString() ?? json['sport']?.toString(),
      league: json['league']?.toString(),
      teams: parsedTeams,
      channels: parsedChannels,
      posterUrl: json['posterUrl']?.toString() ?? json['thumbnail']?.toString() ?? '',
      bannerUrl: json['bannerUrl']?.toString() ?? json['thumbnail']?.toString() ?? json['posterUrl']?.toString() ?? '',
      synopsis: json['synopsis']?.toString(),
      viewers: (json['viewers'] as num?)?.toDouble() ?? 0.0,
      airingAt: json['airingAt'] as int?,
      source: json['source']?.toString() ?? 'ppv',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'sportLabel': sportLabel,
    'league': league,
    'teams': teams,
    'channels': channels,
    'posterUrl': posterUrl,
    'bannerUrl': bannerUrl,
    'synopsis': synopsis,
    'viewers': viewers,
    'airingAt': airingAt,
    'source': source,
  };
}

extension ContentSportsToMediaItem on ContentSports {
  MediaItem toMediaItem() {
    return MediaItem(
      id: id,
      title: title,
      type: MediaType.movie,
      year: DateTime.now().year,
      posterUrl: posterUrl,
      bannerUrl: bannerUrl,
      rating: viewers,
      synopsis: synopsis ?? (league != null ? 'Liga: $league' : 'Evento deportivo'),
      subtitle: league ?? (teams.isNotEmpty ? teams.join(' vs ') : null),
      genres: sportLabel != null ? [sportLabel!] : [],
      detailUrl: channels.isNotEmpty ? channels.first['url']?.toString() : '',
      source: source,
      channels: channels,
    );
  }
}

bool isSportsItemMetadata({
  required String title,
  String? source,
  List<Map<String, dynamic>>? channels,
  String? category,
}) {
  final s = (source ?? '').toLowerCase();
  final c = (category ?? '').toLowerCase();
  final t = title.toLowerCase();
  return s == 'ppv' || s == 'sport' || s == 'live' || c == 'live' ||
      (channels != null && channels.isNotEmpty) ||
      t.contains('vs') || t.contains('championship') || t.contains('cup') || t.contains('league');
}

void handleCardTapOrSportsNavigation(BuildContext context, {
  required String title,
  required String imageUrl,
  VoidCallback? onTap,
  String? source,
  List<Map<String, dynamic>>? channels,
  String? subtitle,
  String? id,
}) {
  if (isSportsItemMetadata(title: title, source: source, channels: channels)) {
    debugPrint('[AurisCore] Intercepted sports card tap -> Opening ContentSportScreen directly for: "$title"');
    final sportsEvent = ContentSports(
      id: id ?? title,
      title: title,
      posterUrl: imageUrl,
      bannerUrl: imageUrl,
      channels: (channels != null && channels.isNotEmpty)
          ? channels
          : [{'name': 'Canal Principal', 'url': ''}],
      source: source ?? 'ppv',
      league: subtitle,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContentSportScreen(event: sportsEvent),
      ),
    );
    return;
  }
  if (onTap != null) {
    SafeTap.run(onTap);
  }
}


