import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auris_core.dart';

/// Widget adaptador para plataformas (Web, Móvil, TV).
/// Muestra automáticamente [UpcomingReleaseCountdown] si el contenido no tiene episodios
/// disponibles y tiene fecha de estreno futura o estado de próximo estreno;
/// de lo contrario, muestra el contenido normal de episodios construido por [episodesBuilder].
class AdaptiveEpisodesOrCountdown extends ConsumerWidget {
  final UnifiedDetailParams params;
  final Widget Function(List<EpisodeInfo> episodes) episodesBuilder;

  const AdaptiveEpisodesOrCountdown({
    super.key,
    required this.params,
    required this.episodesBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(unifiedContentProvider(params));
    final episodes = state.episodes.valueOrNull?.response.episodes ?? [];

    // Verificación 2: Si hay episodios disponibles, tienen prioridad absoluta
    if (episodes.isNotEmpty) {
      return episodesBuilder(episodes);
    }

    // Mientras carga, delegamos a episodesBuilder
    if (state.episodes is AsyncLoading || state.detail is AsyncLoading) {
      return episodesBuilder([]);
    }

    // Si no hay episodios, devolvemos directamente el widget Box de cuenta regresiva
    return UpcomingReleaseCountdown.fromState(
      state: state,
      onCountdownZero: () {
        ref.refresh(unifiedContentProvider(params));
      },
    );
  }
}
