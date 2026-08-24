import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../../auris_core.dart';
import 'auth_provider.dart';

final playbackHistoryStateProvider = AsyncNotifierProvider<PlaybackHistoryNotifier, List<PlaybackHistory>>(() {
  return PlaybackHistoryNotifier();
});

class PlaybackHistoryNotifier extends AsyncNotifier<List<PlaybackHistory>> {
  late Box _box;
  Timer? _throttleTimer;
  PlaybackHistory? _pendingSave;
  
  final Map<String, int> _lastSavedPositionsMs = {};

  @override
  FutureOr<List<PlaybackHistory>> build() async {
    _box = Hive.box('playback_history');
    final user = ref.watch(authProvider);
    final profileId = user?.activeProfileId ?? 'guest_profile';
    return _loadAll(profileId);
  }

  List<PlaybackHistory> _loadAll(String profileId) {
    return _box.values
        .map((e) => PlaybackHistory.fromJson(e as Map))
        .where((h) => h.profileId == profileId)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
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

    final existingData = _box.get(key);
    PlaybackHistory? existingHistory;
    if (existingData != null) {
      existingHistory = PlaybackHistory.fromJson(existingData as Map);
    }
    
    final int lastSavedMs = existingHistory?.positionInMilliseconds ?? 0;
    final int jumpDiff = (finalPositionMs - lastSavedMs).abs();
    
    if (jumpDiff > 300000 && !force && !completed) {
      return;
    }

    if (!force) {
      final lastPersistedPos = _lastSavedPositionsMs[key] ?? -10000;
      final diff = (finalPositionMs - lastPersistedPos).abs();
      if (diff < 10000 && !completed) return;
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

  Future<void> _savePending({bool notify = true}) async {
    if (_pendingSave == null) return;
    
    final history = _pendingSave!;
    _pendingSave = null;
    final key = history.key;
    _lastSavedPositionsMs[key] = history.positionInMilliseconds;

    await _box.put(key, history.toJson());
    
    if (notify) {
      final user = ref.read(authProvider);
      state = AsyncData(_loadAll(user?.activeProfileId ?? 'guest_profile'));
    }
  }

  PlaybackHistory? getProgress(String contentId, int? season, String? episode) {
    final user = ref.read(authProvider);
    final profileId = user?.activeProfileId ?? 'guest_profile';
    final key = PlaybackHistory.generateKey(contentId, season, episode, profileId: profileId);
    final data = _box.get(key);
    if (data == null) return null;
    final history = PlaybackHistory.fromJson(data as Map);
    return history.isFinished ? null : history;
  }

  PlaybackHistory? getLatestWatched(String contentId) {
    final user = ref.read(authProvider);
    final entries = _loadAll(user?.activeProfileId ?? 'guest_profile').where((h) => h.contentId == contentId).toList();
    if (entries.isEmpty) return null;
    return entries.first;
  }

  Future<void> deleteProgress(String contentId, int? season, String? episode) async {
    final user = ref.read(authProvider);
    final profileId = user?.activeProfileId ?? 'guest_profile';
    final key = PlaybackHistory.generateKey(contentId, season, episode, profileId: profileId);
    await _box.delete(key);
    state = AsyncData(_loadAll(profileId));
  }

  Future<void> clearContentHistory(String contentId) async {
    final user = ref.read(authProvider);
    final profileId = user?.activeProfileId ?? 'guest_profile';
    final keysToDelete = _box.keys.where((k) => k.toString().startsWith('$profileId|$contentId|') || k.toString() == '$profileId|$contentId');
    await _box.deleteAll(keysToDelete);
    state = AsyncData(_loadAll(profileId));
  }

  void flush() {
    if (_pendingSave != null) {
      _savePending(notify: true);
    }
    _throttleTimer?.cancel();
  }
}
