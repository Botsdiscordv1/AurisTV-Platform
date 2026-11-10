import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/widgets/content_sport_screen.dart';
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

/// Acción que cada app inyecta para abrir la ficha de un evento deportivo.
///
/// Core no conoce go_router, así que la ruta limpia (o el `Navigator.push`
/// de siempre) la decide la app. El default conserva el comportamiento
/// previo: un `MaterialPageRoute` a pantalla completa.
typedef SportsDetailOpener = void Function(
  BuildContext context,
  ContentSports event,
  ValueChanged<Map<String, dynamic>>? onChannelSelected,
);

/// Sobreescribido por cada app en su `ProviderScope`.
final sportsDetailOpenerProvider = Provider<SportsDetailOpener>(
  (ref) => (context, event, onChannelSelected) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContentSportScreen(
          event: event,
          onChannelSelected: onChannelSelected,
        ),
      ),
    );
  },
);
