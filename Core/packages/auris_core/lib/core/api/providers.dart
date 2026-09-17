import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../../data/models/playback_history.dart';
import '../../data/repositories/auris_repository.dart';
import '../../data/repositories/impl/auris_repository_impl.dart';
import '../utils/user_event_tracker.dart';
import 'api_client.dart';

/// Senior Fix: Provider global para el navigator key, permitiendo acceder al 
/// contexto desde los proveedores de datos (necesario para precacheImage).
final navigatorKeyProvider = Provider<GlobalKey<NavigatorState>>((ref) {
  return GlobalKey<NavigatorState>();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

final aurisRepositoryProvider = Provider<AurisRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return AurisRepositoryImpl(client);
});

final userEventTrackerProvider = Provider<UserEventTracker>((ref) {
  final repo = ref.watch(aurisRepositoryProvider);
  return UserEventTracker(repo);
});

final playbackHistoryProvider = Provider((ref) {
  final box = Hive.box('playback_history');
  
  return PlaybackHistoryManager(box);
});

class PlaybackHistoryManager {
  final Box _box;
  PlaybackHistoryManager(this._box);

  Future<void> saveProgress({
    required String contentId,
    int? season,
    String? episode,
    required int positionInMilliseconds,
    int durationInMilliseconds = 0,
  }) async {
    final history = PlaybackHistory(
      contentId: contentId,
      season: season,
      episode: episode,
      positionInMilliseconds: positionInMilliseconds,
      durationInMilliseconds: durationInMilliseconds,
      updatedAt: DateTime.now(),
    );
    await _box.put(history.key, history.toJson());
  }

  PlaybackHistory? getProgress(String contentId, int? season, String? episode) {
    final key = PlaybackHistory.generateKey(contentId, season, episode);
    final data = _box.get(key);
    if (data == null) return null;
    return PlaybackHistory.fromJson(data as Map);
  }

  PlaybackHistory? getLatestWatched(String contentId) {
    final entries = _box.values
        .map((e) => PlaybackHistory.fromJson(e as Map))
        .where((h) => h.contentId == contentId)
        .toList();
    
    if (entries.isEmpty) return null;
    
    entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entries.first;
  }

  Future<void> deleteProgress(String contentId, int? season, String? episode) async {
    final key = PlaybackHistory.generateKey(contentId, season, episode);
    await _box.delete(key);
  }
}
