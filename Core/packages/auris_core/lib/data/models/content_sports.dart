import 'server/search_result.dart';
import 'media_item.dart';
import 'package:flutter/material.dart';
import '../../presentation/widgets/content_sport_screen.dart';
import '../../core/utils/safe_tap.dart';

/// Modelo exclusivo para eventos deportivos en vivo y próximos (`content_sports`),
/// adaptado a los endpoints del servidor de deportes
/// (`/api/events`, `/api/home/hero`, `/api/home/sections`).
///
/// El BACKEND calcula y envía el estado real (`isLive`, `status`), la fecha/hora
/// de inicio (`date`, `startsAt*`), la liga/deporte (`league`, `sportLabel`,
/// `leagueLogo`) y los canales decorados con logo (`channels[i].logo`/`initials`).
/// El frontend SOLO debe pintar estos campos y NUNCA recalcular isLive ni fechas.
class ContentSports {
  final String id;
  final String title;
  final String? sport;          // key normalizado: 'futbol', 'nfl', 'baloncesto'…
  final String? sportLabel;     // etiqueta visible: 'Fútbol', 'Fútbol Am.'…
  final String? league;         // 'Ligue 1', 'NFL'…
  final String? leagueLogo;     // URL del logo de la liga (o null)
  final List<String> teams;
  final List<Map<String, dynamic>> channels;  // con logo/logoKey/initials decorados
  final String posterUrl;
  final String bannerUrl;       // thumbnail de mejor calidad (fallback a posterUrl)
  final List<String>? colors;   // colores de los equipos (acentos de la tarjeta)
  final String? synopsis;
  final double viewers;
  final String? date;           // 'YYYY-MM-DD' (fecha del encuentro)
  final int? startsAtMs;        // epoch ms del inicio
  final String? startsAt;       // ISO del inicio
  final int? endsAtMs;
  final String? endsAt;
  final int? durationMin;
  final bool isLive;            // estado REAL calculado por el backend
  final bool alwaysLive;
  final String? status;         // 'EN VIVO' | 'PRÓXIMO' | 'FINALIZADO'
  final int? airingAt;          // compatibilidad hacia atrás
  final String source;
  final SearchResult? card;

  const ContentSports({
    required this.id,
    required this.title,
    this.sport,
    this.sportLabel,
    this.league,
    this.leagueLogo,
    this.teams = const [],
    this.channels = const [],
    required this.posterUrl,
    required this.bannerUrl,
    this.colors,
    this.synopsis,
    this.viewers = 0.0,
    this.date,
    this.startsAtMs,
    this.startsAt,
    this.endsAtMs,
    this.endsAt,
    this.durationMin,
    this.isLive = false,
    this.alwaysLive = false,
    this.status,
    this.airingAt,
    this.source = 'ppv',
    this.card,
  });

  /// Estado en vivo efectivo (el backend ya lo resolvió; este getter solo
  /// respalda datos viejos que no traigan `isLive`).
  bool get effectiveIsLive => isLive || alwaysLive;

  /// Fecha/hora de inicio como DateTime (usa startsAtMs, si no startsAt).
  DateTime? get startsAtDate {
    if (startsAtMs != null) return DateTime.fromMillisecondsSinceEpoch(startsAtMs!);
    if (startsAt != null) return DateTime.tryParse(startsAt!);
    return null;
  }

  /// Etiqueta de estado lista para pintar (usa la del backend si existe).
  String get statusLabel {
    if (status != null && status!.isNotEmpty) return status!;
    return effectiveIsLive ? 'EN VIVO' : 'PRÓXIMO';
  }

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

    final rawColors = json['colors'];
    List<String>? parsedColors;
    if (rawColors is List && rawColors.isNotEmpty) {
      parsedColors = rawColors.map((e) => e.toString()).toList();
    }

    final poster = json['posterUrl']?.toString() ?? json['thumbnail']?.toString() ?? '';
    final banner = json['bannerUrl']?.toString() ??
        json['thumbnail']?.toString() ??
        json['posterUrl']?.toString() ??
        '';

    // El backend envía isLive/status/date/startsAt. Se parsean con fallbacks
    // para tolerar respuestas viejas que no los traigan.
    final bool isLive = json['isLive'] == true;
    final bool alwaysLive = json['alwaysLive'] == true;
    final String? status = json['status']?.toString();

    return ContentSports(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Evento deportivo',
      sport: json['sport']?.toString(),
      sportLabel: json['sportLabel']?.toString() ?? json['sport']?.toString(),
      league: json['league']?.toString(),
      leagueLogo: json['leagueLogo']?.toString(),
      teams: parsedTeams,
      channels: parsedChannels,
      posterUrl: poster,
      bannerUrl: banner,
      colors: parsedColors,
      synopsis: json['synopsis']?.toString(),
      viewers: (json['viewers'] as num?)?.toDouble() ?? 0.0,
      date: json['date']?.toString(),
      startsAtMs: (json['startsAtMs'] as num?)?.toInt(),
      startsAt: json['startsAt']?.toString(),
      endsAtMs: (json['endsAtMs'] as num?)?.toInt(),
      endsAt: json['endsAt']?.toString(),
      durationMin: (json['durationMin'] as num?)?.toInt(),
      isLive: isLive,
      alwaysLive: alwaysLive,
      status: status,
      airingAt: json['airingAt'] as int?,
      source: json['source']?.toString() ?? 'ppv',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'sport': sport,
    'sportLabel': sportLabel,
    'league': league,
    'leagueLogo': leagueLogo,
    'teams': teams,
    'channels': channels,
    'posterUrl': posterUrl,
    'bannerUrl': bannerUrl,
    'colors': colors,
    'synopsis': synopsis,
    'viewers': viewers,
    'date': date,
    'startsAtMs': startsAtMs,
    'startsAt': startsAt,
    'endsAtMs': endsAtMs,
    'endsAt': endsAt,
    'durationMin': durationMin,
    'isLive': isLive,
    'alwaysLive': alwaysLive,
    'status': status,
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


