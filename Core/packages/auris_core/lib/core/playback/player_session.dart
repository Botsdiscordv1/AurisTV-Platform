import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import '../../auris_core.dart';

/// Senior Playback Orchestrator — única fuente de verdad para reproducción.
///
/// Antes: `Web/Movil/TV/lib/features/player/presentation/player_screen.dart` (~5600 líneas x3)
/// duplicaban `_currentSource`, `_allTracks`, `_groupedSources`, `_hasInitialized`,
/// `extract` y `history_sync`. Cada fix Web obligaba parche triple.
///
/// Ahora: Este `StateNotifier` centraliza **lógica** (player, tracks, episodios, servidores,
/// idioma, historial) y las 3 plataformas solo renderizan **UI** (hover vs swipe vs D-pad).
/// `playerSessionProvider` es alias tipado de `activePlayerProvider` para migración incremental;
/// a futuro `active_player_provider.dart` quedará como re-export de este archivo.
class PlayerSessionState extends ActivePlayerState {
  PlayerSessionState({
    super.player,
    super.controller,
    super.currentItem,
    super.uiState,
    super.episode,
    super.season,
    super.source,
    super.url,
    super.availableSources,
    super.availableTracks,
    super.availableEpisodes,
    super.selectedTrackIndex,
    super.videoKey,
  });

  factory PlayerSessionState.fromActive(ActivePlayerState s) => PlayerSessionState(
        player: s.player,
        controller: s.controller,
        currentItem: s.currentItem,
        uiState: s.uiState,
        episode: s.episode,
        season: s.season,
        source: s.source,
        url: s.url,
        availableSources: s.availableSources,
        availableTracks: s.availableTracks,
        availableEpisodes: s.availableEpisodes,
        selectedTrackIndex: s.selectedTrackIndex,
        videoKey: s.videoKey,
      );
}

/// Provider único — alias tipado para migración incremental.
/// Por ahora es el mismo `activePlayerProvider` (single source of truth).
/// Futuro: `active_player_provider.dart` se moverá aquí y `activePlayerProvider` será alias inverso.
final playerSessionProvider = activePlayerProvider;

class PlayerSessionNotifier extends ActivePlayerNotifier {
  PlayerSessionNotifier(super.ref);

  /// Switch de episodio sin salir de mini (mantiene `uiState` actual).
  /// Reusa `episodesProvider` cache y `extractVideo` del repo.
  Future<void> switchEpisodeInSession(EpisodeInfo ep) async {
    if (state.currentItem == null || state.source == null) return;
    final pageUrl = ep.url.isNotEmpty ? ep.url : buildEpisodeUrl(state.url ?? '', state.source!, ep.number);
    final category = state.currentItem!.type.name;
    // Optimista: actualiza episodio visible
    await play(
      item: (ep.thumbnail != null && ep.thumbnail!.isNotEmpty)
          ? state.currentItem!.copyWith(bannerUrl: ep.thumbnail)
          : state.currentItem!,
      url: pageUrl,
      episode: ep.number.toString(),
      season: state.season,
      source: state.source,
      triggerOpen: false,
    );
    try {
      final repo = ref.read(aurisRepositoryProvider);
      final extract = await repo.extractVideo(pageUrl, state.source!, category: category);
      final tracks = extract.tracks.where((t) => !t.isDownload).toList();
      String? streamUrl;
      Map<String, String> headers = const {};
      int idx = 0;
      if (tracks.isNotEmpty) {
        // Senior Fix: Usar lógica centralizada de idioma basada en ajustes
        final settings = ref.read(settingsProvider);
        final String pref = settings.preferredLanguage.toLowerCase();
        final String targetType = pref == 'latino' ? 'DUB' : (pref == 'castellano' ? 'CAST' : 'SUB');

        final latIdx = tracks.indexWhere((t) => trackQualityType(t.quality) == 'DUB');
        final castIdx = tracks.indexWhere((t) => trackQualityType(t.quality) == 'CAST');
        final subIdx = tracks.indexWhere((t) => trackQualityType(t.quality) == 'SUB');

        if (targetType == 'DUB' && latIdx >= 0) idx = latIdx;
        else if (targetType == 'CAST' && castIdx >= 0) idx = castIdx;
        else if (subIdx >= 0) idx = subIdx;
        else if (latIdx >= 0) idx = latIdx;
        else if (castIdx >= 0) idx = castIdx;

        streamUrl = tracks[idx].url;
        headers = tracks[idx].headers;
        updateSession(tracks: tracks, selectedIndex: idx);
      } else if (extract.url.isNotEmpty) {
        streamUrl = extract.url;
        headers = extract.headers;
      }
      if (streamUrl != null && streamUrl.isNotEmpty) {
        await state.player?.open(Media(streamUrl, httpHeaders: headers));
        await state.player?.play();
      }
    } catch (e) {
      debugPrint('[player_session] switchEpisode fail: $e');
    }
  }

  /// Seek interactivo compartido (mini progress bar y full)
  Future<void> seekTo(double progress) async {
    final dur = state.player?.state.duration.inMilliseconds ?? 0;
    if (dur <= 0) return;
    final seekMs = (progress.clamp(0.0, 1.0) * dur).toInt();
    await state.player?.seek(Duration(milliseconds: seekMs));
  }
}
