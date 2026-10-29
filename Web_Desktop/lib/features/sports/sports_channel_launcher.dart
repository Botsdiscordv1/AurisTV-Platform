import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:auris_core/auris_core.dart';

/// Implementación de [sportsChannelLauncherProvider] para Web / Desktop.
///
/// En navegador y escritorio no es posible inyectar JS en un iframe de otro
/// origen (política mismo-origen), así que el resolvedor de m3u8 no puede
/// ejecutarse. Los eventos se abren con el **reproductor embed** de la
/// plataforma: se lanza la URL del embed (o la directa si la trae) en el
/// navegador del sistema, el mismo comportamiento que `_initEmbedPlayer`
/// (`_launchExternal`) de `PlayerScreen` en Web/Windows.
void launchSportsChannel(
    BuildContext context, ContentSports event, Map<String, dynamic> channel) {
  final embedUrl = channel['embed_url']?.toString().trim() ?? '';
  final directUrl = channel['url']?.toString().trim() ?? '';
  final url = embedUrl.isNotEmpty ? embedUrl : directUrl;

  if (url.isEmpty) {
    debugPrint(
        '[sportsLauncher] canal sin URL reproducible: ${channel['name']}');
    return;
  }

  final uri = Uri.tryParse(url);
  if (uri == null) {
    debugPrint('[sportsLauncher] URL inválida: $url');
    return;
  }
  launchUrl(uri, mode: LaunchMode.externalApplication).catchError((e) {
    debugPrint('[sportsLauncher] no se pudo abrir $url: $e');
    return false;
  });
}
