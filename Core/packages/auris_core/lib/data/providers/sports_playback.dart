import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/content_sports.dart';

/// Acción que cada app inyecta para reproducir un canal de un evento deportivo.
///
/// Core no conoce go_router ni el `PlayerScreen` de cada app, así que la
/// navegación la decide la app. El [channel] puede traer `embed_url`/`referer`
/// (fuente lacancha, que el resolvedor de la app convierte a m3u8) o una `url`
/// directa (backend deportivo 3003), según la fuente del evento.
typedef SportsChannelLauncher = void Function(
  BuildContext context,
  ContentSports event,
  Map<String, dynamic> channel,
);

/// Sobreescribido por cada app en su `ProviderScope`. El default solo loguea,
/// para que un tap no rompa la app si aún no hay player inyectado.
final sportsChannelLauncherProvider = Provider<SportsChannelLauncher>(
  (ref) => (context, event, channel) {
    debugPrint(
      '[sportsChannelLauncher] sin implementar en la app -> '
      'evento="${event.title}" canal=${channel['name']} '
      'url=${channel['url'] ?? channel['embed_url']}',
    );
  },
);
