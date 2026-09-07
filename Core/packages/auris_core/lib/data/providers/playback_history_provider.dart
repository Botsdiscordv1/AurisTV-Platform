import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auris_core.dart';
import 'auth_provider.dart';

final playbackHistoryRepositoryProvider = Provider<PlaybackHistoryRepository>((ref) {
  final box = Hive.box('playback_history');
  final local = HivePlaybackHistoryRepository(box);
  final remote = SupabasePlaybackHistoryRepository(Supabase.instance.client);
  
  return HybridPlaybackHistoryRepository(local: local, remote: remote);
});

final playbackHistoryStateProvider = AsyncNotifierProvider<PlaybackHistoryNotifier, List<PlaybackHistory>>(() {
  return PlaybackHistoryNotifier();
});

/// Provider especializado para el carrusel de "Continuar Viendo"
/// Filtra contenidos completados, agrupa por serie para mostrar solo el último episodio
/// y mantiene el orden cronológico.
final continueWatchingProvider = Provider<AsyncValue<List<PlaybackHistory>>>((ref) {
  final historyAsync = ref.watch(playbackHistoryStateProvider);
  
  return historyAsync.whenData((list) {
    final Set<String> seenContentIds = {};
    return list.where((h) {
      if (h.isCompleted) return false;
      // Senior Logic: Solo mostramos la entrada más reciente para cada serie/contenido
      if (seenContentIds.contains(h.contentId)) return false;
      seenContentIds.add(h.contentId);
      return true;
    }).toList();
  });
});

class PlaybackHistoryNotifier extends AsyncNotifier<List<PlaybackHistory>> {
  Timer? _throttleTimer;
  PlaybackHistory? _pendingSave;
  
  final Map<String, int> _lastSavedPositionsMs = {};
  
  // Cache en memoria para actualizaciones rápidas sin recargar todo de Hive
  List<PlaybackHistory> _memoryCache = [];

  @override
  FutureOr<List<PlaybackHistory>> build() async {
    final repository = ref.watch(playbackHistoryRepositoryProvider);
    final user = ref.watch(authProvider);
    
    // Senior Fix: Si hay una sesión activa en Supabase pero el authProvider aún es null,
    // mantenemos el estado en LOADING.
    if (user == null && Supabase.instance.client.auth.currentSession != null) {
      final completer = Completer<List<PlaybackHistory>>();
      return completer.future;
    }

    final profileId = user?.activeProfileId ?? 'guest_profile';
    
    // Le damos un pequeño margen a Hive para asegurar que el box esté listo 
    // y poblado tras el Hot Restart.
    final history = await repository.getHistory(profileId);
    _memoryCache = history;

    if (user != null && user.email != null) {
      _triggerSync(repository, profileId, user.id).ignore();
    }

    return _memoryCache;
  }

  Future<void> _triggerSync(PlaybackHistoryRepository repository, String profileId, String userId) async {
    await repository.syncWithCloud(profileId, userId);
    // Recargar memoria después de sync si algo cambió en la nube
    _memoryCache = await repository.getHistory(profileId);
    state = AsyncData(List.from(_memoryCache));
  }

  void updatePosition({
    required String contentId,
    int? season,
    String? episode,
    required int positionMs,
    required int durationMs,
    String? title,
    String? posterUrl,
    String? bannerUrl,
    String? category,
    String? source,
    String? url,
    String? language,
    List<SearchResult>? alternativeSources,
    bool force = false,
  }) {
    final user = ref.read(authProvider);
    final profileId = user?.activeProfileId ?? 'guest_profile';

    final double calcProgress = durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0) : 0.0;
    final bool completed = calcProgress > 0.95;
    
    int finalPositionMs = completed ? durationMs : positionMs;
    double finalProgress = completed ? 1.0 : calcProgress;

    final key = PlaybackHistory.generateKey(contentId, season, episode, profileId: profileId);

    // Buscar en caché primero
    final existingHistory = _memoryCache.cast<PlaybackHistory?>().firstWhere(
      (h) => h?.key == key, 
      orElse: () => null
    );
    
    // Eliminamos la restricción de jumpDiff > 300000 para permitir seeks manuales
    // Pero mantenemos un pequeño throttle para no saturar si no hay cambios significativos
    if (!force) {
      final lastPersistedPos = _lastSavedPositionsMs[key] ?? -10000;
      final diff = (finalPositionMs - lastPersistedPos).abs();
      // Si el video es muy corto, bajamos el umbral a 5s, si no 10s
      final threshold = durationMs < 60000 ? 5000 : 10000;
      if (diff < threshold && !completed) return;
    }

    final history = PlaybackHistory(
      contentId: contentId,
      season: season,
      episode: episode,
      positionInMilliseconds: finalPositionMs,
      durationInMilliseconds: durationMs,
      updatedAt: DateTime.now(),
      progress: finalProgress,
      isCompleted: completed,
      title: title ?? existingHistory?.title,
      posterUrl: posterUrl ?? existingHistory?.posterUrl,
      bannerUrl: bannerUrl ?? existingHistory?.bannerUrl,
      category: category ?? existingHistory?.category,
      source: source ?? existingHistory?.source,
      url: url ?? existingHistory?.url,
      language: language ?? existingHistory?.language,
      alternativeSources: alternativeSources ?? existingHistory?.alternativeSources,
      profileId: profileId,
    );

    _pendingSave = history;
    
    // Actualización optimista de la memoria
    _updateMemoryCache(history);

    if (force) {
      _savePending(notify: true);
      return;
    }

    if (_throttleTimer == null || !_throttleTimer!.isActive) {
      _savePending();
      _throttleTimer = Timer(const Duration(seconds: 2), () {
        if (_pendingSave != null) _savePending();
      });
    }
  }

  void _updateMemoryCache(PlaybackHistory history) {
    final index = _memoryCache.indexWhere((h) => h.key == history.key);
    if (index != -1) {
      _memoryCache[index] = history;
    } else {
      _memoryCache.insert(0, history);
    }
    
    // Re-ordenar por fecha de actualización
    _memoryCache.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    
    // Notificar al estado (esto hará que la UI se actualice)
    state = AsyncData(List.from(_memoryCache));
  }

  Future<void> _savePending({bool notify = true}) async {
    if (_pendingSave == null) return;
    
    final history = _pendingSave!;
    _pendingSave = null;
    final key = history.key;
    _lastSavedPositionsMs[key] = history.positionInMilliseconds;

    final repository = ref.read(playbackHistoryRepositoryProvider);
    await repository.saveHistory(history);
    
    // Aplicar cleanup cada vez que guardamos para mantener la DB limpia
    final user = ref.read(authProvider);
    if (user != null) {
      await repository.cleanup(user.activeProfileId ?? 'guest_profile');
    }
  }

  PlaybackHistory? getProgress(String contentId, int? season, String? episode) {
    final user = ref.read(authProvider);
    final profileId = user?.activeProfileId ?? 'guest_profile';
    final key = PlaybackHistory.generateKey(contentId, season, episode, profileId: profileId);
    
    final history = _memoryCache.cast<PlaybackHistory?>().firstWhere(
      (h) => h?.key == key, 
      orElse: () => null
    );
    
    return history?.isFinished == true ? null : history;
  }

  PlaybackHistory? getLatestWatched(String contentId) {
    final entries = _memoryCache.where((h) => h.contentId == contentId).toList();
    if (entries.isEmpty) return null;
    return entries.first;
  }

  Future<void> deleteProgress(String contentId, int? season, String? episode) async {
    final user = ref.read(authProvider);
    final profileId = user?.activeProfileId ?? 'guest_profile';
    final repository = ref.read(playbackHistoryRepositoryProvider);
    
    await repository.deleteHistory(contentId, season, episode, profileId);
    
    final key = PlaybackHistory.generateKey(contentId, season, episode, profileId: profileId);
    _memoryCache.removeWhere((h) => h.key == key);
    state = AsyncData(List.from(_memoryCache));
  }

  Future<void> clearContentHistory(String contentId) async {
    final user = ref.read(authProvider);
    final profileId = user?.activeProfileId ?? 'guest_profile';
    final repository = ref.read(playbackHistoryRepositoryProvider);
    
    await repository.clearHistory(contentId, profileId);
    
    _memoryCache.removeWhere((h) => h.contentId == contentId && h.profileId == profileId);
    state = AsyncData(List.from(_memoryCache));
  }

  void flush() {
    if (_pendingSave != null) {
      _savePending(notify: true);
    }
    _throttleTimer?.cancel();
  }
}
