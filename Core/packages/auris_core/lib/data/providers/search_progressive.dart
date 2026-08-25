import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/server/search_result.dart';
import '../repositories/auris_repository.dart';
import '../../core/api/providers.dart';

class SearchParams {
  final String category;
  final String query;

  const SearchParams({required this.category, required this.query});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchParams &&
          category == other.category &&
          query == other.query;

  @override
  int get hashCode => category.hashCode ^ query.hashCode;
}

/// Búsqueda progresiva: pide primero la fase "fast" (fuentes rápidas) y pinta
/// resultados de inmediato; luego pide la fase "slow" (fuentes pesadas, p. ej.
/// AnimeAV1) y mergea sus resultados. Así la pantalla no espera a las fuentes
/// lentas para mostrar contenido.
final searchResultsProvider =
    StateNotifierProvider.autoDispose.family<_SearchResultsNotifier,
        AsyncValue<SearchResponse>, SearchParams>((ref, params) {
  return _SearchResultsNotifier(ref, params);
});

class _SearchResultsNotifier
    extends StateNotifier<AsyncValue<SearchResponse>> {
  final Ref ref;
  final SearchParams params;

  _SearchResultsNotifier(this.ref, this.params)
      : super(const AsyncValue.loading()) {
    _load();
  }

  void _load() async {
    try {
      final repo = ref.read(aurisRepositoryProvider);
      final fast = await repo.search(params.category, params.query, phase: 'fast');
      if (mounted) state = AsyncValue.data(fast);

      final slow = await repo.search(params.category, params.query, phase: 'slow');
      if (!mounted) return;

      final seen = <String>{};
      final merged = <SearchResult>[];
      for (final r in [...fast.results, ...slow.results]) {
        final key = (r.url.isNotEmpty ? r.url : r.title).toLowerCase();
        if (seen.add(key)) merged.add(r);
      }
      state = AsyncValue.data(SearchResponse(
        query: fast.query,
        category: fast.category,
        count: merged.length,
        results: merged,
      ));
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }
}
