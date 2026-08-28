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

  @override
  void initState() {
    super.initState();
    // Registramos las fuentes iniciales como "vistas" para que no se animen al entrar
    for (final s in widget.sources) {
      _seen.add(simplifySourceName(s.source));
    }
  }

  List<int> _groupedIndices() {
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
    final indices = grouped.values
        .where((i) => widget.unavailableSources?.contains(simplifySourceName(widget.sources[i].source)) != true)
        .toList();
    
    indices.sort((a, b) =>
          sourceDisplayRank(widget.sources[a].source).compareTo(sourceDisplayRank(widget.sources[b].source)));
    return indices;
  }

  @override
  Widget build(BuildContext context) {
    final indices = _groupedIndices();
    if (indices.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final i in indices) ...[
              Builder(builder: (context) {
                final name = simplifySourceName(widget.sources[i].source);
                final bool isNew = !_seen.contains(name);
                if (isNew) {
                  // Agregamos a seen de forma segura en el siguiente frame si es necesario, 
                  // pero para la lógica de animación, basta con saber que no estaba.
                  // Senior Elite: Usamos un post-frame para actualizar el Set sin romper el build.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !_seen.contains(name)) {
                      setState(() => _seen.add(name));
                    }
                  });
                }

                return _SourceItem(
                  key: ValueKey('item_${widget.sources[i].source}_${widget.sources[i].url}'),
                  source: widget.sources[i],
                  isSelected: widget.currentSource != null && widget.sources[i].url == widget.currentSource!.url,
                  animate: isNew,
                  season: widget.season,
                  onTap: () => widget.onSourceSelected(i),
                );
              }),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _SourceItem extends ConsumerWidget {
  final SearchResult source;
  final bool isSelected;
  final bool animate;
  final int? season;
  final VoidCallback onTap;

  const _SourceItem({
    super.key,
    required this.source,
    required this.isSelected,
    required this.animate,
    this.season,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Senior Clean Fix: El watch de disponibilidad solo ocurre aquí, para el item específico.
    if (source.source == 'AnimeD23') {
      final ok = ref.watch(d23SeasonCheckProvider((
        url: source.url,
        title: source.title,
        fullTitle: source.metadataTitle,
        category: 'anime',
        season: season ?? source.season,
        year: source.year,
      ))).valueOrNull;
      
      if (ok == false) return const SizedBox.shrink();
    }

    final label = simplifySourceName(source.source);
    
    // Si no animamos, empezamos directamente en 1.0
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: animate ? 0.0 : 1.0, end: 1.0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(opacity: v, child: Transform.scale(scale: 0.95 + (0.05 * v), child: child)),
      child: _chipBody(label),
    );
  }

  Widget _chipBody(String label) {
    final bg = isSelected ? Colors.white : Colors.transparent;
    final fg = isSelected ? Colors.black : const Color(0xFFC8C8CE);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: Colors.white.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
