import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:collection/collection.dart';
import '../../auris_core.dart';
import 'playback_history_provider.dart';

enum PlayerUIState { none, mini, full, pip }

class ActivePlayerState {
  final Player? player;
  final VideoController? controller;
  final MediaItem? currentItem;
  final PlayerUIState uiState;
  final String? episode;
  final int? season;
  final String? source;
  final String? url;
  
  // Senior: Session Persistence & Continuity Data
  final List<SearchResult> availableSources;
  final List<VideoTrackOption> availableTracks;
  final List<EpisodeInfo> availableEpisodes; // Senior: Nueva lista de episodios persistente
  final int selectedTrackIndex;
  final GlobalKey videoKey;

  ActivePlayerState({
    this.player,
    this.controller,
    this.currentItem,
    this.uiState = PlayerUIState.none,
    this.episode,
    this.season,
    this.source,
    this.url,
    this.availableSources = const [],
    this.availableTracks = const [],
    this.availableEpisodes = const [],
    this.selectedTrackIndex = 0,
    GlobalKey? videoKey,
  }) : videoKey = videoKey ?? GlobalKey();

  ActivePlayerState copyWith({
    Player? player,
    VideoController? controller,
    MediaItem? currentItem,
    PlayerUIState? uiState,
    String? episode,
    int? season,
    String? source,
    String? url,
    List<SearchResult>? availableSources,
    List<VideoTrackOption>? availableTracks,
    List<EpisodeInfo>? availableEpisodes,
    int? selectedTrackIndex,
  }) {
    return ActivePlayerState(
      player: player ?? this.player,
      controller: controller ?? this.controller,
      currentItem: currentItem ?? this.currentItem,
      uiState: uiState ?? this.uiState,
      episode: episode ?? this.episode,
      season: season ?? this.season,
      source: source ?? this.source,
      url: url ?? this.url,
      availableSources: availableSources ?? this.availableSources,
      availableTracks: availableTracks ?? this.availableTracks,
      availableEpisodes: availableEpisodes ?? this.availableEpisodes,
      selectedTrackIndex: selectedTrackIndex ?? this.selectedTrackIndex,
      videoKey: videoKey,
    );
  }
}

final activePlayerProvider = StateNotifierProvider<ActivePlayerNotifier, ActivePlayerState>((ref) {
  return ActivePlayerNotifier(ref);
});

class ActivePlayerNotifier extends StateNotifier<ActivePlayerState> {
  final Ref ref;
  StreamSubscription? _posSubscription;
  String? _currentSessionId;

  ActivePlayerNotifier(this.ref) : super(ActivePlayerState());

  void initPlayerIfNeeded() {
    if (state.player != null) return;

    final player = Player(
      configuration: const PlayerConfiguration(
        bufferSize: 32 * 1024 * 1024,
      ),
    );
    
    // Senior Tuning: Optimizamos el motor para carga estable
    try {
      if (!kIsWeb) {
        final platform = player.platform as dynamic;
        platform.setProperty('hwdec', 'auto-safe');
      }
    } catch (_) {}

    final controller = VideoController(player);
    
    // Senior Strategy: Actualizamos el estado síncronamente para evitar que llamadas rápidas
    // sucesivas a initPlayerIfNeeded creen múltiples instancias de hardware (Audio Doble).
    state = state.copyWith(player: player, controller: controller);
    _setupHistorySync();
  }

  void _setupHistorySync() {
    _posSubscription?.cancel();
    _posSubscription = state.player?.stream.position.listen((pos) {
      final item = state.currentItem;
      if (item != null && state.uiState != PlayerUIState.none) {
        // [PlaybackHistory] Excluir estrictamente los OP/ED de guardarse en el historial global
        final bool isOpEd = state.episode == 'OP' || state.episode == 'ED';
        if (isOpEd) return;

        final duration = state.player?.state.duration.inMilliseconds ?? 0;
        if (duration > 0) {
          // Senior Logic: Intentar obtener el thumbnail del episodio actual para enriquecer el banner de "Continuar Viendo"
          String? effectiveBanner = (item.bannerUrl != null && item.bannerUrl!.isNotEmpty) ? item.bannerUrl : null;
          
          if (state.episode != null && state.availableEpisodes.isNotEmpty) {
            final int? currentEpNum = int.tryParse(state.episode!);
            final epInfo = state.availableEpisodes.firstWhereOrNull(
              (e) => e.number == currentEpNum,
            );
            // Si el episodio tiene miniatura propia, la priorizamos sobre el backdrop genérico
            if (epInfo?.thumbnail != null && epInfo!.thumbnail!.isNotEmpty) {
              effectiveBanner = epInfo.thumbnail;
            }
          }

          final double calcProgress = duration > 0 ? (pos.inMilliseconds / duration).clamp(0.0, 1.0) : 0.0;
          final bool isCompleted = calcProgress > 0.95;

          ref.read(playbackHistoryStateProvider.notifier).updatePosition(
            contentId: item.id,
            title: item.title,
            posterUrl: item.posterUrl,
            bannerUrl: effectiveBanner,
            logoUrl: item.logoUrl,
            category: item.type.name,
            episode: state.episode,
            season: state.season,
            source: state.source,
            url: state.url,
            alternativeSources: state.availableSources,
            positionMs: pos.inMilliseconds,
            durationMs: duration,
          );

          // [Intelligence] Reportar completed_view al motor de personalización
          if (isCompleted) {
            final auth = ref.read(authProvider);
            ref.read(userEventTrackerProvider).record(
              userId: auth?.activeProfileId ?? auth?.id,
              animeId: item.animeId,
              event: 'completed_view',
              sectionId: item.sectionId,
              playbackSessionId: _currentSessionId,
            );
          }
        }
      }
    });
  }

  Future<void> play({
    required MediaItem item,
    required String url,
    String? episode,
    int? season,
    String? source,
    bool triggerOpen = true,
  }) async {
    initPlayerIfNeeded();
    
    final bool isSameContent = state.currentItem?.id == item.id;
    final bool isSameUrl = state.url == url;

    // Si ya está reproduciendo lo mismo, solo expandimos
    if (isSameContent && isSameUrl && state.uiState != PlayerUIState.none) {
      setUiState(PlayerUIState.full);
      return;
    }

    // Senior Strategy: Actualizamos el estado síncronamente para evitar tirones en la UI
    // y solo diferimos la apertura del motor si es necesario.
    state = state.copyWith(
      currentItem: item,
      url: url,
      episode: episode,
      season: season,
      source: source,
      uiState: PlayerUIState.full,
      // Senior Fix: Solo limpiar sesión si es un contenido nuevo de verdad
      availableSources: isSameContent ? state.availableSources : [],
      availableTracks: isSameContent ? state.availableTracks : [],
      availableEpisodes: isSameContent ? state.availableEpisodes : [],
      selectedTrackIndex: isSameContent ? state.selectedTrackIndex : 0,
    );

    // Si no necesitamos abrir el motor (porque la pantalla lo hará manualmente con headers/posiciones), paramos aquí.
    if (!triggerOpen) return;

    // Senior Strategy: Diferimiento del motor para evitar errores de ciclo de vida en el hardware
    Future(() async {
      // Solo abrimos si el URL cambió para evitar parpadeos y errores src
      if (!isSameUrl) {
        _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
        await state.player?.open(Media(url));

        // [Intelligence] Reportar el inicio real de reproducción
        final auth = ref.read(authProvider);
        ref.read(userEventTrackerProvider).record(
          userId: auth?.activeProfileId ?? auth?.id,
          animeId: item.animeId,
          event: 'play',
          sectionId: item.sectionId,
          playbackSessionId: _currentSessionId,
        );
      }
    });
  }

  void setUiState(PlayerUIState uiState) {
    if (state.uiState == uiState) return;
    
    // Senior Continuity Shield: Capturamos el estado de reproducción antes del cambio de modo
    // No pausamos nunca el motor al cambiar de full <-> mini, solo transferimos el GlobalKey
    final bool wasPlaying = state.player?.state.playing ?? false;
    final playerRef = state.player;

    try {
      state = state.copyWith(uiState: uiState);
    } catch (_) {
      // Defunct guard al notificar Consumer ya disposed (episodios -> mini -> X -> reabrir)
      return;
    }

    if (wasPlaying && playerRef != null) {
      Future.microtask(() async {
        await Future.delayed(const Duration(milliseconds: 80));
        try {
          if (playerRef.state.playing == false && state.player == playerRef) {
            await playerRef.play();
          }
        } catch (_) {}
      });
    }
  }

  void updateSession({
    List<SearchResult>? sources,
    List<VideoTrackOption>? tracks,
    List<EpisodeInfo>? episodes,
    int? selectedIndex,
  }) {
    final List<SearchResult> nextSources = (sources != null && sources.isNotEmpty) 
        ? sources 
        : state.availableSources;
         
    final List<VideoTrackOption> nextTracks = (tracks != null && tracks.isNotEmpty) 
        ? tracks 
        : state.availableTracks;

    final List<EpisodeInfo> nextEpisodes = (episodes != null && episodes.isNotEmpty)
        ? episodes
        : state.availableEpisodes;

    MediaItem? nextItem = state.currentItem;
    if (nextEpisodes.isNotEmpty && state.episode != null && nextItem != null) {
        final int? currentEpNum = int.tryParse(state.episode!);
        final epInfo = nextEpisodes.firstWhereOrNull((e) => e.number == currentEpNum);
        if (epInfo?.thumbnail != null && epInfo!.thumbnail!.isNotEmpty) {
            if (nextItem.bannerUrl != epInfo.thumbnail) {
                nextItem = nextItem.copyWith(bannerUrl: epInfo.thumbnail);
            }
        }
    }

    // Sincrónico para que mini/full vean datos sin delay; wrap defunct guard
    try {
      state = state.copyWith(
        availableSources: nextSources,
        availableTracks: nextTracks,
        availableEpisodes: nextEpisodes,
        selectedTrackIndex: selectedIndex ?? state.selectedTrackIndex,
        currentItem: nextItem,
      );
    } catch (_) {
      // Ignora notify a Consumer defunct (race al cerrar mini y reabrir)
    }
  }

  void stop() {
    // Guarda progreso final del mini/full antes de flush (force=true evita throttle 10s)
    try {
      final pos = state.player?.state.position.inMilliseconds ?? 0;
      final dur = state.player?.state.duration.inMilliseconds ?? 0;
      final item = state.currentItem;
      if (item != null && pos > 3000 && dur > 0 && state.episode != 'OP' && state.episode != 'ED') {
        ref.read(playbackHistoryStateProvider.notifier).updatePosition(
          contentId: item.id,
          season: state.season,
          episode: state.episode,
          positionMs: pos,
          durationMs: dur,
          title: item.title,
          posterUrl: item.posterUrl,
          bannerUrl: item.bannerUrl,
          logoUrl: item.logoUrl,
          category: item.type.name,
          source: state.source,
          url: state.url,
          alternativeSources: state.availableSources,
          force: true,
        );
      }
    } catch (_) {}
    try {
      ref.read(playbackHistoryStateProvider.notifier).flush();
    } catch (_) {}
    state.player?.stop();
    _posSubscription?.cancel();
    _posSubscription = null;
    try {
      state = state.copyWith(
        uiState: PlayerUIState.none, 
        currentItem: null, 
        url: null,
        availableSources: [],
        availableTracks: [],
        availableEpisodes: [],
        selectedTrackIndex: 0,
      );
    } catch (_) {}
  }

  /// [Intelligence] Reportar abandono deliberado (skip) del contenido actual.
  /// Debe llamarse solo ante una señal explícita de "No quiero ver esto más".
  void skip() {
    final item = state.currentItem;
    if (item != null) {
      final auth = ref.read(authProvider);
      ref.read(userEventTrackerProvider).record(
        userId: auth?.activeProfileId ?? auth?.id,
        animeId: item.animeId,
        event: 'skip',
        playbackSessionId: _currentSessionId,
      );
    }
    stop();
  }

  /// Switch de episodio sin salir de mini (mantiene `uiState` actual).
  Future<void> switchEpisodeInSession(EpisodeInfo ep) async {
    if (state.currentItem == null || state.source == null) return;
    final pageUrl = ep.url.isNotEmpty ? ep.url : buildEpisodeUrl(state.url ?? '', state.source!, ep.number);
    final category = state.currentItem!.type.name;
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
        // Senior Fix: Usamos la lógica de idioma centralizada basada en ajustes
        // La implementación se delega al _indexForLanguage que ahora consulta settingsProvider.
        // Como estamos en el notifier, necesitamos el provider.
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

  Future<void> seekTo(double progress) async {
    final dur = state.player?.state.duration.inMilliseconds ?? 0;
    if (dur <= 0) return;
    final seekMs = (progress.clamp(0.0, 1.0) * dur).toInt();
    await state.player?.seek(Duration(milliseconds: seekMs));
  }

  @override
  void dispose() {
    _posSubscription?.cancel();
    state.player?.dispose();
    super.dispose();
  }
}
