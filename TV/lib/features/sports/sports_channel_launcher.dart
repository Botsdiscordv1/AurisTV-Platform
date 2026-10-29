import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:auris_core/auris_core.dart';

import 'lacancha_stream_resolver.dart';

const String _kBrowserUa =
    'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36';

/// Implementación de [sportsChannelLauncherProvider] para Android (Móvil).
///
/// - Evento lacancha (`embed_url`): resuelve el m3u8 con un WebView oculto y
///   lo abre en media_kit (`isLive`, headers con el Referer del embed).
/// - Evento con stream directo (backend 3003, `url` ya jugable): lo abre
///   directo.
/// - Si la resolución falla, cae al reproductor embed (`source=ppv`).
void launchSportsChannel(BuildContext context, ContentSports event, Map<String, dynamic> channel) {
  final embedUrl = channel['embed_url']?.toString().trim() ?? '';
  final directUrl = channel['url']?.toString().trim() ?? '';

  if (embedUrl.isNotEmpty) {
    _playResolved(context, event, embedUrl);
    return;
  }
  if (directUrl.isNotEmpty) {
    _openPlayer(context, event, url: directUrl, source: '', headers: null);
    return;
  }
  debugPrint('[sportsLauncher] canal sin URL reproducible: ${channel['name']}');
}

Future<void> _playResolved(BuildContext context, ContentSports event, String embedUrl) async {
  final resolved = await resolveLacanchaStream(context, embedUrl);
  if (!context.mounted) return;
  if (resolved != null) {
    _openPlayer(
      context,
      event,
      url: resolved.m3u8,
      source: '',
      headers: {'Referer': resolved.referer, 'User-Agent': _kBrowserUa},
    );
  } else {
    // Fallback: embed en el reproductor WebView embebido.
    _openPlayer(context, event, url: embedUrl, source: 'ppv', headers: null);
  }
}

void _openPlayer(
  BuildContext context,
  ContentSports event, {
  required String url,
  required String source,
  Map<String, String>? headers,
}) {
  final contentId = M3uParser.stableId(url);
  final uri = Uri(
    path: '/player/$contentId',
    queryParameters: {
      'source': source,
      'url': url,
      'category': 'movie',
      'title': event.title,
      'isLive': '1',
      'skipResume': '1',
      if (event.posterUrl.isNotEmpty) 'posterUrl': event.posterUrl,
      if (event.bannerUrl.isNotEmpty) 'bannerUrl': event.bannerUrl,
      if (headers != null) 'headers': jsonEncode(headers),
    },
  );
  context.push(uri.toString());
}
