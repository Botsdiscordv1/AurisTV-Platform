import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/source_utils.dart';
import '../../data/providers/content_providers.dart';
import '../../data/models/server/search_result.dart';

/// Fila visible de "chips" de servidor con animación de entrada. Cada chip
/// aparece con fade + scale + leve desplazamiento vertical la primera vez que
/// se renderiza; así, cuando la búsqueda suplementaria (SLOW) agrega nuevas
/// fuentes (p.ej. AV1/AnimeJara), el usuario PERCIBE que "está llegando más
/// contenido" sin necesidad de un banner de carga aparte.
///
/// Es un único widget compartido por Móvil/Web/TV. La selección actual queda
/// resaltada y al tocar un chip se notifica con el índice en `sources`.
class SourceChipsBar extends ConsumerStatefulWidget {
  final List<SearchResult> sources;
  final SearchResult? currentSource;
  final void Function(int) onSourceSelected;
  final Set<String>? unavailableSources;
  final int? season;

  const SourceChipsBar({
    super.key,
    required this.sources,
    this.currentSource,
    required this.onSourceSelected,
    this.unavailableSources,
    this.season,
  });

  @override ConsumerState<SourceChipsBar> createState() => _SourceChipsBarState();
}

class _SourceChipsBarState extends ConsumerState<SourceChipsBar> {
  // Fuentes ya mostradas alguna vez: solo animamos la entrada de las NUEVAS.
  final Set<String> _seen = {};

  List<int> _visibleIndices() {
    final grouped = <String, int>{};
    for (int i = 0; i < widget.sources.length; i++) {
      final s = widget.sources[i];
      final name = simplifySourceName(s.source);
      if (s.url == widget.currentSource?.url) {
        grouped[name] = i;
      } else if (!grouped.containsKey(name)) {
        grouped[name] = i;
      }
    }
    return grouped.values
        .where((i) => widget.unavailableSources?.contains(simplifySourceName(widget.sources[i].source)) != true)
        .where((i) {
          final s = widget.sources[i];
          if (s.source != 'AnimeD23') return true;
          final ok = ref
              .watch(d23SeasonCheckProvider((
                url: s.url,
                title: s.title,
                fullTitle: s.metadataTitle,
                category: 'anime',
                season: widget.season ?? s.season,
                year: s.year,
              )))
              .valueOrNull;
          // Si aún no resuelve (null) lo mostramos; solo ocultamos si es falso.
          return ok != false;
        })
        .toList()
      ..sort((a, b) =>
          sourceDisplayRank(widget.sources[a].source).compareTo(sourceDisplayRank(widget.sources[b].source)));
  }

  @override
  Widget build(BuildContext context) {
    final indices = _visibleIndices();
    if (indices.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final i in indices) ...[
            _SourceChip(
              key: ValueKey(simplifySourceName(widget.sources[i].source)),
              label: simplifySourceName(widget.sources[i].source),
              selected: widget.currentSource != null && widget.sources[i].url == widget.currentSource!.url,
              animate: _seen.add(simplifySourceName(widget.sources[i].source)),
              onTap: () => widget.onSourceSelected(i),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool animate;
  final VoidCallback? onTap;

  const _SourceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.animate,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final begin = animate ? 0.0 : 1.0;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: begin, end: 1.0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 8),
          child: Transform.scale(scale: 0.82 + 0.18 * v, child: child),
        ),
      ),
      child: _chipBody(),
    );
  }

  Widget _chipBody() {
    final bg = selected ? Colors.white : const Color(0xFF32333E);
    final fg = selected ? Colors.black : const Color(0xFFC8C8CE);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
