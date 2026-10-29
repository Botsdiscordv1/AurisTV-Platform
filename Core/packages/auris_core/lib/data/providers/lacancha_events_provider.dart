import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sources/lacancha_events_source.dart';
import '../models/content_sports.dart';

/// Instancia compartida de la fuente de eventos de lacancha.tv.
final lacanchaEventsSourceProvider = Provider<LacanchaEventsSource>(
  (ref) => LacanchaEventsSource(),
);

/// Eventos en vivo de lacancha.tv (catálogo del home `/es/en-vivo`).
///
/// Fuente primaria de la categoría "live" del Home: sustituye la dependencia
/// del servidor deportivo propio (puerto 3003). Devuelve lista vacía si la
/// red o el HTML fallan, para que el consumidor pueda aplicar su fallback.
final lacanchaLiveEventsProvider = FutureProvider<List<ContentSports>>((ref) async {
  final source = ref.watch(lacanchaEventsSourceProvider);
  return source.fetchLiveEvents();
});
