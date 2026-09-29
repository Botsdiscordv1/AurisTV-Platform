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

/// Etiqueta de episodio `T1:E1 "Título"` (o `T1:E1` sin título / tal cual si
/// no es numérico como OP/ED). Formato único para los subtítulos de los
/// players de las 3 plataformas. Un genérico ("Episodio 1") cuenta como
/// ausente: mostrarlo entrecomillado finge un título que no existe.
String episodeDisplayLabel(String? episode, {int? season, String? title}) {
  final m = RegExp(r'(\d+)').firstMatch(episode ?? '');
  final base = m == null ? (episode ?? '') : 'T${season ?? 1}:E${int.parse(m.group(1)!)}';
  final raw = (title ?? '').trim();
  final t = CommunityTranslationManager.isGenericTitle(raw) ? '' : raw;
  return t.isEmpty ? base : '$base "$t"';
}

/// Huella de una lista de episodios (números+títulos+thumbs). El fast y el
/// full suelen tener LA MISMA longitud: una key solo-longitud bloquea el
/// reemplazo y la sesión se queda con el fast pobre para siempre.
String episodesFingerprint(List<EpisodeInfo> eps) {
  final body =
      eps.map((e) => '${e.number}:${e.title ?? ''}:${e.thumbnail ?? ''}').join('|');
  return '${eps.length}:${body.hashCode}';
}

class ActivePlayerState {
  final Player? player;
  final VideoController? controller;
  final MediaItem? currentItem;
  final PlayerUIState uiState;
  final String? episode;
  final int? season;
  final String? source;
  final String? url;
  /// Título del episodio en curso, fijado explícitamente por el player (que
  /// ya lo tiene cargado para el display). Manda sobre el lookup en
  /// availableEpisodes; se limpia al cambiar de episodio sin título nuevo.
  final String? episodeTitle;
  
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
    this.episodeTitle,
    this.availableSources = const [],
    this.availableTracks = const [],
    this.availableEpisodes = const [],
    this.selectedTrackIndex = 0,
    GlobalKey? videoKey,
  }) : videoKey = videoKey ?? GlobalKey();

  /// Centinela para distinguir "no pasar" de "limpiar con null" en copyWith.
  static const keepField = Object();

  ActivePlayerState copyWith({
    Player? player,
    VideoController? controller,
    MediaItem? currentItem,
    PlayerUIState? uiState,
    String? episode,
    int? season,
    String? source,
    String? url,
    Object? episodeTitle = keepField,
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
      episodeTitle: identical(episodeTitle, keepField)
          ? this.episodeTitle
          : episodeTitle as String?,
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

  /// Extrae el número de episodio de valores como "5", "05" o "EP 5".
  /// tryParse solo vale para numéricos puros y devolvía null en el resto,
  /// con lo que el lookup del thumbnail se saltaba y caía al backdrop.
  int? _parseEpisodeNumber(String? episode) {
    if (episode == null) return null;
    final direct = int.tryParse(episode.trim());
    if (direct != null) return direct;
    final m = RegExp(r'(\d+)\s*$').firstMatch(episode);
    return m != null ? int.tryParse(m.group(1)!) : null;
  }

  /// EpisodeInfo del episodio dado en la lista dada (null si no hay match).
  /// Público para que las pantallas resuelvan título/thumbnail sin depender
  /// del timing del sync.
  EpisodeInfo? episodeInfoFor(String? episode, [List<EpisodeInfo>? episodes]) {
    final list = episodes ?? state.availableEpisodes;
    if (list.isEmpty) return null;
    final currentEpNum = _parseEpisodeNumber(episode);
    if (currentEpNum == null) {
      debugPrint('[HistoryBanner] episodio sin número parseable: "$episode"');
      return null;
    }
    final epInfo = list.firstWhereOrNull(
      (e) => e.number == currentEpNum,
    );
    if (epInfo == null) {
      debugPrint('[HistoryBanner] ep $currentEpNum no está en ${list.length} episodios cargados');
    }
    return epInfo;
  }

  /// Thumbnail del episodio dado en la lista dada (null si no hay match).
  /// Público para que las pantallas resuelvan sin depender del sync.
  String? episodeThumbnail(String? episode, [List<EpisodeInfo>? episodes]) {
    final thumb = episodeInfoFor(episode, episodes)?.thumbnail;
    return (thumb != null && thumb.isNotEmpty) ? thumb : null;
  }

  /// Banner determinista para el historial: thumbnail del episodio en curso si
  /// la lista ya llegó (caso normal al cerrar tras ver un rato); si no, el
  /// banner del item (backdrop). El guardado final (stop) usaba el banner
  /// crudo del item, así que si cerrabas antes de que llegaran los episodios
  /// la tarjeta quedaba con backdrop aunque los ticks ya hubieran guardado
  /// el thumb (o viceversa según el timing) → alternancia backdrop/thumb.
  String? resolveEpisodeBanner() {
    final item = state.currentItem;
    final thumb = episodeThumbnail(state.episode, state.availableEpisodes);
    if (thumb != null) return thumb;
    return (item?.bannerUrl != null && item!.bannerUrl!.isNotEmpty)
        ? item.bannerUrl
        : null;
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
          // Banner del episodio en curso (o backdrop si aún no llegó la lista)
          final String? effectiveBanner = resolveEpisodeBanner();

          final double calcProgress = duration > 0 ? (pos.inMilliseconds / duration).clamp(0.0, 1.0) : 0.0;
          final bool isCompleted = calcProgress > 0.95;

          List<SearchResult>? robustSources = state.availableSources;
          if ((robustSources == null || robustSources.isEmpty) && item.card != null) {
            robustSources = [item.card!];
          }

          // url del historial: solo URLs http reales (detailUrl o id-url).
          // Antes caía el título cuando detailUrl era null y el id no era URL,
          // y ese título luego se usaba como url del seed → /api/episodes roto.
          final String? detailUrl = item.detailUrl;
          final String? historyUrl = (detailUrl != null && detailUrl.isNotEmpty)
              ? detailUrl
              : (isHttpUrl(item.id) ? item.id : null);

          ref.read(playbackHistoryStateProvider.notifier).updatePosition(
            contentId: item.id,
            title: item.title,
            posterUrl: item.posterUrl,
            bannerUrl: effectiveBanner,
            logoUrl: item.logoUrl,
            category: item.type.name,
            kind: item.kind ?? item.card?.kind,
            type: item.card?.type ?? item.type.name,
            year: item.year,
            episode: state.episode,
            season: state.season,
            source: state.source,
            url: historyUrl,
            alternativeSources: robustSources,
            // Título explícito del player (display T1:E1 "x") manda; si no
            // hay, lookup en la lista sincronizada.
            episodeTitle: state.episodeTitle ?? episodeInfoFor(state.episode)?.title,
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
    List<SearchResult>? sources,
    // Título ya resuelto por el player para el display T1:E1 "x": se guarda
    // tal cual en el historial al salir (sin depender del timing del sync).
    String? episodeTitle,
  }) async {
    initPlayerIfNeeded();
    
    final bool isSameContent = state.currentItem?.id == item.id;
    final bool isSameUrl = state.url == url;

    final List<SearchResult> activeRegisteredSources = ref.read(activeContentSourcesProvider);

    final List<SearchResult> mergedSources = (sources != null && sources.isNotEmpty)
        ? sources
        : (activeRegisteredSources.isNotEmpty
            ? activeRegisteredSources
            : (isSameContent ? state.availableSources : (item.card != null ? [item.card!] : [])));

    // Si ya está reproduciendo lo mismo, solo expandimos
    if (isSameContent && isSameUrl && state.uiState != PlayerUIState.none) {
      setUiState(PlayerUIState.full);
      return;
    }

    // Cambio real de contenido/episodio/fuente: invalidar el preload del
    // episodio anterior (si no, el popup "siguiente" consumiría tracks stale).
    try {
      ref.read(playerPreloadControllerProvider).clearPreload();
    } catch (_) {}

    // Senior Strategy: Actualizamos el estado síncronamente para evitar tirones en la UI
    // y solo diferimos la apertura del motor si es necesario.
    // El título explícito manda; si el episodio cambió y no viene título se
    // limpia para no arrastrar el anterior (el lookup lo repondrá al llegar
    // la lista).
    final bool episodeChanged = state.episode != episode;
    state = state.copyWith(
      currentItem: item,
      url: url,
      episode: episode,
      season: season,
      source: source,
      episodeTitle: episodeTitle ?? (episodeChanged ? null : ActivePlayerState.keepField),
      uiState: PlayerUIState.full,
      // Senior Fix: Solo limpiar sesión si es un contenido nuevo de verdad
      availableSources: mergedSources,
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
    // Título ya resuelto por el player (display): fija el campo sin esperar
    // al sync de la lista. Null = conservar el actual.
    String? episodeTitle,
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
    if (nextEpisodes.isNotEmpty && nextItem != null) {
        final thumb = episodeThumbnail(state.episode, nextEpisodes);
        if (thumb != null) {
            if (nextItem.bannerUrl != thumb) {
                nextItem = nextItem.copyWith(bannerUrl: thumb);
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
        episodeTitle: episodeTitle ?? ActivePlayerState.keepField,
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
        List<SearchResult>? robustSources = state.availableSources;
        if ((robustSources == null || robustSources.isEmpty) && item.card != null) {
          robustSources = [item.card!];
        }
        // url del historial: solo URLs http reales (igual que en los ticks).
        final String? detailUrl = item.detailUrl;
        final String? historyUrl = (detailUrl != null && detailUrl.isNotEmpty)
            ? detailUrl
            : (isHttpUrl(item.id) ? item.id : null);

        ref.read(playbackHistoryStateProvider.notifier).updatePosition(
          contentId: item.id,
          season: state.season,
          episode: state.episode,
          positionMs: pos,
          durationMs: dur,
          title: item.title,
          posterUrl: item.posterUrl,
          bannerUrl: resolveEpisodeBanner(),
          logoUrl: item.logoUrl,
          category: item.type.name,
          kind: item.kind ?? item.card?.kind,
          type: item.card?.type ?? item.type.name,
          year: item.year,
          source: state.source,
          url: historyUrl,
          alternativeSources: robustSources,
          episodeTitle: state.episodeTitle ?? episodeInfoFor(state.episode)?.title,
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
    // Consumir el preload vigente si es para este mismo episodio (si no,
    // extracción fresca como antes). Sin el match por url+episodio se podía
    // reproducir un preload stale (E6 precargado, salto a E8, abría E6).
    ExtractResult? preloaded;
    try {
      final target = ref.read(nextEpisodePreloadTargetProvider);
      if (target != null && target.url == pageUrl && target.episode == ep.number) {
        preloaded = ref.read(nextEpisodePreloadProvider);
      }
    } catch (_) {}
    ExtractResult extract;
    if (preloaded != null && preloaded.tracks.isNotEmpty) {
      debugPrint('[player_session] switchEpisode consume preload E${ep.number}');
      extract = preloaded;
      try {
        ref.read(playerPreloadControllerProvider).clearPreload();
      } catch (_) {}
    } else {
      try {
        final repo = ref.read(aurisRepositoryProvider);
        extract = await repo.extractVideo(pageUrl, state.source!, category: category);
      } catch (e) {
        debugPrint('[player_session] switchEpisode fail: $e');
        return;
      }
    }
    try {
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
