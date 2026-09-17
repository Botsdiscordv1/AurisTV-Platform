import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/server/search_result.dart';
import '../repositories/auris_repository.dart';
import 'favorites_provider.dart';
import 'playback_history_provider.dart';
import '../../core/api/providers.dart';
import '../../core/utils/content_logic.dart';
import '../../core/utils/category_utils.dart';

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

/// Motor de Búsqueda Progresiva (Streaming):
/// Escucha un stream NDJSON del servidor y acumula resultados en tiempo real.
/// Realiza deduplicación y fusión de fuentes sobre la marcha.
final searchResultsProvider =
    StateNotifierProvider.autoDispose.family<_SearchResultsNotifier,
        AsyncValue<SearchResponse>, SearchParams>((ref, params) {
  return _SearchResultsNotifier(ref, params);
});

class _SearchResultsNotifier extends StateNotifier<AsyncValue<SearchResponse>> {
  final Ref ref;
  final SearchParams params;
  StreamSubscription? _subscription;
  CancelToken? _cancelToken;
  
  final Map<String, SearchResult> _accumulated = {};

  _SearchResultsNotifier(this.ref, this.params)
      : super(const AsyncValue.loading()) {
    _load();
  }

  void _load() {
    if (params.query.isEmpty) {
      state = AsyncValue.data(SearchResponse(
        query: params.query, 
        category: params.category, 
        count: 0, 
        results: const []
      ));
      return;
    }

    // Senior Hybrid Logic: Carga inmediata de resultados locales (Favoritos e Historial)
    _loadLocalResults();

    final repo = ref.read(aurisRepositoryProvider);
    
    // Senior Active Cancellation: Abortamos el token anterior para que Dio
    // cierre el socket en el servidor inmediatamente.
    _cancelToken?.cancel('Query changed');
    _subscription?.cancel();
    
    _cancelToken = CancelToken();
    _subscription = repo.searchStream(
      params.category, 
      params.query, 
      cancelToken: _cancelToken
    ).listen(
      (responseChunk) {
        _processChunk(responseChunk);
      },
      onError: (e, st) {
        // Ignorar errores de cancelación normal
        if (e is DioException && e.type == DioExceptionType.cancel) return;
        
        if (mounted && _accumulated.isEmpty) {
          state = AsyncValue.error(e, st);
        }
      },
      onDone: () {
        // Opcional: Marcar como finalizado si la UI lo requiere
      },
    );
  }

  void _loadLocalResults() {
    final query = params.query.toLowerCase();
    final cat = params.category.toLowerCase();

    // 1. Filtrar Favoritos
    final favorites = ref.read(favoritesProvider);
    for (final fav in favorites) {
      if (!_matchesLocal(fav.title, fav.category, query, cat)) continue;
      
      final res = SearchResult(
        title: fav.title,
        url: fav.url,
        source: fav.source,
        quality: 'Local',
        thumbnail: fav.posterUrl,
        banner: fav.bannerUrl,
        year: null,
      );
      _accumulated[_fuseKey(res)] = res;
    }

    // 2. Filtrar Historial
    final history = ref.read(playbackHistoryStateProvider).valueOrNull ?? [];
    for (final h in history) {
      if (!_matchesLocal(h.title ?? '', h.category ?? '', query, cat)) continue;
      
      final res = SearchResult(
        title: h.title ?? '',
        url: h.url ?? h.contentId,
        source: h.source ?? '',
        quality: 'Historial', // Senior Fix: Identificador para el resolver de metadatos
        thumbnail: h.posterUrl ?? '',
        banner: h.bannerUrl ?? '',
        year: null,
        kind: h.category, // Mapeo de metadatos para que el label sea correcto
        type: h.category,
        season: h.season,
        progress: h.progress, // Inyectamos el progreso directamente
      );
      // Senior Fix: El historial tiene prioridad sobre la clave para mostrar progreso
      _accumulated[_fuseKey(res)] = res;
    }

    if (_accumulated.isNotEmpty && mounted) {
      state = AsyncValue.data(SearchResponse(
        query: params.query,
        category: params.category,
        count: _accumulated.length,
        results: _accumulated.values.toList(),
      ));
    }
  }

  bool _matchesLocal(String title, String itemCat, String query, String targetCat) {
    if (!title.toLowerCase().contains(query)) return false;
    if (targetCat == 'all') return true;
    
    // Mapeo simple de categorías para el filtro local
    final normalizedItemCat = itemCat.toLowerCase();
    if (targetCat == 'peliculas' || targetCat == 'movie') {
      return normalizedItemCat.contains('movie') || normalizedItemCat.contains('pelicula');
    }
    if (targetCat == 'series') {
      return normalizedItemCat.contains('series') || normalizedItemCat.contains('drama');
    }
    return normalizedItemCat.contains(targetCat);
  }

  void _processChunk(SearchResponse chunk) {
    for (final r in chunk.results) {
      final key = _fuseKey(r);
      final existing = _accumulated[key];

      if (existing == null) {
        _accumulated[key] = r;
      } else {
        // Fusión de fuentes: añadir nuevas fuentes al resultado existente
        final mergedSources = List<SourceItem>.from(existing.sources);
        for (final src in r.sources) {
          if (!mergedSources.any((s) => s.source == src.source && s.url == src.url)) {
            mergedSources.add(src);
          }
        }

        // Mejora de metadatos: preferir el que tenga mejor imagen
        SearchResult better = existing;
        if (r.thumbnail.isNotEmpty && existing.thumbnail.isEmpty) {
          better = r;
        }

        _accumulated[key] = better.copyWith(sources: mergedSources);
      }
    }

    if (mounted) {
      state = AsyncValue.data(SearchResponse(
        query: params.query,
        category: params.category,
        count: _accumulated.length,
        results: _accumulated.values.toList(),
      ));
    }
  }

  String _fuseKey(SearchResult r) {
    final t = r.title.toLowerCase();
    final typeRe = RegExp(r'\b(movie|película|film|ova|special|oav)\b');
    final isMovieish = typeRe.hasMatch(t);
    final franchise = t.replaceAll(typeRe, '').replaceAll(RegExp(r'[^a-z0-9]'), '');
    final cat = inferOpenCategory(r, isMovieish ? 'movie' : 'tv');
    return '$franchise#$cat';
  }

  @override
  void dispose() {
    _cancelToken?.cancel('Notifier disposed');
    _subscription?.cancel();
    super.dispose();
  }
}

