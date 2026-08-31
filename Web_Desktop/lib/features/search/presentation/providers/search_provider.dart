import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'package:auris_core/auris_core.dart';
import '../../data/models/search_history.dart';

final searchRepositoryProvider = Provider<AurisRepository>((ref) {
  return ref.watch(aurisRepositoryProvider);
});

final searchTrendingProvider = FutureProvider<List<SearchResult>>((ref) async {
  // Senior Performance Fix: Retardo inicial para no competir con el Home o las Fuentes (8.8MB ttf)
  // Esto evita el freeze al entrar a la pantalla de búsqueda.
  await Future.delayed(const Duration(milliseconds: 1500));
  
  final repo = ref.read(searchRepositoryProvider);
  
  // Obtenemos tendencias haciendo una búsqueda vacía
  // Senior Tip: Usamos un timeout para que la UI no se quede bloqueada si el server tarda 50s
  final response = await repo.search('anime', '').timeout(
    const Duration(seconds: 12),
    onTimeout: () => const SearchResponse(query: '', category: 'anime', count: 0, results: []),
  );

  // Mapeo limitado: No procesamos los 5.5MB de JSON, solo lo necesario para el TOP 10.
  return response.results.take(10).toList();
});

final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryNotifier, List<SearchHistoryItem>>((ref) {
  final box = Hive.box('search_history');
  final user = ref.watch(authProvider);
  final profileId = user?.activeProfileId ?? 'guest_profile';
  return SearchHistoryNotifier(box, profileId);
});

class SearchHistoryNotifier extends StateNotifier<List<SearchHistoryItem>> {
  final Box _box;
  final String _profileId;

  SearchHistoryNotifier(this._box, this._profileId) : super([]) {
    _loadHistory();
  }

  String get _storageKey => 'items_$_profileId';

  void _loadHistory() {
    final raw = _box.get(_storageKey);
    if (raw == null || raw is! List) {
      state = [];
      return;
    }
    state = raw.map((e) {
      final map = Map<String, dynamic>.from(e as Map);
      return SearchHistoryItem.fromJson(map);
    }).toList();
  }

  Future<void> addQuery(String query) async {
    if (query.trim().isEmpty) return;
    
    final item = SearchHistoryItem(query: query.trim(), timestamp: DateTime.now());
    
    // Eliminar si ya existe el mismo texto (case insensitive) para moverlo al inicio
    final filtered = state.where((e) => e.query.toLowerCase() != query.trim().toLowerCase()).toList();
    
    state = [item, ...filtered].take(8).toList();
    await _box.put(_storageKey, state.map((e) => e.toJson()).toList());
  }

  Future<void> removeQuery(String query) async {
    state = state.where((e) => e.query != query).toList();
    await _box.put(_storageKey, state.map((e) => e.toJson()).toList());
  }

  Future<void> clearHistory() async {
    state = [];
    await _box.delete(_storageKey);
  }
}

final animeTitlesProvider =
    FutureProvider.family<AnimeTitleInfo, String>((ref, query) async {
  final repo = ref.watch(searchRepositoryProvider);
  return repo.getAnimeTitles(query);
});

final movieTitlesProvider =
    FutureProvider.family<MovieTitleInfo, String>((ref, query) async {
  final repo = ref.watch(searchRepositoryProvider);
  return repo.getMovieTitles(query);
});

// Senior: Sugerencias basadas exclusivamente en el historial local (Privacidad y Rapidez)
final searchSuggestionsProvider = StateNotifierProvider<SearchSuggestionsNotifier, List<String>>((ref) {
  final history = ref.watch(searchHistoryProvider);
  return SearchSuggestionsNotifier(history);
});

class SearchSuggestionsNotifier extends StateNotifier<List<String>> {
  final List<SearchHistoryItem> _history;

  SearchSuggestionsNotifier(this._history) : super([]);

  void getSuggestions(String query, String category) {
    if (query.trim().isEmpty) {
      state = [];
      return;
    }

    // Filtramos el historial local para encontrar coincidencias
    final historyMatches = _history
        .where((h) => h.query.toLowerCase().contains(query.toLowerCase()))
        .map((h) => h.query)
        .take(5)
        .toList();
        
    state = historyMatches;
  }
}
