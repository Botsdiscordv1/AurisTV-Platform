import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auris_core.dart';

abstract class PlaybackHistoryRepository {
  Future<List<PlaybackHistory>> getHistory(String profileId);
  Future<void> saveHistory(PlaybackHistory history);
  Future<void> deleteHistory(String contentId, int? season, String? episode, String profileId);
  Future<void> clearHistory(String contentId, String profileId);
  Future<void> cleanup(String profileId, {int limit = 150});
  Future<void> syncWithCloud(String profileId, String userId);
}

class HivePlaybackHistoryRepository implements PlaybackHistoryRepository {
  final dynamic _box;

  HivePlaybackHistoryRepository(this._box);

  @override
  Future<List<PlaybackHistory>> getHistory(String profileId) async {
    return _box.values
        .map((e) => PlaybackHistory.fromJson(e as Map))
        .where((h) => h.profileId == profileId)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<void> saveHistory(PlaybackHistory history) async {
    await _box.put(history.key, history.toJson());
  }

  @override
  Future<void> deleteHistory(String contentId, int? season, String? episode, String profileId) async {
    final key = PlaybackHistory.generateKey(contentId, season, episode, profileId: profileId);
    await _box.delete(key);
  }

  @override
  Future<void> clearHistory(String contentId, String profileId) async {
    final keysToDelete = _box.keys.where((k) => 
      k.toString().startsWith('$profileId|$contentId|') || 
      k.toString() == '$profileId|$contentId'
    );
    await _box.deleteAll(keysToDelete);
  }

  @override
  Future<void> cleanup(String profileId, {int limit = 150}) async {
    final history = await getHistory(profileId);
    if (history.length > limit) {
      final toDelete = history.sublist(limit);
      final keys = toDelete.map((e) => e.key).toList();
      await _box.deleteAll(keys);
    }
  }

  @override
  Future<void> syncWithCloud(String profileId, String userId) async {
    // Hive no sincroniza solo, lo hace el HybridRepository
  }
}

class SupabasePlaybackHistoryRepository implements PlaybackHistoryRepository {
  final SupabaseClient _client;

  SupabasePlaybackHistoryRepository(this._client);

  @override
  Future<List<PlaybackHistory>> getHistory(String profileId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _client
          .from('playback_history')
          .select()
          .eq('user_id', userId)
          .eq('profile_id', profileId)
          .order('updated_at', ascending: false);

      return (response as List).map((e) {
        final map = Map<String, dynamic>.from(e);
        final metadata = map['metadata'] as Map<String, dynamic>? ?? {};
        return PlaybackHistory(
          contentId: map['content_id'],
          season: map['season'],
          episode: map['episode'],
          positionInMilliseconds: map['position_ms'],
          durationInMilliseconds: map['duration_ms'],
          progress: (map['progress'] as num).toDouble(),
          isCompleted: map['is_completed'],
          updatedAt: DateTime.parse(map['updated_at']),
          profileId: map['profile_id'],
          title: metadata['title'],
          posterUrl: metadata['poster_url'],
          bannerUrl: metadata['banner_url'],
          category: metadata['category'],
          source: metadata['source'],
          url: metadata['url'],
          language: metadata['language'],
        );
      }).toList();
    } catch (e) {
      // ignore: avoid_print
      print('Supabase History Error: $e');
      return [];
    }
  }

  @override
  Future<void> saveHistory(PlaybackHistory history) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      await _client.from('playback_history').upsert({
        'user_id': userId,
        'profile_id': history.profileId,
        'content_id': history.contentId,
        'season': history.season,
        'episode': history.episode,
        'position_ms': history.positionInMilliseconds,
        'duration_ms': history.durationInMilliseconds,
        'progress': history.progress,
        'is_completed': history.isCompleted,
        'updated_at': history.updatedAt.toIso8601String(),
        'metadata': {
          'title': history.title,
          'poster_url': history.posterUrl,
          'banner_url': history.bannerUrl,
          'category': history.category,
          'source': history.source,
          'url': history.url,
          'language': history.language,
        },
      }, onConflict: 'user_id,profile_id,content_id,season,episode');
    } catch (e) {
      // ignore: avoid_print
      print('Supabase Save Error: $e');
    }
  }

  @override
  Future<void> deleteHistory(String contentId, int? season, String? episode, String profileId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    var query = _client
        .from('playback_history')
        .delete()
        .eq('user_id', userId)
        .eq('profile_id', profileId)
        .eq('content_id', contentId);

    if (season != null) query = query.eq('season', season);
    if (episode != null) query = query.eq('episode', episode);

    await query;
  }

  @override
  Future<void> clearHistory(String contentId, String profileId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client
        .from('playback_history')
        .delete()
        .eq('user_id', userId)
        .eq('profile_id', profileId)
        .eq('content_id', contentId);
  }

  @override
  Future<void> cleanup(String profileId, {int limit = 150}) async {
    // Supabase cleanup suele ser manual o por triggers, pero podríamos implementarlo
  }

  @override
  Future<void> syncWithCloud(String profileId, String userId) async {
    // Implementado en Hybrid
  }
}

class HybridPlaybackHistoryRepository implements PlaybackHistoryRepository {
  final HivePlaybackHistoryRepository local;
  final SupabasePlaybackHistoryRepository remote;

  HybridPlaybackHistoryRepository({required this.local, required this.remote});

  @override
  Future<List<PlaybackHistory>> getHistory(String profileId) => local.getHistory(profileId);

  @override
  Future<void> saveHistory(PlaybackHistory history) async {
    await local.saveHistory(history);
    // Remote save is handled asycnronously or triggered via sync
    try {
      await remote.saveHistory(history);
    } catch (e) {
      // ignore
    }
  }

  @override
  Future<void> deleteHistory(String contentId, int? season, String? episode, String profileId) async {
    await local.deleteHistory(contentId, season, episode, profileId);
    try {
      await remote.deleteHistory(contentId, season, episode, profileId);
    } catch (_) {}
  }

  @override
  Future<void> clearHistory(String contentId, String profileId) async {
    await local.clearHistory(contentId, profileId);
    try {
      await remote.clearHistory(contentId, profileId);
    } catch (_) {}
  }

  @override
  Future<void> cleanup(String profileId, {int limit = 150}) async {
    await local.cleanup(profileId, limit: limit);
  }

  @override
  Future<void> syncWithCloud(String profileId, String userId) async {
    try {
      final localData = await local.getHistory(profileId);
      final remoteData = await remote.getHistory(profileId);

      final Map<String, PlaybackHistory> merged = {};

      for (var h in localData) {
        merged[h.key] = h;
      }

      bool localChanged = false;

      for (var rh in remoteData) {
        final lh = merged[rh.key];
        if (lh == null || rh.updatedAt.isAfter(lh.updatedAt)) {
          merged[rh.key] = rh;
          await local.saveHistory(rh);
          localChanged = true;
        } else if (lh.updatedAt.isAfter(rh.updatedAt)) {
          await remote.saveHistory(lh);
        }
      }
      
      // Subir items locales que no están en remoto
      final remoteKeys = remoteData.map((e) => e.key).toSet();
      for (var lh in localData) {
        if (!remoteKeys.contains(lh.key)) {
          await remote.saveHistory(lh);
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error syncing history: $e');
    }
  }
}

