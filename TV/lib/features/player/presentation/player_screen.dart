import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:collection/collection.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import 'package:auris_core/auris_core.dart';
import '../../../core/utils/app_fullscreen.dart';
import '../../../core/utils/web_utils.dart';

import '../../remote_control/presentation/providers/remote_control_provider.dart';
import '../../remote_control/data/models/remote_device.dart';
// import '../../remote_control/presentation/widgets/device_selector_dialog.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final String contentId;
  final String sourceUrl;
  final String source;
  final String? episode;
  final int? season;
  final String? serverName;
  final int? startPosition;
  final String? category;
  /// Kind granular + año para historial fiel (ver Movil).
  final String? kind;
  final int? year;
  final int? totalEpisodes;
  final String? title;
  final String? metadataTitle;
  final String? episodeTitle;
  final String? posterUrl;
  final String? bannerUrl;
  final String? logoUrl;
  final String? video720;
  final String? video1080;
  final bool skipResume;

  const PlayerScreen({
    super.key,
    required this.contentId,
    required this.sourceUrl,
    this.source = '',
    this.episode,
    this.season,
    this.serverName,
    this.startPosition,
    this.category,
    this.kind,
    this.year,
    this.totalEpisodes,
    this.title,
    this.metadataTitle,
    this.episodeTitle,
    this.posterUrl,
    this.bannerUrl,
    this.logoUrl,
    this.video720,
    this.video1080,
    this.skipResume = false,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

enum PlayerOverlay { none, language, server, quality, config, speed, volume, episodes }

class _PlayerScreenState extends ConsumerState<PlayerScreen> with WidgetsBindingObserver {
  late final FocusNode _timelineFocusNode;
  late final FocusNode _playerFocusNode;
  late final FocusNode _headerFocusNode = FocusNode(debugLabel: "player_header");
  late final FocusNode _serverPillFocusNode = FocusNode(debugLabel: "pill_server");
  late final FocusNode _episodesPillFocusNode = FocusNode(debugLabel: "pill_episodes");
  late final FocusNode _opedPillFocusNode = FocusNode(debugLabel: "pill_oped");
  late final FocusNode _languagePillFocusNode = FocusNode(debugLabel: "pill_language");
  late final FocusNode _sidePanelCloseNode = FocusNode(debugLabel: "sidepanel_close");
  FocusNode? _lastFocusedPillNode;
  DateTime _timelineFocusTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool get _isMovie => widget.category == 'movie' || widget.category == 'movie_anime';
  Player? _player;
  VideoController? _controller;
  int _selectedTrackIndex = 0;

  String get _currentTrackQuality {
    if (_allTracks.isEmpty) return '';
    final i = _selectedTrackIndex < _allTracks.length ? _selectedTrackIndex : 0;
    return _allTracks[i].quality;
  }

  StreamSubscription<Tracks>? _tracksSubscription;
  WebViewController? _webViewController;
    bool _hasInitialized = false;
    // Clave del último sync de episodios al provider global (evita re-syncs
    // en cada rebuild: el whenData dispara por cada frame mientras hay data).
    String? _episodesSyncKey;

  bool _showControls = true;
  bool _hasResetPosition = false;
  int _resumePosition = 0;
  /// Generación del seek de resume: cada _initPlayer la incrementa para que
  /// los loops de reintento del episodio/fuente anterior se aborten y no
  /// apliquen su seek tardío sobre el nuevo stream (igual que Movil).
  int _resumeSeekGen = 0;
  DateTime? _resumeGuardUntil;
  int _resumeGuardRetries = 0;
  Timer? _hideTimer;
  double _playbackSpeed = 1.0;
  StreamSubscription? _posSubscription;
  StreamSubscription? _completedSubscription;
  bool _isStabilizing = false;
  Timer? _stabilizationTimer;
  bool _isMobileDevice = false;
  bool _isFullscreen = false;
  bool _isExiting = false;
  bool _webNeedsInteraction = false; // Senior Web Fix: Autoplay blocker
  PlayerOverlay _activeOverlay = PlayerOverlay.none;
  /// Sub-panel padre para la navegación en dos niveles (Configuración →
  /// Calidad): salir desde el hijo vuelve al padre en vez de cerrar.
  PlayerOverlay? _overlayParent;
  bool _isVolumePillHovered = false;
  Timer? _volumeExitTimer;
  String _selectedQuality = 'auto';
  bool _userHasPaused = false;
  // Center indicator removed
  final GlobalKey _sliderKey = GlobalKey();
  final ValueNotifier<Offset?> _hoverInfoNotifier = ValueNotifier<Offset?>(null);

  // Senior Pro Gestures State
  double? _gestureStartX;
  double _lastGestureValue = 0.0;
  bool? _isBrightnessGesture;
  double _lastAppliedBrightness = -1.0;
  double _lastAppliedVolume = -1.0;
  bool _showSeekIndicator = false;
  Duration _seekTargetDuration = Duration.zero;
  Duration _seekDiff = Duration.zero;
  // Hold-scrub estilo YouTube TV (D-pad mantenido en el timeline).
  Timer? _holdTimer;
  int _holdDir = 0; // -1 atrás, +1 adelante, 0 inactivo
  int _holdBaseMs = 0;
  DateTime? _holdStart;
  Timer? _historySaveTimer;
  int? _lastSeekPosMs;

  /// En móvil/tablet el player ya ocupa toda la pantalla, así que el botón
  /// "fullscreen" no cambia la ventana sino el formato/ajuste del video:
  /// contain (default) → fill (estira a los bordes) → cover (rellena sin
  /// estirar) → contain.
  BoxFit _videoFit = BoxFit.contain;

  /// En Android/iOS (phone/tablet/foldable) y en web móvil el player ya cubre
  /// toda la pantalla, así que el botón debe ajustar el formato del video en
  /// lugar de entrar/salir de fullscreen del SO/navegador.
  bool get _useVideoFitCycle {
    if (kIsWeb) {
      return MediaQuery.sizeOf(context).shortestSide < 600;
    }
    return _isMobileDevice || ResponsiveUtils.isTablet(context);
  }

  bool _isLoading = true;
  bool _isCompleted = false;
  StreamSubscription<bool>? _bufferingSubscription;
  StreamSubscription<double>? _volumeSubscription;
  DateTime? _lastManualVolumeTime;

  List<VideoTrackOption> _extractTracks = [];
  List<VideoTrackOption> _allTracks = [];

  /// Calidades disponibles de la pista actual (parseadas del master HLS).
  List<QualityOption> _qualityOptions = [];

  /// Stream base de la pista actual (para volver a "Automático").
  String _currentStreamUrl = '';
  Map<String, String> _currentStreamHeaders = const {};

  double _volume = 1.0;

  late String _currentSourceUrl;
  late String _currentSource;
  String? _currentServerName;
  String? _currentLanguage;
  String? _currentEpisode;
  Map<String, List<SearchResult>> _groupedSources = {};
  DateTime? _lastPopEventTime;
  bool _ignoreNextPop = false;

  /// Episodio activo: se actualiza al navegar entre episodios.
  String? get _activeEpisode => _currentEpisode ?? widget.episode;

  bool get _isSpecial => widget.season == 0;
  String get _displayTitle {
    if (_isSpecial && widget.episodeTitle?.isNotEmpty == true) return widget.episodeTitle!;
    return widget.title ?? widget.contentId;
  }

  /// Si el contenido actual es un Opening (OP) o Ending (ED).
  bool get _isOpEd => widget.episode == 'OP' || widget.episode == 'ED';

  /// Si el contenido actual es un Tráiler.
  bool get _isTrailer => widget.episode == 'Trailer';

  /// Subtítulo del episodio en formato `T1:E1 "Título"` (igual en las 3
  /// plataformas). Observa la lista sincronizada: el título aparece en cuanto
  /// llega, y al mostrarse ya queda cargado para el guardado.
  String _episodeLabel() {
    if (_isSpecial) return 'Temporada 0';
    String? title;
    try {
      final synced = ref.watch(activePlayerProvider.select((s) => s.availableEpisodes));
      final notifier = ref.read(activePlayerProvider.notifier);
      title = notifier.episodeInfoFor(_activeEpisode, _enrichedEpisodes(synced ?? const []))?.title;
      if (title == null || title.isEmpty) {
        final eps = ref
            .read(episodesProvider(EpisodesParams(
              url: _seriesListUrl,
              source: widget.source,
              title: widget.title,
              season: widget.season,
            )))
            .valueOrNull
            ?.episodes;
        title = notifier.episodeInfoFor(_activeEpisode, _enrichedEpisodes(eps ?? const []))?.title;
      }
    } catch (_) {}
    return episodeDisplayLabel(_activeEpisode, season: widget.season, title: title);
  }

  /// URL de SERIE para listar episodios. El player recibe la URL del
  /// episodio y con ella el backend devuelve lista incompleta (a veces solo
  /// ese episodio); la ficha usa la URL de serie y ve todo. Se resuelve
  /// desde las fuentes sincronizadas; fallback a la URL actual.
  String get _seriesListUrl {
    try {
      final sources = ref.read(activeContentSourcesProvider);
      final match = findSourceByName(sources, _currentSource) ??
          (sources.isNotEmpty ? sources.first : null);
      final url = match?.url ?? '';
      if (url.isNotEmpty) return url;
    } catch (_) {}
    return widget.sourceUrl;
  }

  /// Hereda la metadata enriquecida de la ficha (títulos ES, thumbnails TMDB)
  /// desde el caché de serie del core. El player consulta episodesProvider
  /// con la URL del episodio y recibe la respuesta cruda (números/URLs); sin
  /// esto el carrusel y los títulos quedan sin metadata. Si la ficha no se
  /// visitó (deep link, Continuar Viendo directo) devuelve la lista intacta.
  List<EpisodeInfo> _enrichedEpisodes(List<EpisodeInfo> episodes) {
    if (episodes.isEmpty) return episodes;
    return ProgressiveContentNotifier.enrichWithSeriesMetadata(
      title: widget.title ?? widget.contentId,
      metadataTitle: widget.metadataTitle,
      season: widget.season ?? 1,
      episodes: episodes,
    );
  }

  /// Al navegar al siguiente/anterior episodio, el nuevo stream debe arrancar
  /// desde cero y NO reaplicar el startPosition/resume del episodio anterior.
  bool _skipResumeOnNextInit = false;

  void _forceSoftwareRestart(String url, Map<String, String> headers) {
    if (_resetRetryCount >= 4) return; // Evitar bucles infinitos
    _resetRetryCount = 4; // El valor 4 activa el modo 'hwdec: no'
    _diagPosCount = 0;
    _hasResetPosition = false; // Bloqueamos historial
    
    // Capturamos la última posición buena o la de reanudación
    final currentPos = _player?.state.position.inMilliseconds ?? 0;
    if (currentPos > 3000) _resumePosition = currentPos;
    
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _initPlayer(url, headers);
    });
  }

  void _initRemoteControl() {
    Future.delayed(Duration.zero, () {
      if (!mounted) return;
      
      // La TV solo escucha comandos entrantes (es el RECEPTOR/TARGET)
      ref.listenManual(
        remoteControlProvider.select((s) => s.lastReceivedCommand),
        (previous, next) {
          if (next != null && next != previous) {
            _handleRemoteCommand(next);
          }
        },
      );
    });
  }

  void _handleRemoteCommand(Map<String, dynamic> command) {
    if (!mounted) return;
    
    final action = command['action'];
    debugPrint('[AurisRemote] Executing action: $action');

    switch (action) {
      case RemoteAction.play:
        _player?.play();
        break;
      case RemoteAction.pause:
        _player?.pause();
        break;
      case RemoteAction.seek:
        final pos = command['position_ms'];
        if (pos != null) {
          _player?.seek(Duration(milliseconds: pos));
        }
        break;
      case RemoteAction.setVolume:
        final vol = command['volume'];
        if (vol != null) {
          setState(() {
            _volume = (vol as num).toDouble();
            _applyVolume();
          });
        }
        break;
      case RemoteAction.stop:
        Navigator.of(context).pop();
        break;
      case RemoteAction.skipOpEd:
        _skipOpEd();
        break;
      case RemoteAction.switchTrack:
        final index = command['index'];
        if (index != null && index is int) {
          _switchTrack(index);
        }
        break;
    }
  }

  void _reportStatusToRemote() {
    if (_player == null || !mounted) return;
    
    final now = DateTime.now().millisecondsSinceEpoch;
    final bool tracksLoaded = _allTracks.isNotEmpty;
    
    if (now - _lastRemoteUpdateMs < 3000 && !tracksLoaded) return;
    _lastRemoteUpdateMs = now;

    ref.read(remoteControlProvider.notifier).updateStatus(
      mediaTitle: widget.title,
      mediaSource: _currentSource,
      mediaUrl: _currentSourceUrl,
      metadataTitle: widget.metadataTitle,
      posterUrl: widget.posterUrl,
      bannerUrl: widget.bannerUrl,
      logoUrl: widget.logoUrl,
      category: widget.category,
      year: null, 
      positionMs: _player!.state.position.inMilliseconds,
      durationMs: _player!.state.duration.inMilliseconds,
      isPlaying: _player!.state.playing,
      volume: _volume,
      availableTracks: _allTracks.map((t) => {
        'label': t.label,
        'url': t.url,
        'quality': t.quality,
      }).toList(),
      selectedTrackIndex: _selectedTrackIndex,
    );
  }

  Widget _buildTopControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          _buildCircularButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).pop(),
            size: 44,
            iconSize: 22,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title ?? 'AurisTV',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (widget.metadataTitle != null)
                  Text(
                    widget.metadataTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _applyVolume() {
    if (kIsWeb) {
      if (_volume <= 1.0) {
        // Modo Estándar: Usar volumen nativo y ganancia neutra
        _player?.setVolume(_volume * 100);
        WebUtils.applyAudioBoost(1.0);
      } else {
        // Modo Boost: Volumen nativo al máximo y usar GainNode para el extra
        _player?.setVolume(100.0);
        WebUtils.applyAudioBoost(_volume);
      }
      return;
    }

    if (_volume <= 1.0) {
      final double safeVol = double.parse(_volume.toStringAsFixed(2));
      VolumeController.instance.setVolume(safeVol);
      _player?.setVolume(100.0);
    } else {
      // Boost INTERNO del video (125-200%): no se toca el volumen del
      // sistema, solo se amplifica el audio del reproductor (mpv tiene
      // volume-max 200). Paridad con el GainNode de Web.
      _player?.setVolume(_volume * 100);
    }
  }

  void _updateHistory({required int positionMs, required int durationMs, bool force = false}) {
    if (_isDisposed) return;
    if (widget.contentId.isEmpty || _historyNotifier == null || _isOpEd) return;
    
    // Senior Performance Fix: Throttling de guardado en base de datos.
    // Solo guardamos si es 'force' o si han pasado 1s desde el último movimiento.
    if (!force) {
      _historySaveTimer?.cancel();
      _historySaveTimer = Timer(const Duration(seconds: 1), () {
        if (!mounted || _isDisposed) return;
        _performHistoryUpdate(positionMs, durationMs, force: false);
      });
      return;
    }
    
    _performHistoryUpdate(positionMs, durationMs, force: true);
  }

  void _performHistoryUpdate(int positionMs, int durationMs, {bool force = false}) {
    // Tras dispose el ref muere (StateError): el guardado final usa
    // _finalSaveOnDispose (sin ref). Igual que Movil.
    if (_isDisposed) return;
    // Título/banner del episodio: 1) lista sincronizada del provider global,
    // 2) lectura directa de episodios (no depende del timing del sync), igual
    // que Movil. Sin esto Continuar Viendo mostraba "T1:E1" sin título en TV.
    String? episodeThumb;
    String? episodeTitle;
    try {
      final notifier = ref.read(activePlayerProvider.notifier);
      episodeThumb = notifier.resolveEpisodeBanner();
      if (episodeThumb == null || episodeThumb == widget.bannerUrl) {
        final epsData = ref
            .read(episodesProvider(EpisodesParams(
              url: _seriesListUrl,
              source: widget.source,
              title: widget.title,
              season: widget.season,
            )))
            .valueOrNull;
        final info = notifier.episodeInfoFor(_activeEpisode,
            _enrichedEpisodes(epsData?.episodes ?? const []));
        if (info?.thumbnail != null && info!.thumbnail!.isNotEmpty) {
          episodeThumb = info.thumbnail;
        }
        episodeTitle = info?.title;
      } else {
        episodeTitle =
            notifier.episodeInfoFor(_activeEpisode)?.title;
      }
    } catch (_) {}
    // Cachear lo resuelto para el guardado final en dispose (sin ref).
    // Solo se pisa con valores reales.
    if (episodeTitle != null && episodeTitle.isNotEmpty) {
      _lastResolvedEpisodeTitle = episodeTitle;
    }
    final _resolvedBanner = episodeThumb ?? widget.bannerUrl;
    if (_resolvedBanner != null && _resolvedBanner.isNotEmpty) {
      _lastResolvedEpisodeBanner = _resolvedBanner;
    }
    _historyNotifier!.updatePosition(
      contentId: widget.contentId,
      season: widget.season,
      episode: _activeEpisode,
      positionMs: positionMs,
      durationMs: durationMs,
      title: widget.title,
      posterUrl: widget.posterUrl,
      // Banner del episodio en curso (no el backdrop crudo): ver Movil.
      bannerUrl: episodeThumb ?? widget.bannerUrl,
      episodeTitle: episodeTitle,
      logoUrl: widget.logoUrl,
      category: widget.category,
      kind: widget.kind,
      year: widget.year,
      source: widget.source,
      url: _currentSourceUrl,
      alternativeSources: ref.read(activeContentSourcesProvider),
      force: force,
    );
  }

  /// Guardado final en dispose SIN usar ref (ver Movil: el ref muere con el
  /// widget y ref.read lanza StateError en finalizeTree).
  void _finalSaveOnDispose(int positionMs, int durationMs) {
    try {
      final hn = _historyNotifier;
      if (hn == null) return;
      hn.updatePosition(
        contentId: widget.contentId,
        season: widget.season,
        episode: _activeEpisode,
        positionMs: positionMs,
        durationMs: durationMs,
        title: widget.title,
        posterUrl: widget.posterUrl,
        bannerUrl: _lastResolvedEpisodeBanner ?? widget.bannerUrl,
        episodeTitle: _lastResolvedEpisodeTitle,
        kind: widget.kind,
        year: widget.year,
        logoUrl: widget.logoUrl,
        category: widget.category,
        source: widget.source,
        url: _currentSourceUrl,
        alternativeSources: _groupedSources.values.expand((e) => e).toList(),
        force: true,
      );
      hn.flush();
    } catch (_) {}
  }

  PlaybackHistoryNotifier? _historyNotifier;
  // Tras dispose el ref muere: bandera + últimos valores para el guardado
  // final sin ref (igual que Movil).
  bool _isDisposed = false;
  String? _lastResolvedEpisodeTitle;
  String? _lastResolvedEpisodeBanner;
  late PlaybackPolicy _policy;
  final ValueNotifier<bool> _showNextNotifier = ValueNotifier<bool>(false);
  int _autoplayCountdown = -1;
  bool _isAutoplayResume = false;
  Timer? _autoplayTimer;
  int _lastFrameMs = 0;
  DateTime? _lastManualSeekTime;
  int _lastStablePositionMs = 0;
  int _lastUiPersistenceMs = 0;
  int _lastRemoteUpdateMs = 0;
  Timer? _bufferingDebounceTimer;
  final GlobalKey _videoKey = GlobalKey();
  
  // Senior Recovery State
  int _resetRetryCount = 0;
  int _diagPosCount = 0;

  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<PlayerLog>? _logSubscription;
  StreamSubscription<bool>? _playingSubscription;
  Timer? _loadWatchdogTimer;
  String? _playbackError;
  String _lastVideoUrl = '';
  Map<String, String> _lastVideoHeaders = const {};

  static const _volumeControlChannel = MethodChannel('auristv/volume');

  /// Activa/desactiva la intercepción nativa de teclas de volumen.
  /// En TV no hay handler nativo (el volumen lo maneja el sistema o el remoto IR
  /// de la TV certificada), así que se ignora silenciosamente en vez de lanzar
  /// MissingPluginException.
  Future<void> _setVolumeIntercept(bool enabled) async {
    try {
      await _volumeControlChannel.invokeMethod('setIntercept', {'enabled': enabled});
    } catch (_) {
      // No-op en plataformas sin handler nativo (TV).
    }
  }
  
  @override
  void initState() {
    super.initState();
    _timelineFocusNode = FocusNode(debugLabel: "player_timeline");
    _playerFocusNode = FocusNode(debugLabel: "player_root");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _timelineFocusNode.canRequestFocus) {
        _timelineFocusNode.requestFocus();
      }
    });
    WidgetsBinding.instance.addObserver(this);
    
    // Senior Restore: Identificación precisa de dispositivo nativo vs táctil.
    _isMobileDevice = ResponsiveUtils.isNative;

    // Senior Fix: Capturar el notifier en initState para poder usarlo en dispose de forma segura
    _historyNotifier = ref.read(playbackHistoryStateProvider.notifier);

    // En App Nativa mantenemos el control total del hardware.
    // TV: siempre horizontal 16:9 (las TV no tienen variante vertical).
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (_isMobileDevice) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      // Senior Elite Fix: ImmersiveSticky es el modo correcto para video Fullscreen Real.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
      ));
    }
    
    if (_isMobileDevice) {
      // Senior Volume Sync: Inicializar con el volumen real del sistema.
      VolumeController.instance.getVolume().then((v) {
        if (mounted) setState(() => _volume = v);
      });
      VolumeController.instance.showSystemUI = true;
      
      // Senior Shield: Activar la intercepción nativa inmediatamente al entrar
      _setVolumeIntercept(true);

      _volumeSubscription = VolumeController.instance.addListener((v) {
        // Senior Elite Sync: Escudo de 1.5s para evitar el "eco" del hardware
        if (_lastManualVolumeTime != null && 
            DateTime.now().difference(_lastManualVolumeTime!).inMilliseconds < 1500) return;

        if (mounted) {
          if (_volume > 1.0 && v >= 0.99) return;

          setState(() {
            _volume = v;
          });
          _player?.setVolume(100.0);
        }
      });
    }
    
    _currentSourceUrl = widget.sourceUrl;
    _currentSource = widget.source;
    _currentServerName = widget.serverName;
    _currentEpisode = widget.episode;

    _policy = PlaybackPolicyResolver.resolve(
      PlaybackPolicyResolver.fromString(widget.category ?? 'anime')
    );

    _initRemoteControl();

    // Senior Bridge Listener: Escuchar señales de botones físicos desde Android
    _volumeControlChannel.setMethodCallHandler((call) async {
      if (call.method == 'volumeUp') _handleVolumeStep(0.05);
      else if (call.method == 'volumeDown') _handleVolumeStep(-0.05);
    });

    // Senior Restoration: Si el provider de fuentes está vacío (viniendo de "Continuar Viendo"),
    // intentamos restaurarlo desde el historial persistido para permitir cambio de servidor.
    final currentSources = ref.read(activeContentSourcesProvider);
    if (currentSources.isEmpty) {
      final history = _historyNotifier?.getProgress(widget.contentId, widget.season, _activeEpisode);
      if (history?.alternativeSources != null && history!.alternativeSources!.isNotEmpty) {
        // Senior Fix: Diferimos la actualización al siguiente microtask para evitar el error
        // "Tried to modify a provider while the widget tree was building"
        Future.microtask(() {
          if (mounted) {
            ref.read(activeContentSourcesProvider.notifier).state = history.alternativeSources!;
            // Senior Fix: Regenerar la lista de servidores una vez restaurados del historial
            _findAlternatives();
          }
        });
      }
    }

    if (widget.sourceUrl.isNotEmpty && widget.source.isEmpty) {
      _hasInitialized = true;
      _initPlayer(widget.sourceUrl);
      _findAlternatives();
    } else if (widget.source == 'YouTube' && widget.sourceUrl.isNotEmpty) {
      // OP/ED de /api/themes con solo ID de YouTube (igual que Movil): van
      // directo al WebView en formato embed (watch no sirve en TV).
      _hasInitialized = true;
      _initEmbedPlayer(_youTubeEmbedUrl(widget.sourceUrl));
      _findAlternatives();
    } else {
      _findAlternatives();
    }
    
    _startHideTimer();
  }

  void _findAlternatives() {
    final sources = ref.read(activeContentSourcesProvider);
    List<SearchResult> effective = sources;

    // Senior Fix: Si no hay fuentes en el provider (abierto desde "Continuar Viendo"
    // o deep link) pero conocemos el servidor actual, al menos mostramos ese para
    // que la lista de servidores no quede vacía.
    if (effective.isEmpty && widget.source.isNotEmpty) {
      effective = [
        SearchResult(
          title: widget.title ?? widget.serverName ?? widget.source,
          url: widget.sourceUrl,
          quality: '',
          thumbnail: '',
          source: widget.source,
        ),
      ];
    }

    if (effective.isEmpty) return;

    final Map<String, List<SearchResult>> grouped = {};
    for (final r in effective) {
      final sName = simplifySourceName(r.source);
      grouped.putIfAbsent(sName, () => []).add(r);
    }

    setState(() {
      _groupedSources = grouped;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isMobileDevice) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Senior Shield: Si el usuario minimiza la app o apaga la pantalla, 
      // restauramos la UI del sistema para no "secuestrar" los botones de volumen fuera del player.
      VolumeController.instance.showSystemUI = true;
      _setVolumeIntercept(false);
    } else if (state == AppLifecycleState.resumed) {
      // Al volver al player, mantenemos visible la interfaz de volumen del sistema.
      VolumeController.instance.showSystemUI = true;
      _setVolumeIntercept(true);
    }
  }

  void _switchTrack(int index) {
    if (index >= _allTracks.length) return;
    
    // Senior Hybrid Fix: Obtener posición actual según el motor activo
    final int currentPosMs = (_player?.state.position.inMilliseconds ?? 0);
    
    final int durationMs = (_player?.state.duration.inMilliseconds ?? 0);

    if (currentPosMs > 3000) {
      _updateHistory(
        positionMs: currentPosMs,
        durationMs: durationMs,
        force: true,
      );
    }

    // Senior Stability Fix: Parar el reproductor INMEDIATAMENTE
    _player?.stop();

    final track = _allTracks[index];

    setState(() {
      _selectedTrackIndex = index; // Senior Fix: Actualizamos el índice para marcarlo como seleccionado
      _currentLanguage = trackQualityType(track.quality) == 'SUB' ? 'SUB' : 'LAT';
      _resumePosition = currentPosMs;
      _isAutoplayResume = false;
      _hasResetPosition = false;
      _isStabilizing = true;
      // Senior Quality Fix: Actualizar las calidades disponibles de la nueva pista.
      _qualityOptions = track.qualities;
      if (_qualityOptions.length <= 1) _selectedQuality = 'auto';
    });

    _initPlayer(track.url, track.headers);
    _startHideTimer();
  }

  void _switchSource(SearchResult newSource) async {
    // Senior Hybrid Fix: Obtener posición actual según el motor activo
    final int currentPosMs = (_player?.state.position.inMilliseconds ?? 0);
    
    final int durationMs = (_player?.state.duration.inMilliseconds ?? 0);

    final qualityLower = newSource.quality.toLowerCase();
    final epNum = _activeEpisode != null ? int.tryParse(_activeEpisode!) ?? 1 : 1;
    
    if (currentPosMs > 3000) {
      _updateHistory(
        positionMs: currentPosMs,
        durationMs: durationMs,
        force: true,
      );
    }

    // Senior Stability Fix: Parar el reproductor INMEDIATAMENTE
    _player?.stop();

    String resolvedUrl = _activeEpisode != null
        ? buildEpisodeUrl(newSource.url, newSource.source, epNum)
        : newSource.url;

    if (_activeEpisode != null && newSource.source == 'Aniyae') {
      try {
        final repo = ref.read(aurisRepositoryProvider);
        final episodeUrl = await repo.resolveEpisodeUrl(newSource.url, newSource.source, epNum, category: widget.category);
        if (episodeUrl.isNotEmpty) resolvedUrl = episodeUrl;
      } catch (e) {
        debugPrint('[SwitchSource] Resolve failed for ${newSource.source}: $e');
      }
    }

    if (!mounted) return;

    setState(() {
      _currentSourceUrl = resolvedUrl;
      _currentSource = newSource.source;
      _currentServerName = newSource.source;
      // Senior Language Fix: Mantener el idioma que se venía reproduciendo al
      // cambiar de fuente (p.ej. DUB desde AnimeJara). El fallback a SUB solo
      // ocurre si la nueva fuente no expone pista DUB, lo resuelve
      // _indexForLanguage al inicializar el extract. Si no hay idioma previo,
      // derivarlo de la calidad declarada por la fuente.
      if (_currentLanguage == null) {
        _currentLanguage = trackQualityType(newSource.quality) == 'SUB' ? 'SUB' : 'LAT';
      }
      _hasInitialized = false;
      _resumePosition = currentPosMs;
      _isAutoplayResume = false;
      _hasResetPosition = false; 
      _isStabilizing = true;
      // Senior Quality Fix: Resetear calidades hasta que el nuevo extract las aporte.
      _qualityOptions = const [];
      _selectedQuality = 'auto';
    });
    
    _startHideTimer();
  }

  void _resolveEpisodeUrl(SearchResult source, int episode) async {
    try {
      final repo = ref.read(aurisRepositoryProvider);
      final episodeUrl = await repo.resolveEpisodeUrl(source.url, source.source, episode, category: widget.category);
      if (mounted && episodeUrl.isNotEmpty) {
        setState(() {
          _currentSourceUrl = episodeUrl;
        });
      }
    } catch (e) {
      debugPrint('[Resolve-Episode] Failed: $e');
    }
  }

  Widget _buildServerSelectorContent({bool isSidebar = false}) {
    final servers = _groupedSources.keys.toList()
      ..sort((a, b) => sourceDisplayRank(a).compareTo(sourceDisplayRank(b)));
    if (servers.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Text('No se encontraron otros servidores', style: TextStyle(color: Colors.white54)),
      ));
    }

    return ListView.builder(
      shrinkWrap: !isSidebar,
      padding: isSidebar ? const EdgeInsets.only(bottom: 8) : EdgeInsets.zero,
      itemCount: servers.length,
      itemBuilder: (context, index) {
        final sName = servers[index];
        final isCurrent = sName == simplifySourceName(_currentSource);

        return AurisOptionCard(
          title: sName,
          subtitle: '${_groupedSources[sName]!.length} opciones disponibles',
          icon: AurisIcons.server,
          isCurrent: isCurrent,
          autofocus: index == 0,
          onTap: () {
            if (!isSidebar) Navigator.pop(context);
            else setState(() => _activeOverlay = PlayerOverlay.none);

            if (!isCurrent) {
              _switchSource(_groupedSources[sName]!.first);
            }
          },
        );
      },
    );
  }

  /// Cierra el panel lateral y devuelve el foco D-pad a la pill que lo abrió
  /// (estilo YouTube-TV: salir del panel = volver a los controles).
  void _dismissSidePanel() {
    // Escudo anti-doble Back: el Back físico dispara la trampa (tecla) y
    // después el back del sistema (PopScope); sin esto el segundo encuentra
    // el panel ya cerrado y oculta los controles recién mostrados.
    _ignoreNextPop = true;
    Timer(const Duration(milliseconds: 300), () {
      _ignoreNextPop = false;
    });
    // Vuelta atrás de un nivel (Calidad → Configuración).
    if (_overlayParent != null) {
      final parent = _overlayParent!;
      setState(() {
        _activeOverlay = parent;
        _overlayParent = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _sidePanelCloseNode.canRequestFocus) {
          _sidePanelCloseNode.requestFocus();
        }
      });
      return;
    }
    setState(() => _activeOverlay = PlayerOverlay.none);
    _startHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _lastFocusedPillNode ?? _serverPillFocusNode;
      if (target.canRequestFocus) target.requestFocus();
    });
  }

  void _showServerSelector() {
    _hideTimer?.cancel();

    setState(() {
      _overlayParent = null;
      _activeOverlay = _activeOverlay == PlayerOverlay.server ? PlayerOverlay.none : PlayerOverlay.server;
      if (_activeOverlay != PlayerOverlay.none) {
        _showControls = true;
        _hideTimer?.cancel();
      } else {
        _startHideTimer();
      }
    });
    if (_activeOverlay != PlayerOverlay.none) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _sidePanelCloseNode.canRequestFocus) {
          _sidePanelCloseNode.requestFocus();
        }
      });
    }
  }

  void _changeQuality(String quality) {
    if (_selectedQuality == quality) return;

    String? targetUrl;
    Map<String, String> targetHeaders = const {};
    if (quality == 'auto') {
      targetUrl = _isOpEd ? widget.sourceUrl : _currentStreamUrl;
      targetHeaders = _isOpEd ? const <String, String>{} : _currentStreamHeaders;
    } else if (_isOpEd) {
      targetUrl = quality == '720' ? widget.video720 : quality == '1080' ? widget.video1080 : null;
    } else {
      final q = _qualityOptions.firstWhereOrNull((o) => o.key == quality);
      if (q != null) {
        targetUrl = q.url;
        targetHeaders = q.headers;
      }
    }

    if (targetUrl == null || targetUrl.isEmpty) return;

    setState(() {
      _selectedQuality = quality;
      if (_player != null) {
        _resumePosition = _player!.state.position.inMilliseconds;
      }
    });

    _initPlayer(targetUrl, targetHeaders);
  }

  Widget _buildQualitySelectorContent({bool isSidebar = false}) {
    final List<Map<String, dynamic>> options = _qualityMenuOptions;

    return ListView.builder(
      shrinkWrap: !isSidebar,
      padding: isSidebar ? const EdgeInsets.only(bottom: 8) : EdgeInsets.zero,
      itemCount: options.length,
      itemBuilder: (context, index) {
        final option = options[index];
        final String key = option['key'] as String;
        final String label = option['label'] as String;
        final String sub = option['sub'] as String? ?? '';
        final String? url = option['url'] as String?;
        final bool isAvailable = url != null && url.isNotEmpty;
        final bool isCurrent = _selectedQuality == key;

        return AurisOptionCard(
          title: label,
          subtitle: isAvailable ? sub : 'No disponible para este tema',
          icon: AurisIcons.hd,
          isCurrent: isCurrent,
          isAvailable: isAvailable,
          autofocus: index == 0,
          onTap: () {
            if (!isSidebar) Navigator.pop(context);
            else setState(() => _activeOverlay = PlayerOverlay.none);
            
            if (isAvailable && !isCurrent) {
              _changeQuality(key);
            }
          },
        );
      },
    );
  }

  BoxDecoration get _controlCapsuleDecoration => BoxDecoration(
    color: Colors.black.withValues(alpha: 0.45),
    borderRadius: BorderRadius.circular(22), // Unificado radio para alto 44
  );

  void _toggleMute() {
    setState(() {
      if (_volume > 0) {
        _lastAppliedVolume = _volume;
        _volume = 0;
      } else {
        _volume = _lastAppliedVolume > 0 ? _lastAppliedVolume : 1.0;
      }
      _applyVolume();
    });
  }

  Widget _buildVolumePill() {
    final bool isBoost = _volume > 1.0;
    final int displayPercent = (_volume * 100).round();
    
    String volIcon = AurisIcons.volumeUp;
    if (_volume == 0) volIcon = AurisIcons.volumeMute;
    else if (_volume <= 0.5) volIcon = AurisIcons.volumeDown;
    else if (isBoost) volIcon = AurisIcons.speedometer;

    return MouseRegion(
      onEnter: (_) {
        _volumeExitTimer?.cancel();
        if (!_isVolumePillHovered) setState(() => _isVolumePillHovered = true);
      },
      onExit: (_) {
        _volumeExitTimer?.cancel();
        _volumeExitTimer = Timer(const Duration(milliseconds: 150), () {
          if (mounted) setState(() => _isVolumePillHovered = false);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuart,
        height: 44,
        width: _isVolumePillHovered ? 220 : 44, // Unificado a 44px colapsado
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggleMute,
            hoverColor: Colors.white.withValues(alpha: 0.12),
            splashColor: Colors.white.withValues(alpha: 0.08),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 4), // Margen de seguridad interna para el icono
                SizedBox(
                  width: 36, height: 36,
                  child: Center(
                    child: AurisIcon(volIcon, color: isBoost ? const Color(0xFFEF7A1E) : Colors.white, size: 24),
                  ),
                ),
                if (_isVolumePillHovered) ...[
                  const SizedBox(width: 4),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                        activeTrackColor: isBoost ? const Color(0xFFEF7A1E) : Colors.white,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: isBoost ? const Color(0xFFEF7A1E) : Colors.white,
                        overlayColor: (isBoost ? const Color(0xFFEF7A1E) : Colors.white).withOpacity(0.2),
                      ),
                      child: Slider(
                        value: _volume,
                        min: 0.0,
                        max: 2.0,
                        onChanged: (v) {
                          setState(() {
                            _volume = v;
                            _applyVolume();
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 45,
                    child: Text(
                      '$displayPercent%',
                      style: TextStyle(
                        color: isBoost ? const Color(0xFFEF7A1E) : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<({String server, SearchResult result, bool isTrack, int trackIndex})> _getLanguageOptions() {
    final currentSName = simplifySourceName(_currentSource);
    final baseOptions = _groupedSources[currentSName] ?? [];
    final sourceOptions = <({String server, SearchResult result, bool isTrack, int trackIndex})>[];

    if (_allTracks.isNotEmpty) {
      for (int i = 0; i < _allTracks.length; i++) {
        final t = _allTracks[i];
        final labelLower = t.label.toLowerCase();

        final String quality;
        if (t.quality.isNotEmpty) {
          quality = t.quality.toUpperCase();
        } else {
          final isLatinoTrack = labelLower.contains('latino') || labelLower.contains('dub');
          final isCastellanoTrack = labelLower.contains('castellano');
          quality = isLatinoTrack ? 'DUB' : (isCastellanoTrack ? 'CAST' : 'SUB');
        }

        sourceOptions.add((
          server: currentSName,
          result: SearchResult(
            title: widget.contentId,
            url: t.url,
            source: _currentSource,
            quality: quality,
            thumbnail: '',
            year: null,
          ),
          isTrack: true,
          trackIndex: i,
        ));
      }
    } else {
      for (final s in baseOptions) {
        sourceOptions.add((server: currentSName, result: s, isTrack: false, trackIndex: -1));
      }
    }

    // Orden de idiomas en el selector: DUB (Latino) -> CAST (Castellano) -> SUB
    int langRank(String q) {
      final type = trackQualityType(q);
      if (type == 'DUB') return 0;
      if (type == 'CAST') return 1;
      return 2; // SUB y demás
    }
    sourceOptions.sort((a, b) {
      final ra = langRank(a.result.quality);
      final rb = langRank(b.result.quality);
      if (ra != rb) return ra - rb;
      return 0;
    });

    return sourceOptions;
  }

  Widget _buildLanguageSelectorContent({bool isSidebar = false}) {
    final sourceOptions = _getLanguageOptions();
    if (sourceOptions.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Text('No hay fuentes disponibles', style: TextStyle(color: Colors.white54)),
      ));
    }

    return ListView.builder(
      shrinkWrap: !isSidebar,
      padding: isSidebar ? const EdgeInsets.only(bottom: 8) : EdgeInsets.zero,
      itemCount: sourceOptions.length,
      itemBuilder: (context, index) {
        final entry = sourceOptions[index];
        final s = entry.result;
        final serverName = entry.server;
        final type = trackQualityType(s.quality);
        final bool isCurrent = entry.isTrack 
            ? entry.trackIndex == _selectedTrackIndex
            : s.url == _currentSourceUrl;

        final titleText = '${entry.isTrack ? _allTracks[entry.trackIndex].label : s.source} ($type)';
        final subtitleText = s.quality.isNotEmpty ? s.quality.toUpperCase() : 'Servidor: $serverName';

        return AurisOptionCard(
          title: titleText,
          subtitle: subtitleText,
          icon: AurisIcons.subtitles,
          isCurrent: isCurrent,
          autofocus: index == 0,
          onTap: () {
            if (!isSidebar) Navigator.pop(context);
            else setState(() => _activeOverlay = PlayerOverlay.none);
            
            if (!isCurrent) {
              if (entry.isTrack) {
                _switchTrack(entry.trackIndex);
              } else {
                _switchSource(s);
              }
            }
          },
        );
      },
    );
  }

  /// Menú raíz del engranaje de configuración: cada fila abre su sub-panel.
  /// Calidad solo aparece cuando hay opciones reales (ver _hasQualityOptions).
  Widget _buildConfigMenuContent({bool isSidebar = false}) {
    final String qualitySub = _selectedQuality == 'auto'
        ? 'Automático'
        : '${_selectedQuality.toUpperCase()}p';
    final bool showQuality = _hasQualityOptions;
    final children = <Widget>[
      if (showQuality)
        AurisOptionCard(
          title: 'Calidad',
          subtitle: qualitySub,
          icon: AurisIcons.hd,
          autofocus: true,
          onTap: () => _openConfigSubPanel(PlayerOverlay.quality),
        ),
      AurisOptionCard(
        title: 'Velocidad',
        subtitle: _formatSpeed(_playbackSpeed),
        icon: AurisIcons.speedometer,
        autofocus: !showQuality,
        onTap: () => _openConfigSubPanel(PlayerOverlay.speed),
      ),
      AurisOptionCard(
        title: 'Boost de volumen',
        subtitle: _volumeLabel,
        icon: AurisIcons.volumeUp,
        isCurrent: _volume > 1.0,
        onTap: () => _openConfigSubPanel(PlayerOverlay.volume),
      ),
    ];
    if (children.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Text('No hay opciones disponibles', style: TextStyle(color: Colors.white54)),
      ));
    }
    return ListView(
      shrinkWrap: !isSidebar,
      padding: isSidebar ? const EdgeInsets.only(bottom: 8) : EdgeInsets.zero,
      children: children,
    );
  }

  /// Abre un sub-panel desde Configuración (vuelta atrás de un nivel).
  void _openConfigSubPanel(PlayerOverlay overlay) {
    setState(() {
      _overlayParent = PlayerOverlay.config;
      _activeOverlay = overlay;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _sidePanelCloseNode.canRequestFocus) {
        _sidePanelCloseNode.requestFocus();
      }
    });
  }

  String _formatSpeed(double speed) =>
      speed == speed.roundToDouble() ? '${speed.toInt()}x' : '${speed}x';

  String get _volumeLabel {
    final percent = (_volume * 100).round();
    return _volume > 1.0 ? '$percent% · Boost' : '$percent%';
  }

  void _setPlaybackSpeed(double speed) {
    if (_playbackSpeed == speed) return;
    setState(() => _playbackSpeed = speed);
    _player?.setRate(speed);
  }

  void _setVolumePreset(double value) {
    // Escudo anti-eco del listener de volumen físico (igual que el slider).
    _lastManualVolumeTime = DateTime.now();
    setState(() => _volume = value);
    _applyVolume();
  }

  static const List<double> _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  Widget _buildSpeedSelectorContent({bool isSidebar = false}) {
    return ListView.builder(
      shrinkWrap: !isSidebar,
      padding: isSidebar ? const EdgeInsets.only(bottom: 8) : EdgeInsets.zero,
      itemCount: _speedOptions.length,
      itemBuilder: (context, index) {
        final speed = _speedOptions[index];
        final bool isCurrent = _playbackSpeed == speed;
        return AurisOptionCard(
          title: _formatSpeed(speed),
          subtitle: speed == 1.0 ? 'Normal' : '',
          icon: AurisIcons.speedometer,
          isCurrent: isCurrent,
          autofocus: index == 0,
          onTap: () {
            if (!isCurrent) _setPlaybackSpeed(speed);
          },
        );
      },
    );
  }

  static const List<double> _volumePresets = [1.0, 1.25, 1.5, 1.75, 2.0];

  Widget _buildVolumeSelectorContent({bool isSidebar = false}) {
    return ListView.builder(
      shrinkWrap: !isSidebar,
      padding: isSidebar ? const EdgeInsets.only(bottom: 8) : EdgeInsets.zero,
      itemCount: _volumePresets.length,
      itemBuilder: (context, index) {
        final value = _volumePresets[index];
        final percent = (value * 100).round();
        final bool isCurrent = (_volume - value).abs() < 0.01;
        return AurisOptionCard(
          title: value >= 2.0 ? '$percent% Máximo' : '$percent%',
          subtitle: value <= 1.0 ? 'Normal' : (value > 1.0 ? 'Boost' : ''),
          icon: AurisIcons.volumeUp,
          isCurrent: isCurrent,
          autofocus: index == 0,
          onTap: () {
            if (!isCurrent) _setVolumePreset(value);
          },
        );
      },
    );
  }

  void _showEpisodesPanel() {
    _hideTimer?.cancel();

    setState(() {
      _overlayParent = null;
      _activeOverlay = _activeOverlay == PlayerOverlay.episodes ? PlayerOverlay.none : PlayerOverlay.episodes;
      if (_activeOverlay != PlayerOverlay.none) {
        _showControls = true;
        _hideTimer?.cancel();
      } else {
        _startHideTimer();
      }
    });
    if (_activeOverlay != PlayerOverlay.none) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _sidePanelCloseNode.canRequestFocus) {
          _sidePanelCloseNode.requestFocus();
        }
      });
    }
  }

  void _selectEpisodeFromPanel(EpisodeInfo ep) {
    final epNum = ep.number;
    if (epNum.toString() == _activeEpisode) return;

    // Prioriza la URL del item o reconstruye con buildEpisodeUrl.
    final String resolvedEpisodeUrl = ep.url.isNotEmpty
        ? ep.url
        : buildEpisodeUrl(_currentSourceUrl, _currentSource ?? '', epNum);

    // Parar el player actual INMEDIATAMENTE para no arrastrar audio.
    _player?.stop();

    // Reemplazar la URL actual para limpiar historial de navegación.
    final String newPath = '/player/${widget.contentId}';
    final queryParameters = Map<String, String>.from(GoRouterState.of(context).uri.queryParameters);
    queryParameters['episode'] = epNum.toString();
    queryParameters['url'] = resolvedEpisodeUrl;
    queryParameters['skipResume'] = '1';

    // Invalidar el extractor para forzar una carga limpia.
    ref.invalidate(extractProvider);

    setState(() {
      _activeOverlay = PlayerOverlay.none;
      _overlayParent = null;
    });
    context.replace(Uri(path: newPath, queryParameters: queryParameters).toString());
  }

  Widget _buildEpisodesSelectorContent({bool isSidebar = false}) {
    final episodesAsync = ref.watch(episodesProvider(EpisodesParams(
      url: _seriesListUrl,
      source: _currentSource,
      title: widget.title ?? '',
      season: widget.season ?? 1,
    )));
    return episodesAsync.when(
      data: (data) {
        if (data == null || data.episodes.isEmpty) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Text('No hay episodios disponibles', style: TextStyle(color: Colors.white54)),
          ));
        }
        final eps = _enrichedEpisodes(data.episodes);
        return ListView.builder(
          shrinkWrap: !isSidebar,
          padding: isSidebar ? const EdgeInsets.only(bottom: 8) : EdgeInsets.zero,
          itemCount: eps.length,
          itemBuilder: (context, index) {
            final ep = eps[index];
            final isCurrent = ep.number.toString() == _activeEpisode;
            return AurisEpisodeListCard(
              ep: ep,
              isCurrent: isCurrent,
              autofocus: isCurrent,
              onTap: () => _selectEpisodeFromPanel(ep),
            );
          },
        );
      },
      loading: () => const Center(child: Padding(
        padding: EdgeInsets.all(32.0),
        child: CircularProgressIndicator(color: Color(0xFFEF7A1E)),
      )),
      error: (err, _) => Center(child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent)),
      )),
    );
  }

  void _showLanguageSelector() {
    _hideTimer?.cancel();

    setState(() {
      _overlayParent = null;
      _activeOverlay = _activeOverlay == PlayerOverlay.language ? PlayerOverlay.none : PlayerOverlay.language;
      if (_activeOverlay != PlayerOverlay.none) {
        _showControls = true;
        _hideTimer?.cancel();
      } else {
        _startHideTimer();
      }
    });
    if (_activeOverlay != PlayerOverlay.none) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _sidePanelCloseNode.canRequestFocus) {
          _sidePanelCloseNode.requestFocus();
        }
      });
    }
  }

  void _showConfigMenu() {
    _hideTimer?.cancel();

    setState(() {
      _overlayParent = null;
      _activeOverlay = _activeOverlay == PlayerOverlay.config ? PlayerOverlay.none : PlayerOverlay.config;
      if (_activeOverlay != PlayerOverlay.none) {
        _showControls = true;
        _hideTimer?.cancel();
      } else {
        _startHideTimer();
      }
    });
    if (_activeOverlay != PlayerOverlay.none) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _sidePanelCloseNode.canRequestFocus) {
          _sidePanelCloseNode.requestFocus();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void _toggleFullscreen() {
    if (kIsWeb) {
      final bool isTactic = ResponsiveUtils.isTactic(context);
      
      // Senior Web Logic: Si es Web Móvil y ya estamos en "Modo Fullscreen" (browser),
      // el botón actúa como ciclo de ajuste (Fit/Fill/Cover) según pidió el usuario.
      if (isTactic && _isFullscreen) {
        _cycleVideoFit();
        return;
      }

      // Si no estamos en fullscreen (o es escritorio), hacemos el toggle de modo browser.
      setState(() {
        _isFullscreen = !_isFullscreen;
        _isMobileDevice = isTactic;
        setAppFullscreen(_isFullscreen);
      });
      return;
    }

    // App Nativa: Siempre es ciclo de ajuste porque el player ya ocupa toda la pantalla.
    if (_useVideoFitCycle) {
      _cycleVideoFit();
      return;
    }

    // Desktop Nativo (Windows/Linux/macOS)
    setState(() {
      _isFullscreen = !_isFullscreen;
      setAppFullscreen(_isFullscreen);
    });
  }

  /// Ciclo de formato del video en móvil/tablet (el player ya está a pantalla
  /// completa): contain → fill (estirar a los bordes) → cover (rellenar sin
  /// estirar la imagen) → contain.
  void _cycleVideoFit() {
    setState(() {
      _videoFit = switch (_videoFit) {
        BoxFit.contain => BoxFit.fill,
        BoxFit.fill => BoxFit.cover,
        _ => BoxFit.contain,
      };
    });
  }

  void _retryPlayback() {
    setState(() => _playbackError = null);
    if (_lastVideoUrl.isNotEmpty) {
      _initPlayer(_lastVideoUrl, _lastVideoHeaders);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _navigateToEpisode(bool next) async {
    if (_isTrailer || _currentEpisode == null) return;
    final currentNum = int.tryParse(_currentEpisode!) ?? 1;
    final nextNum = next ? currentNum + 1 : currentNum - 1;
    if (nextNum < 1) return;

    // Senior Autoplay Fix: Parar el player actual INMEDIATAMENTE para
    // que no se siga escuchando el episodio anterior durante la carga del nuevo.
    _player?.stop();
    if (_webViewController != null) {
      _webViewController = null;
    }

    final sources = ref.read(activeContentSourcesProvider);
    // Match tolerante + fallback a la primera fuente: si el nombre no matchea,
    // reusar la URL actual re-extraía el episodio ANTERIOR (reiniciado).
    final baseSource = findSourceByName(sources, _currentSource) ??
        (sources.isNotEmpty ? sources.first : null);

    // Senior Navigation Fix: Calcular la URL del episodio destino ANTES de reemplazar
    // la ruta. context.replace recrea la pantalla (GoRouter usa la URI como page key),
    // por lo que el query param 'url' debe ser la del NUEVO episodio, no la actual,
    // o el extract provider re-extraería la página del episodio anterior (bug E2->E3).
    final String nextSourceUrl = baseSource != null
        ? buildEpisodeUrl(baseSource.url, baseSource.source, nextNum)
        : _currentSourceUrl;

    // Senior Navigation Fix: Actualizar la URL de la ruta sin añadir una nueva entrada al historial
    // para que el botón "Atrás" (Mouse 4) no nos regrese al episodio anterior.
    final String newPath = '/player/${widget.contentId}';
    final queryParams = Map<String, String>.from(GoRouterState.of(context).uri.queryParameters);
    queryParams['episode'] = nextNum.toString();
    queryParams['url'] = nextSourceUrl;
    if (next) {
      queryParams['skipResume'] = '1';
    } else {
      queryParams.remove('skipResume');
    }
    // Senior Language Fix: Persistir el idioma que el usuario eligió realmente
    // (por si cambió la pista manualmente), para que el siguiente episodio
    // mantenga LAT/SUB aunque la pantalla se reconstruya.
    
    // Usamos context.replace para sustituir la entrada actual en el historial
    // Esto asegura que al retroceder (Mouse 4) no volvamos al episodio anterior.
    context.replace(Uri(path: newPath, queryParameters: queryParams).toString());

    final preloaded = ref.read(nextEpisodePreloadProvider);
    final preloadTarget = ref.read(nextEpisodePreloadTargetProvider);
    // Solo consumir el preload si es para ESTE destino (url+episodio). Un
    // preload stale reproduciría el episodio equivocado; se limpia y se sigue
    // por extracción fresca.
    final bool preloadValid = preloaded != null &&
        next &&
        preloadTarget != null &&
        preloadTarget.url == nextSourceUrl &&
        preloadTarget.episode == nextNum;
    if (!preloadValid && preloaded != null) {
      ref.read(playerPreloadControllerProvider).clearPreload();
    }
    if (preloadValid) {
      final tracks = preloaded.tracks.where((t) => !t.isDownload).toList();
      
      _autoplayTimer?.cancel();
      ref.read(playerPreloadControllerProvider).clearPreload();

      setState(() {
        _currentEpisode = nextNum.toString();
        _currentSourceUrl = nextSourceUrl;
        _isStabilizing = true;
        _isLoading = true;
        _hasInitialized = true;
        _skipResumeOnNextInit = true;
        _resumePosition = 0;
        _isAutoplayResume = false;
        _hasResetPosition = false;
        _showNextNotifier.value = false;
        _autoplayCountdown = -1;
      });

      if (tracks.isNotEmpty) {
        // Senior Language Fix: Respetar el idioma elegido (LAT/SUB) al reproducir
        // el episodio pre-cargado, con fallback a SUB si el doblaje aún no existe.
        final trackIdx = _indexForLanguage(tracks);
        final initialTrack = tracks[trackIdx];
        _selectedTrackIndex = trackIdx;
        // Senior Quality Fix: Cargar las calidades de la pista pre-cargada.
        _applyTrackQualityOptions(initialTrack);
        if (initialTrack.isEmbed) {
          _initEmbedPlayer(initialTrack.url, initialTrack.headers);
        } else {
          _initPlayer(initialTrack.url, initialTrack.headers);
        }
      }
      return;
    }
    
    if (baseSource != null) {
      _autoplayTimer?.cancel();
      setState(() {
        _hasInitialized = false; 
        _currentEpisode = nextNum.toString();
        _currentSourceUrl = nextSourceUrl;
        _isStabilizing = true;
        _skipResumeOnNextInit = true;
        _resumePosition = 0;
        _isAutoplayResume = false;
        _hasResetPosition = false;
        _showNextNotifier.value = false;
        _autoplayCountdown = -1;
      });

      if (baseSource.source == 'Aniyae') {
        _resolveEpisodeUrl(baseSource, nextNum);
      }
    }
  }

  /// Senior Language Strategy: Selecciona automáticamente la pista inicial basándose 
  /// exclusivamente en los Ajustes del Usuario, ignorando etiquetas externas.
  /// Prioridad: Preferencia -> SUB (como fallback universal) -> Primera disponible.
  int _indexForLanguage(List<VideoTrackOption> tracks) {
    if (tracks.isEmpty) return 0;

    final settings = ref.read(settingsProvider);
    final String pref = settings.preferredLanguage.toLowerCase();
    
    // Mapeo de preferencia a tipo de track técnico
    final String targetType = pref == 'latino' ? 'DUB' : (pref == 'castellano' ? 'CAST' : 'SUB');

    final latIdx = tracks.indexWhere((t) => trackQualityType(t.quality) == 'DUB');
    final castIdx = tracks.indexWhere((t) => trackQualityType(t.quality) == 'CAST');
    final subIdx = tracks.indexWhere((t) => trackQualityType(t.quality) == 'SUB');

    // 1. Intentar coincidir con la preferencia exacta
    if (targetType == 'DUB' && latIdx >= 0) return latIdx;
    if (targetType == 'CAST' && castIdx >= 0) return castIdx;
    if (targetType == 'SUB' && subIdx >= 0) return subIdx;

    // 2. Fallback Senior: Si la preferencia no está disponible (ej: no hay DUB aún), 
    // siempre priorizamos SUB antes que cualquier otra cosa para asegurar contenido.
    if (subIdx >= 0) return subIdx;

    // 3. Last Resort: La primera pista que responda (normalmente el servidor original)
    return latIdx >= 0 ? latIdx : (castIdx >= 0 ? castIdx : 0);
  }

  /// Senior Quality Fix: Aplica las calidades de la pista seleccionada y resetea
  /// la selección a "auto" si la pista nueva no las ofrece (o solo tiene una).
  void _applyTrackQualityOptions(VideoTrackOption track) {
    final newQualities = track.qualities;
    final settings = ref.read(settingsProvider);

    setState(() {
      _qualityOptions = newQualities;
      if (newQualities.length <= 1) {
        _selectedQuality = 'auto';
      } else {
        // Senior Fix: Intentar coincidir con la calidad preferida del usuario
        final pref = settings.preferredQuality.replaceAll('p', '');
        if (pref == 'auto') {
          _selectedQuality = 'auto';
        } else {
          final found = newQualities.firstWhereOrNull((q) => q.key.contains(pref));
          _selectedQuality = found?.key ?? 'auto';
        }
      }
    });
  }

  /// Opciones mostradas en el selector de calidad (OP/ED + episodios con HLS).
  List<Map<String, dynamic>> get _qualityMenuOptions {
    if (_isOpEd) {
      return [
        {'key': 'auto', 'label': 'Automático', 'sub': 'Mejor calidad disponible', 'url': widget.sourceUrl, 'headers': const <String, String>{}},
        {'key': '720', 'label': '720p HD', 'sub': 'Calidad Estándar', 'url': widget.video720, 'headers': const <String, String>{}},
        {'key': '1080', 'label': '1080p FHD', 'sub': 'Alta Definición', 'url': widget.video1080, 'headers': const <String, String>{}},
      ];
    }
    return [
      {'key': 'auto', 'label': 'Automático', 'sub': 'Mejor calidad disponible', 'url': _currentStreamUrl, 'headers': _currentStreamHeaders},
      ..._qualityOptions.map((q) => {
        'key': q.key,
        'label': q.label,
        'sub': q.bandwidth != null ? '${(q.bandwidth! / 1000).round()} Kbps' : '',
        'url': q.url,
        'headers': q.headers,
      }),
    ];
  }

  /// ¿Debe mostrarse el botón de calidad? Solo si hay más de una opción real.
  bool get _hasQualityOptions {
    if (_isOpEd) {
      return (widget.video720?.isNotEmpty ?? false) || (widget.video1080?.isNotEmpty ?? false);
    }
    return _qualityOptions.length > 1;
  }

  void _startAutoplayCountdown({bool isResume = false}) {
    // Senior Fix: Respetar la preferencia de Autoplay del usuario
    final settings = ref.read(settingsProvider);
    if (!isResume && (!settings.autoPlayNextEpisode || !_policy.autoPlayNext)) return;
    
    // Evitar reiniciar si ya está corriendo el mismo tipo de cuenta atrás
    if (_autoplayTimer != null && _autoplayTimer!.isActive && _isAutoplayResume == isResume) {
      return;
    }

    if (!isResume) {
      final nextNum = (int.tryParse(_currentEpisode ?? '0') ?? 0) + 1;
      if (widget.totalEpisodes != null && nextNum > widget.totalEpisodes!) return;
    }

    setState(() {
      _autoplayCountdown = 5;
      _isAutoplayResume = isResume;
    });

    _autoplayTimer?.cancel();
    _autoplayTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_autoplayCountdown > 0) {
        setState(() => _autoplayCountdown--);
      } else {
        timer.cancel();
        if (_isAutoplayResume) {
          _handleResumeAction();
        } else {
          _navigateToEpisode(true);
        }
      }
    });
  }

  void _handleResumeAction() {
    _autoplayTimer?.cancel();
    setState(() {
      _autoplayCountdown = -1;
      _isAutoplayResume = false;
      _isCompleted = false;
      _hasResetPosition = true;
      _isStabilizing = true;
      _lastManualSeekTime = DateTime.now();
      _lastStablePositionMs = _resumePosition;
    });

    if (kIsWeb || (_player?.state.position.inMilliseconds ?? 0) < 3000) {
      _player?.seek(Duration(milliseconds: _resumePosition));
    }
    _userHasPaused = false;
    _player?.play();

    _startHideTimer();
    _startStabilizationTimer();

    _updateHistory(
      positionMs: _resumePosition,
      durationMs: (_player?.state.duration.inMilliseconds ?? 0),
      force: true,
    );
  }

  void _handleRestartAction() {
    _autoplayTimer?.cancel();
    setState(() {
      _autoplayCountdown = -1;
      _isAutoplayResume = false;
      _isCompleted = false;
      _hasResetPosition = true;
    });
    if (!_isOpEd) _historyNotifier?.deleteProgress(widget.contentId, widget.season, _activeEpisode);
    _player?.seek(Duration.zero);
    _userHasPaused = false;
    _player?.play();
    _startHideTimer();
  }

  void _handlePlayPause() {
    final wasPlaying = _player?.state.playing ?? false;
    if (wasPlaying) {
      _userHasPaused = true;
      _player?.pause();
      final ms = _player?.state.position.inMilliseconds ?? 0;
      final duration = _player?.state.duration.inMilliseconds ?? 0;
      if (ms > 3000 && duration > 0) {
        _updateHistory(
          positionMs: ms,
          durationMs: duration,
          force: true,
        );
      }
    } else {
      _userHasPaused = false;
      _player?.play();
    }
  }

  void _handleVolumeStep(double step) {
    _lastManualVolumeTime = DateTime.now();
    _safeSetState(() {
      double currentSnapped = (_volume * 20).round() / 20.0;
      double nextVol = currentSnapped + step;

      if (currentSnapped < 1.0 && nextVol > 1.0) nextVol = 1.0;
      else if (currentSnapped > 1.0 && nextVol < 1.0) nextVol = 1.0;
      else if ((nextVol - 1.0).abs() < 0.02) nextVol = 1.0;
      
      _volume = nextVol.clamp(0.0, 2.0);
      _applyVolume();
    });
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (_isExiting) return KeyEventResult.ignored;
    final key = event.logicalKey;

    // Reiniciar timer de ocultación en cualquier interacción de teclado / D-PAD
    if (_showControls && (event is KeyDownEvent || event is KeyRepeatEvent)) {
      _startHideTimer();
    }

    // Physical Remote Buttons (Media Keys)
    if (event is KeyDownEvent) {
      if (key == LogicalKeyboardKey.mediaPlay || key == LogicalKeyboardKey.mediaPause || key == LogicalKeyboardKey.mediaPlayPause) {
        _handlePlayPause();
        if (!_showControls) {
          setState(() => _showControls = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _timelineFocusNode.canRequestFocus) {
              _timelineFocusNode.requestFocus();
            }
          });
        }
        _startHideTimer();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.mediaStop) {
        _handleBackNavigation();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.mediaTrackNext) {
        _navigateToEpisode(true);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.mediaTrackPrevious) {
        _navigateToEpisode(false);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.mediaFastForward) {
        _skipForward();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.mediaRewind) {
        _skipBackward();
        return KeyEventResult.handled;
      }
    }

    // Volume Keys
    final isVolumeKey = key == LogicalKeyboardKey.audioVolumeUp || key == LogicalKeyboardKey.audioVolumeDown;
    if (isVolumeKey) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        _handleVolumeStep((key == LogicalKeyboardKey.audioVolumeUp) ? 0.05 : -0.05);
      }
      return KeyEventResult.handled;
    }

    // 1. SI LOS CONTROLES ESTÁN OCULTOS: Cualquier flecha o botón central los muestra
    if (!_showControls) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        if (key == LogicalKeyboardKey.arrowUp || 
            key == LogicalKeyboardKey.arrowDown || 
            key == LogicalKeyboardKey.arrowLeft || 
            key == LogicalKeyboardKey.arrowRight || 
            key == LogicalKeyboardKey.select || 
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter ||
            key == LogicalKeyboardKey.space) {
          
          setState(() {
            _showControls = true;
          });
          _startHideTimer();

          // Despertar direccional desde el ancla (timeline): arriba = header,
          // abajo = pills, resto = timeline (+ su acción de seek/toggle).
          final FocusNode wakeTarget;
          if (key == LogicalKeyboardKey.arrowUp) {
            wakeTarget = _headerFocusNode;
          } else if (key == LogicalKeyboardKey.arrowDown) {
            wakeTarget = _lastFocusedPillNode ?? _serverPillFocusNode;
          } else {
            wakeTarget = _timelineFocusNode;
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && wakeTarget.canRequestFocus) {
              wakeTarget.requestFocus();
            }
          });

          if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyJ) _skipBackward();
          if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyL) _skipForward();
          // Con controles ocultos, OK/centro alterna play/pausa directo
          // (solo al pulsar, no al mantener, para no hacer strobe).
          if (event is KeyDownEvent &&
              (key == LogicalKeyboardKey.space ||
                  key == LogicalKeyboardKey.keyK ||
                  key == LogicalKeyboardKey.select ||
                  key == LogicalKeyboardKey.enter ||
                  key == LogicalKeyboardKey.numpadEnter)) {
            _handlePlayPause();
          }
          
          return KeyEventResult.handled;
        }
      }
    }

    // 2. SI LOS CONTROLES YA ESTÁN VISIBLES:
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      // Escape / Back
      if (key == LogicalKeyboardKey.escape ||
          key == LogicalKeyboardKey.goBack ||
          key == LogicalKeyboardKey.browserBack) {
        _handleBackNavigation();
        return KeyEventResult.handled;
      }

      // Space / PlayPause key
      if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) {
        _handlePlayPause();
        _startHideTimer();
        return KeyEventResult.handled;
      }

      // Left / Right Arrows (O J / L)
      if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyJ) {
        final primaryFocus = FocusManager.instance.primaryFocus;
        if (primaryFocus == null || primaryFocus == _timelineFocusNode || primaryFocus == _playerFocusNode || primaryFocus.debugLabel == 'video_surface' || !primaryFocus.hasPrimaryFocus) {
          _skipBackward();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      }

      if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyL) {
        final primaryFocus = FocusManager.instance.primaryFocus;
        if (primaryFocus == null || primaryFocus == _timelineFocusNode || primaryFocus == _playerFocusNode || primaryFocus.debugLabel == 'video_surface' || !primaryFocus.hasPrimaryFocus) {
          _skipForward();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      }

      // Up / Down Arrows
      if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
        return KeyEventResult.ignored;
      }

      // Fullscreen & Mute shortcuts
      if (key == LogicalKeyboardKey.keyF) {
        _toggleFullscreen();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyM) {
        _toggleMute();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted && !_isExiting) {
      setState(fn);
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Senior Shield: Ignorar cambios de métricas si el widget ya no está activo o está saliendo
    if (!mounted || _isExiting) return;

    // Sincronizar el estado de pantalla completa real (especialmente útil en Web con ESC)
    if (kIsWeb) {
      final bool realFullscreen = isAppFullscreen();
      if (realFullscreen != _isFullscreen) {
        _safeSetState(() {
          _isFullscreen = realFullscreen;
        });
      }
    } else {
      _safeSetState(() {});
    }
    
    // Segundo ciclo para asegurar ajuste Web/Móvil tras rotación física
    Future.delayed(const Duration(milliseconds: 100), () {
      _safeSetState(() {});
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    // Sin exenciones por foco: cualquier tecla en timeline/header/pills
    // vuelve a mostrar los controles, así que ocultar con foco aparcado
    // es seguro y evita que queden encendidos eternamente.
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _showControls = false);
        // Ancla neutral: con controles ocultos el foco vive en el timeline.
        if (_timelineFocusNode.canRequestFocus) _timelineFocusNode.requestFocus();
      }
    });
  }

  void _toggleControls() {
    if (!mounted) return;
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _startHideTimer();
      } else if (_timelineFocusNode.canRequestFocus) {
        _timelineFocusNode.requestFocus();
      }
    });
  }

  // _showCentralIndicator removed

  void _skipForward() {
    final now = DateTime.now();
    // Senior Logic: Soporte para "Rapid Fire" con acumulación (YouTube Style)
    final bool isRapidFire = _lastManualSeekTime != null && 
                             now.difference(_lastManualSeekTime!).inMilliseconds < 800;
    
    final current = isRapidFire 
        ? Duration(milliseconds: _lastFrameMs) 
        : (_player?.state.position ?? Duration.zero);
        
    final target = current + const Duration(seconds: 10);
    _isStabilizing = true;
    _lastManualSeekTime = now;
    _lastFrameMs = target.inMilliseconds;
    _lastStablePositionMs = target.inMilliseconds;
    
    _player?.seek(target);

    setState(() {
      _showControls = true;
    });

    HapticFeedback.lightImpact();
    _startHideTimer();
    _startStabilizationTimer();
    
    _updateHistory(
      positionMs: _lastFrameMs,
      durationMs: _player?.state.duration.inMilliseconds ?? 0,
      force: true,
    );
  }

  void _skipBackward() {
    final now = DateTime.now();
    // Senior Logic: Soporte para "Rapid Fire" con acumulación
    final bool isRapidFire = _lastManualSeekTime != null && 
                             now.difference(_lastManualSeekTime!).inMilliseconds < 800;
                             
    final current = isRapidFire 
        ? Duration(milliseconds: _lastFrameMs) 
        : (_player?.state.position ?? Duration.zero);
        
    final target = current - const Duration(seconds: 10);
    _isStabilizing = true;
    _lastManualSeekTime = now;
    final finalTarget = target < Duration.zero ? Duration.zero : target;
    _lastFrameMs = finalTarget.inMilliseconds;
    _lastStablePositionMs = finalTarget.inMilliseconds;
    
    _player?.seek(finalTarget);

    setState(() {
      _showControls = true;
    });

    HapticFeedback.lightImpact();
    _startHideTimer();
    _startStabilizationTimer();

    _updateHistory(
      positionMs: _lastFrameMs,
      durationMs: _player?.state.duration.inMilliseconds ?? 0,
      force: true,
    );
  }

  /// Hold-scrub estilo YouTube TV: al mantener ←/→ en el timeline el
  /// objetivo avanza por ticks acelerados con preview, y UN solo seek se
  /// confirma al soltar. Un toque simple equivale al ±10s de antes.
  void _beginHoldScrub(int dir) {
    if (_holdDir != 0) return;
    final pos = _player?.state.position.inMilliseconds ?? 0;
    final dur = _player?.state.duration.inMilliseconds ?? 0;
    if (dur <= 0) return;
    _holdDir = dir;
    _holdBaseMs = pos;
    _holdStart = DateTime.now();
    final target = (pos + dir * 10000).clamp(0, dur);
    setState(() {
      _showControls = true;
      _seekTargetDuration = Duration(milliseconds: target);
      _seekDiff = Duration(milliseconds: target - pos);
    });
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _tickHoldScrub(),
    );
    HapticFeedback.selectionClick();
  }

  void _tickHoldScrub() {
    if (_holdDir == 0 || _player == null || !mounted) return;
    final dur = _player!.state.duration.inMilliseconds;
    if (dur <= 0) return;
    final elapsed = DateTime.now().difference(_holdStart ?? DateTime.now());
    final int stepMs;
    if (elapsed < const Duration(seconds: 1)) {
      stepMs = 10000;
    } else if (elapsed < const Duration(seconds: 3)) {
      stepMs = 30000;
    } else {
      stepMs = 60000;
    }
    final target =
        (_seekTargetDuration.inMilliseconds + _holdDir * stepMs).clamp(0, dur);
    setState(() {
      _seekTargetDuration = Duration(milliseconds: target);
      _seekDiff = Duration(milliseconds: target - _holdBaseMs);
    });
    _startHideTimer();
  }

  void _endHoldScrub() {
    final timer = _holdTimer;
    _holdTimer = null;
    timer?.cancel();
    if (_holdDir == 0 || !mounted) {
      _holdDir = 0;
      return;
    }
    _holdDir = 0;
    final targetMs = _seekTargetDuration.inMilliseconds;
    if (_player == null) return;
    _isStabilizing = true;
    _lastManualSeekTime = DateTime.now();
    _lastFrameMs = targetMs;
    _lastStablePositionMs = targetMs;
    _player?.seek(Duration(milliseconds: targetMs));
    HapticFeedback.mediumImpact();
    _startHideTimer();
    _startStabilizationTimer();
    _updateHistory(
      positionMs: targetMs,
      durationMs: _player?.state.duration.inMilliseconds ?? 0,
      force: true,
    );
  }

  void _restartToBeginning() {
    _isStabilizing = true;
    _isCompleted = false;
    _lastManualSeekTime = DateTime.now();
    _lastFrameMs = 0;
    _lastStablePositionMs = 0;
    _player?.seek(Duration.zero);
    _startStabilizationTimer();
    _updateHistory(
      positionMs: 0,
      durationMs: _player?.state.duration.inMilliseconds ?? 0,
      force: true,
    );
    setState(() {
      _showControls = true;
    });
    HapticFeedback.lightImpact();
    _startHideTimer();
  }

  void _skipOpEd() {
    final current = _player?.state.position ?? Duration.zero;
    final target = current + const Duration(seconds: 85);
    _isStabilizing = true;
    _lastManualSeekTime = DateTime.now();
    _lastFrameMs = target.inMilliseconds;
    _lastStablePositionMs = target.inMilliseconds;
    
    _player?.seek(target);
    
    _startHideTimer();
    _startStabilizationTimer();

    _updateHistory(
      positionMs: target.inMilliseconds,
      durationMs: _player?.state.duration.inMilliseconds ?? 0,
      force: true,
    );
  }

  void _startStabilizationTimer() {
    _stabilizationTimer?.cancel();
    // Senior: 3s es el equilibrio perfecto entre seguridad y experiencia de usuario
    _stabilizationTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isStabilizing = false);
    });
  }

  Future<void> _initPlayer(String videoUrl, [Map<String, String> headers = const {}]) async {
    // En Android el backend devuelve URLs con localhost:3000 (el servidor corre
    // en el PC); hay que apuntar a la IP real de la LAN para que el dispositivo
    // pueda llegar al servidor.
    videoUrl = ApiEndpoints.fixUrl(videoUrl);
    final bool isHls = videoUrl.contains('.m3u8');

    // Senior Quality Fix: Guardar el stream base para poder volver a "Automático".
    _currentStreamUrl = videoUrl;
    _currentStreamHeaders = headers;
    
    // Senior: Obtener historial al inicio para setear la propiedad 'start' de MPV
    // [PlaybackHistory] Ignoramos historial para OP/ED
    final history = _isOpEd ? null : _historyNotifier?.getProgress(widget.contentId, widget.season, _activeEpisode);
    final int historyPos = (history != null && history.positionInMilliseconds > 3000) ? history.positionInMilliseconds : 0;

    final bool isSwitching = _resumePosition > 0;
    // Senior Autoplay Fix: Si venimos de una navegación de episodio, saltamos el
    // diálogo de "reanudar" aunque el widget se haya recreado (widget.skipResume).
    final bool skipResume = _skipResumeOnNextInit || widget.skipResume;
    _skipResumeOnNextInit = false;
    // Invalidar loops de resume-retry de inits anteriores (ver campo).
    _resumeSeekGen++;

    _lastVideoUrl = videoUrl;
    _lastVideoHeaders = headers;
    _playbackError = null;
    _isCompleted = false;
    _loadWatchdogTimer?.cancel();
    _userHasPaused = false;

    setState(() {
      _isLoading = true;
      _autoplayCountdown = -1;
      _isAutoplayResume = false;
      if (!isSwitching) {
        if (!skipResume && widget.startPosition != null && widget.startPosition! > 3000) {
           _resumePosition = widget.startPosition!;
           _hasResetPosition = true;
           WidgetsBinding.instance.addPostFrameCallback((_) {
             if (mounted) _handleResumeAction();
           });
        } else if (!skipResume && historyPos > 0) {
           _resumePosition = historyPos;
           _hasResetPosition = true;
           WidgetsBinding.instance.addPostFrameCallback((_) {
             if (mounted) _handleResumeAction();
           });
        } else {
           _resumePosition = 0;
           _hasResetPosition = true; 
        }
      }
      
      _isStabilizing = true; 
      _lastFrameMs = _resumePosition; 
      _lastStablePositionMs = _resumePosition;
    });

    debugPrint('[player] init resume=${_resumePosition} resumeCountdown=$_isAutoplayResume url=$videoUrl (HLS=$isHls)');

    // Senior Resume Fix: Tras confirmar la reanudación, vigilar la posición
    // durante 30s. Si mpv reinicia el demuxer desde 0 (p.ej. "Could not open
    // codec" en av1), el guard re-aplica el seek al punto de reanudación.
    if (_resumePosition > 3000) {
      _resumeGuardUntil = DateTime.now().add(const Duration(seconds: 30));
      _resumeGuardRetries = 0;
    } else {
      _resumeGuardUntil = null;
      _resumeGuardRetries = 0;
    }

    if (_webViewController != null) {
      setState(() {
        _webViewController = null;
      });
    }

    if (_player == null) {
      _player = Player(configuration: const PlayerConfiguration(bufferSize: 32 * 1024 * 1024));
    }
    final player = _player!;

    _posSubscription?.cancel();
    _bufferingSubscription?.cancel();
    _completedSubscription?.cancel();
    _errorSubscription?.cancel();
    _logSubscription?.cancel();
    _playingSubscription?.cancel();

    // Si el video arranca a reproducirse (p.ej. tras un error de codec no
    // fatal en una pista de audio), retiramos cualquier cartel de error.
    _playingSubscription = player.stream.playing.listen((playing) {
      if (mounted && playing) {
        setState(() {
          _playbackError = null;
          _isLoading = false; 
          _webNeedsInteraction = false; // Si empieza a sonar, ya no necesitamos interaction
        });
        _applyVolume();
      }
    });

    _errorSubscription = player.stream.error.listen((message) {
      if (!mounted) return;
      
      final String errorMsg = message.toString();

      // Senior Web Fix: Detectar bloqueo de autoplay por falta de interacción del usuario
      if (kIsWeb && errorMsg.contains('interact')) {
        debugPrint('[player web] Autoplay bloqueado. Requiere interacción del usuario.');
        setState(() {
          _webNeedsInteraction = true;
          _isLoading = false;
        });
        return;
      }

      if (errorMsg.contains('DEMUXER_ERROR') || errorMsg.contains('COULD_NOT_PARSE')) {
        debugPrint('[player recovery] Detectada URL expirada o error de demuxer ($errorMsg). Re-extrayendo...');
        _retryPlayback();
        return;
      }

      if (kIsWeb && message.contains('interrupted')) {
        debugPrint('[player] Ignorando error de interrupción normal en Web');
        return;
      }

      debugPrint('[player] error: $message');
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        if (player.state.playing) return;
        setState(() {
          _isLoading = false;
          _playbackError = message;
        });
      });
    });

    _logSubscription = player.stream.log.listen((entry) {
      final m = entry.text.toLowerCase();
      if (m.contains('property not found') && m.contains('osc')) return;
      if (m.contains('failed to parse temporal unit')) {
        _diagPosCount++; 
        if (_diagPosCount > 50 && _resetRetryCount < 4) {
           debugPrint('[player] CRITICAL: Massive parsing errors. Forcing Software Fallback...');
           _forceSoftwareRestart(videoUrl, headers);
        }
      }

      if (m.contains('error') ||
          m.contains('fail') ||
          m.contains('cannot') ||
          m.contains('unable')) {
        debugPrint('[player log] ${entry.text}');
      }
    });

    _posSubscription = player.stream.position.listen((pos) {
      if (!mounted) return;
      _reportStatusToRemote(); // Reportar a Auris Remote
      final ms = pos.inMilliseconds;
      final duration = player.state.duration.inMilliseconds;

      // Senior UI Fix: la carga termina cuando la posición avanza de verdad
      // (no al llamar a play()); así el spinner cubre el tiempo de buffering.
      if (ms > 1000 && mounted && _isLoading) {
        setState(() => _isLoading = false);
      }

      if (!_hasResetPosition) {
        if (_resumePosition > 3000) {
          if ((ms - _resumePosition).abs() < 5000) _hasResetPosition = true;
          return;
        } else {
          _hasResetPosition = true; 
          return;
        }
      }

      // Senior Resume Fix: Solo nativo. Si tras confirmar la reanudación la
      // posición cae a ~0 (demuxer reiniciado por error de codec av1/buffering),
      // re-aplicamos el seek al punto de reanudación. Limitado a pocos intentos
      // y se ignora si el usuario buscó manualmente o pausó.
      if (!kIsWeb &&
          _resumePosition > 3000 &&
          _resumeGuardRetries < 3 &&
          _resumeGuardUntil != null &&
          DateTime.now().isBefore(_resumeGuardUntil!) &&
          ms < 1000 &&
          !_userHasPaused &&
          (_lastManualSeekTime == null ||
              DateTime.now().difference(_lastManualSeekTime!) > const Duration(seconds: 5))) {
        _resumeGuardRetries++;
        debugPrint('[player] Resume guard: posición cayó a $ms tras confirmar $_resumePosition. Re-seeking.');
        _lastStablePositionMs = _resumePosition;
        _lastFrameMs = _resumePosition;
        _player?.seek(Duration(milliseconds: _resumePosition));
        _isStabilizing = true;
        _startStabilizationTimer();
        return;
      }

      final bool isTrustworthy = !_isStabilizing && player.state.playing && !player.state.buffering;

      if (isTrustworthy) {
        final int timeDiff = (ms - _lastStablePositionMs).abs();
        if (timeDiff > 600000 && _lastStablePositionMs > 0) {
          debugPrint('[PlaybackHistory] BLOQUEO DE SEGURIDAD: Salto detectado de ${timeDiff/1000}s. Reintentando seek a $_lastStablePositionMs');
          _player?.seek(Duration(milliseconds: _lastStablePositionMs));
          _isStabilizing = true; 
          _startStabilizationTimer();
          return;
        }

        _lastStablePositionMs = ms;
        _resumePosition = ms;

        if ((ms - _lastUiPersistenceMs).abs() > 5000 && ms > 5000 && duration > 0) {
          _lastUiPersistenceMs = ms;
          _updateHistory(positionMs: ms, durationMs: duration);
        }

        if (!_isOpEd) {
          final double progress = ms / duration;
          final Duration remaining = Duration(milliseconds: duration - ms);

          if (_policy.preloadNext && progress >= 0.90) {
            ref.read(playerPreloadControllerProvider).triggerNextPreload(
              currentSource: _currentSource, 
              currentEpisode: _activeEpisode, 
              totalEpisodes: widget.totalEpisodes, 
              currentSourceUrl: _currentSourceUrl,
              category: widget.category,
            );
          }

          bool shouldShowNext = false;
          if (_policy.nextContentThreshold != null && progress >= _policy.nextContentThreshold!) {
            shouldShowNext = true;
          } else if (_policy.remainingTimeThreshold != null && remaining <= _policy.remainingTimeThreshold!) {
            shouldShowNext = true;
          }

          if (shouldShowNext && !_showNextNotifier.value) {
            // DIFERIMIENTO ASÍNCRONO TOTAL: Sacar la actualización del frame actual
            Future.delayed(Duration.zero, () {
              if (mounted) _showNextNotifier.value = true;
            });
          } else if (!shouldShowNext && _showNextNotifier.value) {
            Future.delayed(Duration.zero, () {
              if (mounted) {
                _showNextNotifier.value = false;
                if (_autoplayCountdown >= 0 && !_isAutoplayResume) {
                  _autoplayTimer?.cancel();
                  setState(() => _autoplayCountdown = -1);
                }
              }
            });
          }
        }
      }
      _lastFrameMs = ms;
    });

    _bufferingSubscription = player.stream.buffering.listen((buffering) {
      if (!mounted) return;
      if (player.state.playing && buffering) return;
      _bufferingDebounceTimer?.cancel();
      if (buffering) {
        _bufferingDebounceTimer = Timer(const Duration(milliseconds: 2500), () {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _isLoading = true);
            });
          }
        });
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _isLoading = false);
        });
      }
    });

    _completedSubscription = player.stream.completed.listen((completed) {
      if (mounted) setState(() => _isCompleted = completed);
      
      if (completed && !_isStabilizing) {
        final ms = player.state.position.inMilliseconds;
        final duration = player.state.duration.inMilliseconds;
        if (ms > 0 && _lastStablePositionMs > 0 && (ms - _lastStablePositionMs).abs() > 600000) {
           debugPrint('[player] EOF falso detectado por latencia de red. Ignorando.');
           return;
        }

        if (duration > 0 && ms > (duration * 0.9)) {
           _updateHistory(
            positionMs: duration,
            durationMs: duration,
            force: false,
          );
          if (!_isOpEd && _currentEpisode != null && widget.totalEpisodes != null) {
            final currentEpNum = int.tryParse(_currentEpisode!) ?? 0;
            if (currentEpNum > 0 && currentEpNum < widget.totalEpisodes!) {
              final nextEpNum = currentEpNum + 1;
              _historyNotifier?.updatePosition(
                contentId: widget.contentId,
                season: widget.season,
                episode: nextEpNum.toString(),
                positionMs: 0,
                durationMs: 0,
                title: widget.title,
                posterUrl: widget.posterUrl,
                bannerUrl: widget.bannerUrl,
                category: widget.category,
                source: widget.source,
                force: true,
              );
            }
          }
          if (!_isOpEd && _autoplayCountdown == -1) _startAutoplayCountdown(isResume: false);
        }
      }
    });

    final Map<String, String> finalHeaders = Map.from(headers);
    if (videoUrl.contains('animethemes.moe') && !finalHeaders.containsKey('Referer')) {
      finalHeaders['Referer'] = 'https://animethemes.moe/';
    }

    try {
      final platform = player.platform as dynamic;
      if (!kIsWeb) {
        // Senior Balanced TV Buffer Tuning:
        // Priorizamos estabilidad visual y sincronización perfecta en pantallas grandes.
        platform.setProperty('msg-level', 'all=error');
        platform.setProperty('cache', 'yes');
        platform.setProperty('cache-on-disk', 'no');
        
        // Colchón generoso de 512MB RAM
        platform.setProperty('demuxer-max-bytes', '536870912'); 
        // Adelanto de 2 minutos para estabilidad total
        platform.setProperty('demuxer-readahead-secs', '120');
        
        platform.setProperty('video-sync', 'display-resample'); 
        platform.setProperty('mc', '0.1'); 
        platform.setProperty('autosync', '1'); 
        
        // Colchón de audio estable (5s)
        platform.setProperty('audio-buffer', '5'); 
        platform.setProperty('volume-max', '200');
        platform.setProperty('cache-pause', 'yes'); 
        
        // Bloque de lectura equilibrado
        platform.setProperty('stream-buffer-size', '16MiB'); 
        
        platform.setProperty('vd-lavc-threads', '8'); 
        platform.setProperty('hwdec', 'no'); // Senior Fix: Software decoding para evitar frames rotos y parpadeos
        platform.setProperty('tls-verify', 'no');
        
        // Suavizamos el parseo para evitar corrupción visual en el arranque
        platform.setProperty('demuxer-lavf-o', 'probesize=10000000,analyzeduration=10000000,seek2any=1');
        platform.setProperty('user-agent', finalHeaders['User-Agent'] ?? 'Mozilla/5.0');

        if (finalHeaders.containsKey('Referer')) {
          platform.setProperty('referrer', finalHeaders['Referer']!);
        }
      }
    } catch (_) {}

    _controller ??= VideoController(player, configuration: const VideoControllerConfiguration(androidAttachSurfaceAfterVideoParameters: false));

    // Senior Web Fix: Auto-Fullscreen en Web Móvil al abrir el reproductor
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ResponsiveUtils.isTactic(context)) {
          if (!_isFullscreen) {
            // Forzamos que la UI detecte modo táctil/móvil antes de entrar
            setState(() => _isMobileDevice = true);
            _toggleFullscreen();
          }
        }
      });
    }

    // --- FLUJO SEQUENCIAL DE ALTA ESTABILIDAD (SOLO NATIVO) ---
    if (!kIsWeb) {
      debugPrint('[player] 1. STOP & CLEAN');
      await player.stop();
      
      debugPrint('[player] 2. OPEN NEW SOURCE (play: false)');
      // Senior Fix: Para MP4 convencionales, forzar recarga total del demuxer
      await player.open(
        Media(
          videoUrl, 
          httpHeaders: finalHeaders,
        ), 
        play: false
      );
      
      debugPrint('[player] 3. WAIT UNTIL PARSED (Polling duration)');
      int timeout = 0;
      while (player.state.duration == Duration.zero && timeout < 60) {
        await Future.delayed(const Duration(milliseconds: 100));
        timeout++;
      }
      
      if (_resumePosition > 3000) {
        debugPrint('[player] 4. RESUME SEEK to $_resumePosition (Duration: ${player.state.duration})');
        // Senior Fix: Seek absoluto forzado después de que el demuxer está listo.
        // Si mpv lo pierde, _resumeSeekWhenReady (tras el play) verifica y reintenta.
        await player.seek(Duration(milliseconds: _resumePosition));
        // Senior: Retardo mayor para estabilización de hardware tras fallo de codec
        await Future.delayed(const Duration(milliseconds: 1200));
      } else {
        debugPrint('[player] 4. NEW VIDEO (Start from 0)');
        await player.seek(Duration.zero);
      }
      
      if (_isAutoplayResume) {
        debugPrint('[player] 5. PAUSE for Resume Countdown');
        await player.pause();
      } else {
        debugPrint('[player] 5. PLAY');
        await player.play();
        // Senior Autoplay Fix: Garantizar que el stream arranca aunque el motor
        // reporte pausa justo después del open (común en HLS nativo).
        _ensureAutoplay(player);
      }

      if (!_isAutoplayResume && _resumePosition > 3000) {
        // Senior Resume Fix: mpv/media_kit no confirma seek() (retorna sin
        // lanzar excepción). Aunque el demuxer reporte duración y el seek
        // "parezca" aplicado, a veces se pierde y el video arranca desde 0 con
        // el overlay mostrando la posición guardada. Verificamos por posición
        // SIEMPRE en reanudaciones y reintentamos hasta que aterrice.
        unawaited(_resumeSeekWhenReady(
            Duration(milliseconds: _resumePosition), player, _resumeSeekGen));
      }
      
      if (mounted) {
        setState(() {
          // Senior UI Fix: _isLoading se deja en true para el play normal; lo
          // limpia la posición (ms > 1000) cuando el video arranca de verdad.
          // En autoplay-resume (pausado con countdown) sí se limpia para que el
          // countdown de reanudación no quede cubierto por el spinner.
          if (_isAutoplayResume) _isLoading = false;
          _showControls = true;
          _hasResetPosition = true;
          _isStabilizing = false;
        });
        _startHideTimer();
      }
      return;
    }

    // --- FLUJO ESTÁNDAR (WEB / FALLBACK) ---
    // Senior Autoplay Fix: Pausar el stream anterior ANTES de abrir el nuevo para
    // evitar audio de fondo mientras el HLS nuevo carga (cambios de episodio/fuente).
    player.pause();
    player.open(Media(videoUrl, httpHeaders: finalHeaders)).then((_) {
      if (!mounted) return;
      setState(() => _showControls = true);
      _startHideTimer();

      if (_isAutoplayResume) {
        player.pause();
        if (mounted) setState(() => _isLoading = false);
      } else {
        final resumeMs = isSwitching
            ? _resumePosition
            : (skipResume ? _resumePosition : (widget.startPosition ?? _resumePosition));
            
        if (resumeMs > 3000) {
          _isStabilizing = true;
          _hasResetPosition = false;
          
          if (kIsWeb) {
            // Web: HTML5/hls.js ignoran seek() hasta que el media tiene metadata,
            // así que los reintentos a ciegas antes de play() solo añadían ~2.3s
            // de espera muerta. Arrancamos el play de inmediato para que el
            // manifest/segmentos carguen en paralelo y aplicamos el seek en
            // cuanto el elemento <video> esté listo.
            _startStabilizationTimer();
            unawaited(_webResumeSeek(player, resumeMs, _resumeSeekGen));
            player.play();
          } else {
            _startStabilizationTimer();
            player.play();
            setState(() => _isLoading = false);
          }
          _ensureAutoplay(player);
        } else {
          _hasResetPosition = true;
          setState(() => _isLoading = false);
          player.play();
          // Senior Autoplay Fix: En web el elemento <video> puede quedar pausado
          // si play() se emite antes de que esté listo (HLS). Reintentamos.
          _ensureAutoplay(player);
        }
      }
    });
  }

  /// Red de seguridad: si el player quedó en pausa tras abrir el nuevo
  /// stream (mpv puede reportar pause=true durante la carga del HLS),
  /// reintenta el play hasta que efectivamente esté reproduciendo.
  void _ensureAutoplay(Player player) {
    void tryPlay() {
      if (mounted && !player.state.playing && !_isAutoplayResume && !_userHasPaused) {
        player.play();
      }
    }

    // Serie de reintentos que cubren tanto la carga nativa lenta como la
    // creación del elemento <video> en web tras cambiar de episodio.
    Future.delayed(const Duration(milliseconds: 800), tryPlay);
    Future.delayed(const Duration(milliseconds: 2500), tryPlay);
    Future.delayed(const Duration(seconds: 5), tryPlay);
    if (kIsWeb) {
      Future.delayed(const Duration(seconds: 8), tryPlay);
      Future.delayed(const Duration(seconds: 12), tryPlay);
    }
  }

  /// Resume Fix: cuando el seek inicial se emitió con duration==0 (MP4 directo
  /// /progresivo, moov aún sin parsear) el comando falla en silencio y la
  /// reproducción arranca desde 0. Aquí esperamos a que el stream esté listo y
  /// reintentamos el seek absoluto, verificando por posición (no por errores,
  /// que llegan por player.stream y no lanzan excepción).
  Future<void> _resumeSeekWhenReady(Duration target, Player player, int gen) async {
    int waited = 0;
    while (waited < 60 && mounted && gen == _resumeSeekGen) {
      await Future.delayed(const Duration(milliseconds: 100));
      waited++;
      final d = player.state.duration;
      final p = player.state.position.inMilliseconds;
      if (d > Duration.zero) break;
      if (p > 150) break;
    }
    if (!mounted || gen != _resumeSeekGen) return;

    final tMs = target.inMilliseconds;
    for (int attempt = 0; attempt < 3 && mounted && gen == _resumeSeekGen; attempt++) {
      final before = player.state.position.inMilliseconds;
      if (before >= tMs - 2000 && before <= tMs + 4000) {
        debugPrint('[player] Resume confirmado en $before (objetivo $tMs)');
        return;
      }
      if (gen != _resumeSeekGen) return;
      debugPrint('[player] Resume retry seek a $tMs (attempt ${attempt + 1}, pos $before)');
      await player.seek(target);
      // Senior: 900ms de settle; el seek en MP4 progresivo dispara una petición
      // de rango al CDN que tarda en responder por el primer byte.
      await Future.delayed(const Duration(milliseconds: 900));
      final after = player.state.position.inMilliseconds;
      if (after >= tMs - 2000 && after <= tMs + 4000) {
        debugPrint('[player] Resume retry OK -> $after');
        return;
      }
    }
  }

  /// Web Resume Fix: hls.js/HTML5 descartan seek() mientras la metadata no está
  /// lista. En lugar de reintentar a ciegas antes del play (que mantenía el
  /// stream sin cargar ~2.3s), esperamos a que el media arranque (posición > 0
  /// o duración conocida) y ahí sí aplicamos el seek absoluto verificando por
  /// posición. El spinner se oculta al confirmar el salto.
  Future<void> _webResumeSeek(Player player, int targetMs, int gen) async {
    int waited = 0;
    while (waited < 80 && mounted && gen == _resumeSeekGen) {
      await Future.delayed(const Duration(milliseconds: 100));
      waited++;
      if (player.state.position.inMilliseconds > 0) break;
      if (player.state.duration > Duration.zero) break;
    }
    if (!mounted || gen != _resumeSeekGen) return;

    for (int attempt = 0; attempt < 3 && mounted && gen == _resumeSeekGen; attempt++) {
      final before = player.state.position.inMilliseconds;
      if (before >= targetMs - 1500) break;
      debugPrint('[player] Web resume seek $targetMs (attempt ${attempt + 1}, pos $before)');
      if (gen != _resumeSeekGen) return;
      await player.seek(Duration(milliseconds: targetMs));
      await Future.delayed(const Duration(milliseconds: 400));
      final after = player.state.position.inMilliseconds;
      if (after >= targetMs - 1500 && after <= targetMs + 5000) break;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isStabilizing = false;
      });
    }
  }

  /// Normaliza cualquier URL de YouTube (watch, youtu.be, embed) al formato
  /// embed con autoplay, que es el único reproducible en el WebView de TV.
  String _youTubeEmbedUrl(String url) {
    try {
      final uri = Uri.parse(url);
      String? id;
      if (uri.host.contains('youtu.be')) {
        id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      } else if (uri.host.contains('youtube.com')) {
        id = uri.queryParameters['v'];
        if (id == null && uri.pathSegments.contains('embed') && uri.pathSegments.length > 1) {
          id = uri.pathSegments[uri.pathSegments.indexOf('embed') + 1];
        }
      }
      if (id != null && id.isNotEmpty) return 'https://www.youtube.com/embed/$id?autoplay=1&rel=0';
    } catch (_) {}
    return url;
  }

  void _initEmbedPlayer(String url, [Map<String, String> headers = const {}]) {
    // En Android el backend devuelve URLs con localhost:3000 (el servidor corre
    // en el PC); hay que apuntar a la IP real de la LAN.
    url = ApiEndpoints.fixUrl(url);
    
    // Senior Stability Fix: Parar el motor nativo inmediatamente al pasar a modo Externo/Embed
    // Esto asegura que el audio anterior se detenga al cambiar de fuente
    _player?.stop();
    
    final isWebOrDesktop = kIsWeb || (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    if (isWebOrDesktop) {
      setState(() => _webViewController = null);
      _launchExternal(url);
      return;
    }

    final allowedHost = Uri.parse(url).host;
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(onNavigationRequest: (request) {
            final requestUrl = request.url;
            if (requestUrl.startsWith('about:') || requestUrl.startsWith('data:')) return NavigationDecision.navigate;
            try {
              final host = Uri.parse(requestUrl).host.toLowerCase();
              final allowed = allowedHost.toLowerCase();
              if (host == allowed || host.endsWith('.$allowed') || allowed.endsWith('.$host')) return NavigationDecision.navigate;
            } catch (_) {}
            return NavigationDecision.prevent;
      }))
      ..loadRequest(Uri.parse(url), headers: headers);

    if (!mounted) return;
    setState(() => _webViewController = controller);
  }



  Future<void> _launchExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  bool _isCurrentTrackEmbed(List<VideoTrackOption> tracks) {
    if (tracks.isEmpty) return false;
    final idx = _selectedTrackIndex < tracks.length ? _selectedTrackIndex : 0;
    return tracks[idx].isEmbed;
  }

  @override
  void dispose() {
    // Primero la bandera: a partir de aquí el ref está muerto (igual que Movil).
    _isDisposed = true;
    // Senior Fix: Cancelar TODOS los timers para evitar fugas de memoria y llamadas a setState
    _loadWatchdogTimer?.cancel();
    _hideTimer?.cancel();
    _autoplayTimer?.cancel();
    _stabilizationTimer?.cancel();
    _historySaveTimer?.cancel();
    _holdTimer?.cancel();
    _bufferingDebounceTimer?.cancel();
    _volumeSubscription?.cancel();
    _volumeControlChannel.setMethodCallHandler(null);
    
    if (_isMobileDevice && _isExiting) {
      VolumeController.instance.showSystemUI = true;
      _setVolumeIntercept(false);
    }
    _posSubscription?.cancel();
    _bufferingSubscription?.cancel();
    _completedSubscription?.cancel();
    _errorSubscription?.cancel();
    _logSubscription?.cancel();
    _playingSubscription?.cancel();

    final ms = _player?.state.position.inMilliseconds ?? 0;
    final duration = _player?.state.duration.inMilliseconds ?? 0;
    
    // Senior Shield: Solo guardamos si el reproductor realmente logró sincronizar la posición
    // de reanudación. Si cerramos antes de que MPV enganche, evitamos sobreescribir con 0ms.
    // Guardado final SIN ref (ver _finalSaveOnDispose).
    if (_hasResetPosition && ms > 3000 && duration > 0) {
      _finalSaveOnDispose(ms, duration);
    }
    
    _historyNotifier?.flush();

    WidgetsBinding.instance.removeObserver(this);

    if (_player != null) {
      // Senior Fix: Red de seguridad final por si _exitPlayer no fue invocado
      final p = _player;
      _player = null;
      p?.stop();
      p?.dispose();
    }

    if (kIsWeb) {
      setAppFullscreen(false);
    } else if (_isMobileDevice) {
      _setVolumeIntercept(false);
    }
    
    _showNextNotifier.dispose();
    _hoverInfoNotifier.dispose();
    _timelineFocusNode.dispose();
    _playerFocusNode.dispose();
    _headerFocusNode.dispose();
    _serverPillFocusNode.dispose();
    _episodesPillFocusNode.dispose();
    _opedPillFocusNode.dispose();
    _languagePillFocusNode.dispose();
    _sidePanelCloseNode.dispose();
    super.dispose();
  }

  void _handleBackNavigation() {
    if (_activeOverlay != PlayerOverlay.none) {
      _dismissSidePanel();
      return;
    }

    if (_showControls) {
      setState(() => _showControls = false);
      if (_timelineFocusNode.canRequestFocus) _timelineFocusNode.requestFocus();
      return;
    }

    if (_isFullscreen && !ResponsiveUtils.isMobile(context)) {
      _toggleFullscreen();
      return;
    }

    if (_isAutoplayResume) {
      _autoplayTimer?.cancel();
      setState(() {
        _autoplayCountdown = -1;
        _isAutoplayResume = false;
      });
      _startHideTimer();
      return;
    }

    _exitPlayer();
  }

  void _exitPlayer() async {
    if (!mounted || _isExiting) return;

    // Senior Safety Flush: Guardar historial ANTES de matar el hardware
    try {
      final ms = _player?.state.position.inMilliseconds ?? 0;
      final duration = _player?.state.duration.inMilliseconds ?? 0;
      
      if (_hasResetPosition && ms > 3000 && duration > 0) {
        _updateHistory(
          positionMs: ms,
          durationMs: duration,
          force: true,
        );
        _historyNotifier?.flush();
      }
    } catch (e) {
      debugPrint('[player] Error during safety flush: $e');
    }
    
    // Senior Fix: Marcar como saliendo ANTES de cualquier otra acción
    setState(() => _isExiting = true);
    
    // 1. Silencio absoluto y detención radical del motor nativo
    final p = _player;
    _player = null; 
    try {
      p?.setVolume(0);
      await p?.stop(); // Esperamos a que el buffer se vacíe educadamente
      p?.dispose();
    } catch (e) {
      debugPrint('[player] Error killing native instance: $e');
    }
    
    // 2. Forzar restauración del sistema (Orientación + UI)
    if (_isMobileDevice) {
      _setVolumeIntercept(false);
      // Senior Fix: Disparar de forma paralela sin 'await' para evitar retrasos en transiciones
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      VolumeController.instance.showSystemUI = true;
    }
    // TV: siempre horizontal 16:9, también al salir (antes restauraba
    // portraitUp y la plataforma cambiaba a vertical).
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // 3. Salida limpia usando GoRouter para asegurar consistencia
    if (mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/'); 
      }
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, "0")}:${seconds.toString().padLeft(2, "0")}';
    }
    return '$minutes:${seconds.toString().padLeft(2, "0")}';
  }

  @override
  Widget build(BuildContext context) {
    // Senior Fix: Sincronización forzada de UI antes de cada build para evitar
    // layouts de escritorio en pantallas móviles durante transiciones.
    _isMobileDevice = ResponsiveUtils.isTactic(context);
    final settings = ref.watch(settingsProvider);

    // Senior Session Sync: lista de episodios al provider global (igual que
    // Movil/Web). Sin esto el historial guardaba "T1:E1" sin título en TV:
    // los ticks/stop resuelven el título desde availableEpisodes.
    // Key anti re-sync: el whenData dispara por cada rebuild con data.
    final episodesForSession = ref.watch(episodesProvider(EpisodesParams(
      url: _seriesListUrl,
      source: widget.source,
      title: widget.title,
      season: widget.season,
    )));
    episodesForSession.whenData((data) {
      if (data == null || data.episodes.isEmpty) return;
      // Huella de contenido (NO solo longitud): fast y full suelen medir
      // igual; si no, el full enriquecido nunca reemplazaba al fast pobre.
      final key = '${widget.sourceUrl}|${widget.source}|${widget.season}|${episodesFingerprint(data.episodes)}';
      if (_episodesSyncKey == key) return;
      _episodesSyncKey = key;
      Future.microtask(() {
        if (!mounted) return;
        try {
          final notifier = ref.read(activePlayerProvider.notifier);
          final enriched = _enrichedEpisodes(data.episodes);
          final t = notifier.episodeInfoFor(_activeEpisode, enriched)?.title;
          notifier.updateSession(
            episodes: enriched,
            episodeTitle: (t != null && t.isNotEmpty) ? t : null,
          );
        } catch (_) {}
      });
    });

    // Senior Shield: Interceptamos la navegación de retroceso (Mouse 4, Botón Atrás, Gestos)
    return PopScope(
      canPop: _isExiting,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        if (_ignoreNextPop) {
          _ignoreNextPop = false;
          return;
        }

        final now = DateTime.now();
        if (_lastPopEventTime != null && now.difference(_lastPopEventTime!) < const Duration(milliseconds: 500)) {
          return;
        }
        _lastPopEventTime = now;

        _handleBackNavigation();
      },
      child: _buildMainContent(context, settings),
    );
  }

  Widget _buildMainContent(BuildContext context, UserSettings settings) {
    final remoteState = ref.watch(remoteControlProvider);
    final targetId = remoteState.activeTargetDeviceId;

    if (targetId != null) {
      final target = remoteState.availableDevices.firstWhereOrNull((d) => d.id == targetId);
      if (target != null) return _buildRemoteModeView(target);
    }

    // Fondo: negro puro en reproducción; gris del panel solo con menú abierto.
    final bg = _activeOverlay != PlayerOverlay.none ? const Color(0xFF0F0F0F) : Colors.black;

    // Senior Direct Flow: Fuentes que ya entregan el stream directo o proxied
    final bool isDirectSource = _currentSource == 'Themes' || _currentSource == 'YouTube';

    if (isDirectSource || widget.source.isEmpty && widget.sourceUrl.isNotEmpty) {
      return Material(color: bg, child: _playerView(settings: settings));
    }

    final extractAsync = ref.watch(extractProvider(ExtractParams(
      url: _currentSourceUrl, 
      source: _currentSource,
      category: widget.category,
    )));

    return Material(
      color: bg,
      child: extractAsync.when(
        data: (result) {
          final tracks = result.tracks;
          final playableTracks = tracks.where((t) => !t.isDownload).toList();
          if (!_hasInitialized) {
            _hasInitialized = true;
            _selectedTrackIndex = _indexForLanguage(playableTracks);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final safeIdx = _selectedTrackIndex < playableTracks.length ? _selectedTrackIndex : 0;
              if (playableTracks.isNotEmpty) {
                final initialTrack = playableTracks[safeIdx];
                _applyTrackQualityOptions(initialTrack);
                if (initialTrack.isEmbed) _initEmbedPlayer(initialTrack.url, initialTrack.headers);
                else _initPlayer(initialTrack.url, initialTrack.headers);
              } else if (result.url.isNotEmpty) _initPlayer(result.url, result.headers);
              if (mounted) {
              _allTracks = playableTracks;
              setState(() => _extractTracks = playableTracks.where((t) => !t.isEmbed).toList());
              // Core session: registrar item/episodio/fuente/pistas (triggerOpen
              // false: TV mantiene el control del hardware, igual que Movil).
              // Sin esto, stop()/saves del provider eran no-op en TV.
              ref.read(activePlayerProvider.notifier).play(
                item: MediaItem(
                  id: widget.contentId,
                  title: widget.title ?? '',
                  posterUrl: widget.posterUrl ?? '',
                  bannerUrl: widget.bannerUrl,
                  logoUrl: widget.logoUrl,
                  type: mediaTypeFromCategory(widget.category),
                  kind: widget.kind,
                  year: widget.year,
                ),
                url: safeIdx < playableTracks.length ? playableTracks[safeIdx].url : result.url,
                episode: _activeEpisode,
                season: widget.season,
                source: _currentSource,
                triggerOpen: false,
                episodeTitle: ref.read(activePlayerProvider.notifier).episodeInfoFor(_activeEpisode)?.title,
              );
              ref.read(activePlayerProvider.notifier).updateSession(
                tracks: playableTracks,
                selectedIndex: safeIdx,
              );
            }
            });
          }
          return _playerView(tracks: tracks, settings: settings);
        },
        loading: () => Stack(children: [
            const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Conectando con la fuente...', style: TextStyle(color: Colors.white54))])),
            Positioned(top: 16, left: 16, child: SafeArea(child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28), onPressed: _exitPlayer))),
          ]),
        error: (err, _) => Stack(children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFFF5252), size: 64), 
                    const SizedBox(height: 20), 
                    const Text('Enlace Caducado o Error de Servidor', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), 
                    const SizedBox(height: 12),
                    Text(
                      'El enlace guardado en tu historial ya no es válido. Esto es común en fuentes como Zilla o JKAnime.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisSize: MainAxisSize.min, 
                      children: [
                        OutlinedButton.icon(
                          onPressed: _exitPlayer, 
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Volver'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF7A1E)), 
                          onPressed: () {
                             Navigator.of(context).pop();
                          }, 
                          icon: const Icon(Icons.search_rounded),
                          label: const Text('Buscar Fuente Fresca'),
                        ),
                      ],
                    )
                  ]
                ),
              ),
            ),
            Positioned(top: 16, left: 16, child: SafeArea(child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28), onPressed: _exitPlayer))),
          ]),
      ),
    );
  }

  Widget _buildRemoteModeView(RemoteDevice target) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              if (widget.bannerUrl != null)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.2,
                    child: CachedNetworkImage(
                      imageUrl: ApiEndpoints.proxyImage(widget.bannerUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              
              SafeArea(
                child: Column(
                  children: [
                    // Header (Compacto)
                    _buildRemoteHeader(target),
                    
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 8,
                        ),
                        // TV: solo layout horizontal (sin variante vertical).
                        child: Column(
                          children: [
                            _buildLandscapeRemoteLayout(target),
                          ],
                        ),
                      ),
                    ),
                    
                    // Footer (Botón Desconectar siempre visible o al final del scroll)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: TextButton.icon(
                        onPressed: () {
                          // Senior Handback Logic: Recuperar posición y volver a local
                          final int resumeMs = target.positionMs;
                          
                          // 1. Detener al receptor remotamente
                          _sendRemoteAction(target, RemoteAction.stop);
                          
                          // 2. Limpiar el vínculo y restaurar estado local
                          ref.read(remoteControlProvider.notifier).setActiveTarget(null);
                          
                          setState(() {
                            _resumePosition = resumeMs;
                            _hasInitialized = false; // Forzar re-inicialización del reproductor local
                            _isLoading = true;
                          });

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Color(0xFFEF7A1E),
                              content: Text('Recuperando reproducción local...', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          );
                        },
                        icon: const Icon(Icons.cast_connected_rounded, size: 16),
                        label: const Text('DETENER TRANSMISIÓN', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                        style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRemoteHeader(RemoteDevice target) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
            onPressed: _exitPlayer,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF7A1E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEF7A1E).withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cast_connected_rounded, color: Color(0xFFEF7A1E), size: 18),
                const SizedBox(width: 10),
                Text(
                  target.name.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFEF7A1E), 
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 1.1
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildLandscapeRemoteLayout(RemoteDevice target) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _displayTitle,
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
        ),
        if (_activeEpisode != null && !_isMovie)
          Text(
            _episodeLabel(),
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16, fontWeight: FontWeight.bold),
          ),
        const SizedBox(height: 32),
        _buildRemoteControls(target),
      ],
    );
  }

  Widget _buildRemoteControls(RemoteDevice target) {
    return Column(
      children: [
        _buildRemoteTimeline(target),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              iconSize: 32,
              icon: AurisIcon(AurisIcons.backwardStep, color: Colors.white70, size: 32),
              onPressed: () => _handleRemoteNavigation(false, target),
            ),
            const SizedBox(width: 16),
            IconButton(
              iconSize: 40,
              icon: AurisIcon(AurisIcons.backward10, color: Colors.white, size: 40),
              onPressed: () => _sendRemoteSeek(target, -10000),
            ),
            const SizedBox(width: 32),
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                color: Colors.white, 
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: const Color(0xFFEF7A1E).withOpacity(0.3), blurRadius: 15)]
              ),
              child: IconButton(
                iconSize: 44,
                icon: AurisIcon(
                  target.isPlaying ? AurisIcons.pause : AurisIcons.play,
                  color: Colors.black,
                  size: 44,
                ),
                onPressed: () => _sendRemoteAction(target, target.isPlaying ? RemoteAction.pause : RemoteAction.play),
              ),
            ),
            const SizedBox(width: 32),
            IconButton(
              iconSize: 40,
              icon: AurisIcon(AurisIcons.forward10, color: Colors.white, size: 40),
              onPressed: () => _sendRemoteSeek(target, 10000),
            ),
            const SizedBox(width: 16),
            IconButton(
              iconSize: 32,
              icon: AurisIcon(AurisIcons.forwardStep, color: Colors.white70, size: 32),
              onPressed: () => _handleRemoteNavigation(true, target),
            ),
          ],
        ),
        if (!_isMobileDevice) ...[
          const SizedBox(height: 32),
          Row(
            children: [
              AurisIcon(AurisIcons.volumeDown, color: Colors.white54, size: 20),
              Expanded(
                child: Slider(
                  value: target.volume.clamp(0.0, 1.0),
                  activeColor: const Color(0xFFEF7A1E),
                  inactiveColor: Colors.white10,
                  onChanged: (v) => _sendRemoteAction(target, RemoteAction.setVolume, {'volume': v}),
                ),
              ),
              AurisIcon(AurisIcons.volumeUp, color: Colors.white54, size: 20),
            ],
          ),
        ],
        
        const SizedBox(height: 32),
        
        // Acciones Especiales (OP/ED e Idioma)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_isOpEd)
              _RemoteMandoActionButton(
                icon: AurisIcons.fastForward,
                label: 'SALTAR OP/ED',
                onTap: () => _sendRemoteAction(target, RemoteAction.skipOpEd),
              ),
            if (!_isOpEd && target.availableTracks.length > 1) ...[
              const SizedBox(width: 16),
              _RemoteMandoActionButton(
                icon: AurisIcons.subtitles,
                label: 'IDIOMA',
                onTap: () => _showRemoteLanguageSelector(target),
              ),
            ],
            if (!_isOpEd && !_isMovie) ...[
              const SizedBox(width: 16),
              _RemoteMandoActionButton(
                icon: AurisIcons.episodes,
                label: 'EPISODIOS',
                onTap: () => _showRemoteEpisodesSelector(target),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _showRemoteLanguageSelector(RemoteDevice target) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F12),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('CAMBIAR IDIOMA (REMOTO)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
            ),
            const Divider(color: Colors.white10, height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: target.availableTracks.length,
                itemBuilder: (context, index) {
                  final track = target.availableTracks[index];
                  final bool isCurrent = index == target.selectedTrackIndex;
                  final label = track['label'] as String? ?? 'Desconocido';
                  final q = (track['quality'] as String? ?? '').toUpperCase();
                  final isLatino = trackQualityType(q) != 'SUB';
                  
                  return ListTile(
                    onTap: () {
                      _sendRemoteAction(target, RemoteAction.switchTrack, {'index': index});
                      Navigator.pop(context);
                    },
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: trackQualityType(q) == 'SUB'
                            ? Colors.blueAccent
                            : (trackQualityType(q) == 'CAST'
                                ? Colors.orangeAccent
                                : Colors.greenAccent),
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(label, style: TextStyle(color: isCurrent ? Colors.white : Colors.white70, fontWeight: isCurrent ? FontWeight.w900 : FontWeight.normal)),
                    trailing: isCurrent ? const Icon(Icons.check_circle_rounded, color: Color(0xFFEF7A1E)) : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRemoteEpisodesSelector(RemoteDevice target) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F12),
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final episodesAsync = ref.watch(episodesProvider(EpisodesParams(
          url: _seriesListUrl,
          source: _currentSource,
          title: widget.title ?? '',
          season: widget.season ?? 1,
        )));

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('EXPLORADOR DE EPISODIOS (REMOTO)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                ),
                const Divider(color: Colors.white10, height: 1),
                Expanded(
                  child: episodesAsync.when(
                    data: (data) {
                      if (data == null || data.episodes.isEmpty) {
                        return const Center(child: Text('No hay episodios disponibles', style: TextStyle(color: Colors.white54)));
                      }
                      final eps = _enrichedEpisodes(data.episodes);
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: eps.length,
                        itemBuilder: (context, index) {
                          final ep = eps[index];
                          final bool isCurrent = ep.number.toString() == _activeEpisode;
                          
                          return ListTile(
                            onTap: () {
                              _handleRemoteNavigationTo(ep.number, ep.url, target);
                              Navigator.pop(context);
                            },
                            leading: Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: isCurrent ? const Color(0xFFEF7A1E).withOpacity(0.1) : Colors.white10,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text('${ep.number}', style: TextStyle(color: isCurrent ? const Color(0xFFEF7A1E) : Colors.white70, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            title: Text(ep.title ?? 'Episodio ${ep.number}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isCurrent ? Colors.white : Colors.white70, fontWeight: isCurrent ? FontWeight.w900 : FontWeight.normal)),
                            subtitle: (ep.description != null && ep.description!.isNotEmpty) ? Text(ep.description!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)) : null,
                            trailing: isCurrent ? const Icon(Icons.play_circle_fill_rounded, color: Color(0xFFEF7A1E)) : const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white10, size: 14),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFEF7A1E))),
                    error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent))),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleRemoteNavigationTo(int epNum, String epUrl, RemoteDevice target) {
    // 1. Actualizar localmente para sincronizar el estado del mando
    setState(() {
      _currentEpisode = epNum.toString();
      _currentSourceUrl = epUrl;
    });

    // 2. Enviar orden de apertura al dispositivo remoto
    _sendRemoteAction(target, RemoteAction.openMedia, {
      'params': {
        'contentId': widget.contentId,
        'url': epUrl,
        'source': _currentSource,
        'episode': epNum.toString(),
        'season': widget.season?.toString(),
        'metadataTitle': widget.metadataTitle,
        'banner': widget.bannerUrl,
        'category': widget.category,
        'title': widget.title,
        'posterUrl': widget.posterUrl,
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFEF7A1E),
        content: Text('Lanzando Episodio $epNum...', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildRemoteTimeline(RemoteDevice target) {
    final double progress = target.durationMs > 0 ? (target.positionMs / target.durationMs).clamp(0.0, 1.0) : 0.0;
    
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            activeTrackColor: const Color(0xFFEF7A1E),
            inactiveTrackColor: Colors.white10,
          ),
          child: Slider(
            value: target.positionMs.toDouble(),
            max: target.durationMs.toDouble().clamp(0.1, double.infinity),
            onChanged: (v) => _sendRemoteAction(target, RemoteAction.seek, {'position_ms': v.toInt()}),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(Duration(milliseconds: target.positionMs)),
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Text(
                _formatDuration(Duration(milliseconds: target.durationMs)),
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _sendRemoteAction(RemoteDevice target, String action, [Map<String, dynamic>? data]) {
    ref.read(remoteControlProvider.notifier).sendCommand(target.id, action, data);
  }

  void _sendRemoteSeek(RemoteDevice target, int deltaMs) {
    final int targetPos = (target.positionMs + deltaMs).clamp(0, target.durationMs);
    _sendRemoteAction(target, RemoteAction.seek, {'position_ms': targetPos});
  }

  void _handleRemoteNavigation(bool next, RemoteDevice target) async {
    if (_currentEpisode == null) return;
    final currentNum = int.tryParse(_currentEpisode!) ?? 1;
    final nextNum = next ? currentNum + 1 : currentNum - 1;
    if (nextNum < 1) return;

    final sources = ref.read(activeContentSourcesProvider);
    final baseSource = findSourceByName(sources, _currentSource) ??
        (sources.isNotEmpty ? sources.first : null);

    final String nextSourceUrl = baseSource != null
        ? buildEpisodeUrl(baseSource.url, baseSource.source, nextNum)
        : _currentSourceUrl;

    // Actualizamos localmente para que el controller sepa en qué episodio está
    setState(() {
      _currentEpisode = nextNum.toString();
      _currentSourceUrl = nextSourceUrl;
    });

    // Enviamos la orden de apertura al target
    _sendRemoteAction(target, RemoteAction.openMedia, {
      'params': {
        'contentId': widget.contentId,
        'url': nextSourceUrl,
        'source': _currentSource,
        'episode': nextNum.toString(),
        'season': widget.season?.toString(),
        'metadataTitle': widget.metadataTitle,
        'banner': widget.bannerUrl,
        'category': widget.category,
        'title': widget.title,
        'posterUrl': widget.posterUrl,
      }
    });
  }

  Widget _playerView({List<VideoTrackOption> tracks = const [], required UserSettings settings}) {
    final playableTracks = tracks.where((t) => !t.isDownload).toList();
    if (!_isCurrentTrackEmbed(playableTracks)) return _buildMobilePlayer(playableTracks, settings);

    // Senior Elite Fix: WebView (Embed) directo sin Scaffold intermedio para máximo aprovechamiento.
    return _buildEmbedStack(playableTracks);
  }

  Widget _buildEmbedStack(List<VideoTrackOption> playableTracks) {
    return Stack(fit: StackFit.expand, children: [
        if (_webViewController != null) WebViewWidget(controller: _webViewController!)
        else Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.open_in_browser, color: Colors.white70, size: 64),
                const SizedBox(height: 16),
                const Text('Reproducción externa iniciada', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE50914), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                  onPressed: () {
                    final currentTrack = playableTracks[_selectedTrackIndex < playableTracks.length ? _selectedTrackIndex : 0];
                    _launchExternal(currentTrack.url);
                  },
                  icon: const Icon(Icons.launch, size: 16),
                  label: const Text('Reabrir navegador'),
                ),
              ])),
        // Senior Fix: Botón de salida para reproducción externa
        Positioned(
          top: 16,
          left: 16,
          child: SafeArea(
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 30),
              onPressed: _exitPlayer,
              style: IconButton.styleFrom(backgroundColor: Colors.black45),
            ),
          ),
        ),
      ]);
  }



  Widget _buildSeekIndicator() {
    final bool isForward = _seekDiff.inMilliseconds >= 0;
    final String timeStr = _formatDuration(_seekTargetDuration);
    final String diffStr = "${isForward ? '+' : '-'}${_formatDuration(_seekDiff.abs())}";
    final isMobile = ResponsiveUtils.isMobile(context);

    return Container(
      color: Colors.black45,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10),
              ),
              child: Icon(
                isForward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
                color: Colors.white,
                size: isMobile ? 48 : 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              timeStr,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: isMobile ? 32 : 48,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEF7A1E),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                diffStr,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: isMobile ? 16 : 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobilePlayer(List<VideoTrackOption> playableTracks, UserSettings settings) {
    final bool isAnyGestureActive = _showSeekIndicator;
    final bool showAnyway = (_showControls || (_autoplayCountdown >= 0 && _isAutoplayResume) || _activeOverlay != PlayerOverlay.none) && !isAnyGestureActive;
    final bool isMenuOpen = _activeOverlay != PlayerOverlay.none;

    final videoAndControls = Stack(
      fit: StackFit.expand,
      children: [
        if (_webViewController != null)
          RepaintBoundary(child: WebViewWidget(controller: _webViewController!))
        else if (_controller != null)
          RepaintBoundary(
            child: AnimatedOpacity(
              opacity: (!_hasResetPosition && _resumePosition > 3000) ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeIn,
              child: Video(
                key: _videoKey,
                controller: _controller!, 
                controls: NoVideoControls, 
                fit: _videoFit,
                subtitleViewConfiguration: SubtitleViewConfiguration(
                  style: TextStyle(
                    height: 1.2,
                    fontSize: 24 * settings.subtitleSize,
                    color: Color(settings.subtitleColor),
                    fontWeight: FontWeight.bold,
                    backgroundColor: Colors.black38,
                  ),
                  padding: EdgeInsets.only(bottom: _showControls ? 160 : 60),
                ),
              ),
            ),
          )
        else
          const SizedBox.shrink(),

        if (!isMenuOpen)
          Positioned.fill(
            child: PointerInterceptor(
              child: Stack(
                fit: StackFit.expand,
                children: [
                MouseRegion(
                  onHover: (_) { 
                    if (ResponsiveUtils.isTactic(context)) return;
                    if (!_showControls) setState(() => _showControls = true); 
                    _startHideTimer(); 
                  }, 
                  cursor: showAnyway ? SystemMouseCursors.basic : SystemMouseCursors.none, 
                  child: Listener(
                    onPointerDown: (event) { 
                      if (_isFullscreen && (event.buttons & kBackMouseButton != 0)) { 
                        _ignoreNextPop = true;
                        _toggleFullscreen();
                        Timer(const Duration(milliseconds: 300), () => _ignoreNextPop = false);
                      } 
                    }, 
                    child: GestureDetector(
                      onTap: () {
                        if (!_isMobileDevice) {
                          final bool wasPlaying = _player?.state.playing ?? false;
                          if (wasPlaying) _player?.pause(); else _player?.play();
                          if (!_showControls) setState(() => _showControls = true);
                          _startHideTimer();
                        } else {
                          _toggleControls();
                        }
                      },
                      behavior: HitTestBehavior.opaque, 
                      onDoubleTapDown: (details) { 
                        final width = MediaQuery.sizeOf(context).width; 
                        final bool isRight = details.globalPosition.dx >= width / 2;
                        if (isRight) _skipForward(); else _skipBackward();
                      }, 
                      onHorizontalDragStart: (details) {
                        if (!ResponsiveUtils.isNative) return;
                        final duration = _player?.state.duration ?? Duration.zero;
                        if (duration.inMilliseconds <= 0) return;
                        
                        setState(() {
                          _showSeekIndicator = true;
                          _seekTargetDuration = _player?.state.position ?? Duration.zero;
                          _seekDiff = Duration.zero;
                          _showControls = false;
                        });
                        HapticFeedback.selectionClick();
                      },
                      onHorizontalDragUpdate: (details) {
                        if (!_showSeekIndicator || _player == null) return;
                        
                        final double screenWidth = MediaQuery.sizeOf(context).width;
                        final duration = _player!.state.duration;
                        final double sensitivityMs = (duration.inMinutes > 2) ? 120000.0 : duration.inMilliseconds.toDouble();
                        final double deltaMs = (details.primaryDelta! / screenWidth) * sensitivityMs;
                        
                        setState(() {
                          final newMs = (_seekTargetDuration.inMilliseconds + deltaMs).clamp(0.0, duration.inMilliseconds.toDouble());
                          _seekTargetDuration = Duration(milliseconds: newMs.toInt());
                          _seekDiff = Duration(milliseconds: _seekTargetDuration.inMilliseconds - (_player!.state.position.inMilliseconds));
                        });
                      },
                      onHorizontalDragEnd: (details) {
                        if (!_showSeekIndicator) return;
                        
                        _player?.seek(_seekTargetDuration);
                        _updateHistory(positionMs: _seekTargetDuration.inMilliseconds, durationMs: _player?.state.duration.inMilliseconds ?? 0, force: true);
                        
                        setState(() {
                          _showSeekIndicator = false;
                          _showControls = true;
                        });
                        _startHideTimer();
                        HapticFeedback.mediumImpact();
                      },
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                ),
                IgnorePointer(
                  ignoring: !showAnyway, 
                  child: AnimatedOpacity(
                    opacity: showAnyway ? 1.0 : 0.0, 
                    duration: const Duration(milliseconds: 300), 
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (!(_autoplayCountdown >= 0 && _isAutoplayResume)) 
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter, 
                                    end: Alignment.bottomCenter, 
                                    colors: [Colors.black.withOpacity(0.7), Colors.transparent, Colors.transparent, Colors.black.withOpacity(0.8)], 
                                    stops: const [0.0, 0.2, 0.7, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        _buildControlsStack(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return Focus(
      focusNode: _playerFocusNode,
      autofocus: true, 
      onKeyEvent: (node, event) => _handleKeyEvent(event), 
      child: FocusScope(
        child: Stack(
          fit: StackFit.expand, 
          children: [
            AurisTwoPanel(
              video: videoAndControls,
              videoOverlays: [
                // Senior UI Fix: El overlay se muestra durante TODA la carga.
                if (_isLoading)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        // Senior UI: Negro opaco durante la reanudación para ocultar flickeos
                        color: (_resumePosition > 3000 && !_hasResetPosition) ? Colors.black : Colors.black45,
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(width: 48, height: 48, child: CircularProgressIndicator(strokeWidth: 4, color: Colors.white)),
                              SizedBox(height: 16),
                              Text('Cargando...', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_showSeekIndicator) Positioned.fill(child: IgnorePointer(child: _buildSeekIndicator())),
                // Senior Web Fix: Overlay para superar el bloqueo de Autoplay en Web
                if (kIsWeb && _webNeedsInteraction)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black87,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cast_connected_rounded, color: Color(0xFFEF7A1E), size: 64),
                            const SizedBox(height: 24),
                            const Text(
                              'SINCROIZACIÓN REMOTA',
                              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Haz clic para empezar a reproducir',
                              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 32),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF7A1E),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                              onPressed: () {
                                setState(() => _webNeedsInteraction = false);
                                _player?.play();
                              },
                              icon: const Icon(Icons.play_arrow_rounded, size: 28),
                              label: const Text('REPRODUCIR AHORA', style: TextStyle(fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
              panelOpen: isMenuOpen,
              panelTitle: switch (_activeOverlay) {
                PlayerOverlay.language => 'Audio y subtítulos',
                PlayerOverlay.server => 'Servidor',
                PlayerOverlay.quality => 'Calidad',
                PlayerOverlay.speed => 'Velocidad',
                PlayerOverlay.volume => 'Volumen',
                PlayerOverlay.episodes => 'Episodios',
                _ => 'Configuración',
              },
              panelContent: switch (_activeOverlay) {
                PlayerOverlay.language => _buildLanguageSelectorContent(isSidebar: true),
                PlayerOverlay.server => _buildServerSelectorContent(isSidebar: true),
                PlayerOverlay.quality => _buildQualitySelectorContent(isSidebar: true),
                PlayerOverlay.config => _buildConfigMenuContent(isSidebar: true),
                PlayerOverlay.speed => _buildSpeedSelectorContent(isSidebar: true),
                PlayerOverlay.volume => _buildVolumeSelectorContent(isSidebar: true),
                PlayerOverlay.episodes => _buildEpisodesSelectorContent(isSidebar: true),
                _ => const SizedBox.shrink(),
              },
              onDismiss: _dismissSidePanel,
              closeFocusNode: _sidePanelCloseNode,
              trapFocus: true,
              onBack: _dismissSidePanel,
              railWidth: 460,
              borderRadius: 40,
            ),
           
           if (_playbackError != null) 
             Positioned.fill(
               child: Container(
                 color: Colors.black.withOpacity(0.92), 
                 child: Center(
                   child: SingleChildScrollView(
                     child: Padding(
                       padding: const EdgeInsets.all(24), 
                       child: Column(
                         mainAxisSize: MainAxisSize.min, 
                         children: [
                           const Icon(Icons.error_outline, color: Color(0xFFFF5252), size: 56),
                           const SizedBox(height: 16),
                           const Text('No se pudo reproducir', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                           const SizedBox(height: 8),
                           Text(_playbackError!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                           const SizedBox(height: 24),
                           Row(
                             mainAxisSize: MainAxisSize.min, 
                             children: [
                               OutlinedButton(onPressed: _exitPlayer, child: const Text('Volver')),
                               const SizedBox(width: 12),
                               ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF7A1E)), onPressed: _retryPlayback, child: const Text('Reintentar')),
                             ],
                           ),
                         ],
                       ),
                     ),
                   ),
                 ),
               ),
             ),
         ],
        ),
      ),
    );
  }

  Widget _buildControlsStack() {
    return Stack(children: [
        _buildMobileHeader(),
        _buildMobileTimelineLayer(),
        _buildMobilePillsLayer(),
        _buildNextEpisodeOverlay(),
      ]);
  }

  Widget _buildMobileTimelineLayer() {
    return Positioned(
      bottom: 70,
      left: 0,
      right: 0,
      child: Center(child: _buildMobileTimeline()),
    );
  }

  Widget _buildMobilePillsLayer() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPillButton(
                label: _currentSource.isNotEmpty ? _currentSource : 'Servidor',
                icon: AurisIcons.server,
                isSelected: _activeOverlay == PlayerOverlay.server,
                onTap: _showServerSelector,
                focusNode: _serverPillFocusNode,
              ),
              const SizedBox(width: 10),
              if (!_isMovie) ...[
                _buildPillButton(
                  label: _activeEpisode != null ? 'Ep. $_activeEpisode' : 'Episodios',
                  icon: AurisIcons.episodes,
                  isSelected: _activeOverlay == PlayerOverlay.episodes,
                  onTap: _showEpisodesPanel,
                  focusNode: _episodesPillFocusNode,
                ),
                const SizedBox(width: 10),
              ],
              if (!_isMovie && !_isOpEd) ...[
                _buildPillButton(
                  label: 'Saltar OP/ED',
                  icon: AurisIcons.fastForward,
                  isSelected: false,
                  onTap: _skipOpEd,
                  focusNode: _opedPillFocusNode,
                ),
                const SizedBox(width: 10),
              ],
              const SizedBox(width: 10),
              _buildPillButton(
                label: _currentLanguage ?? 'Audio / Subs',
                icon: AurisIcons.subtitles,
                isSelected: _activeOverlay == PlayerOverlay.language,
                onTap: _showLanguageSelector,
                focusNode: _languagePillFocusNode,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNextEpisodeOverlay() {
    if (_isTrailer || _isAutoplayResume) return const SizedBox.shrink();
    final isMobile = ResponsiveUtils.isMobile(context);
    final bool isCountdown = _autoplayCountdown >= 0;
    final String label = _isAutoplayResume ? 'Reanudar' : 'Siguiente episodio';

    // Senior Autoplay Shield: Verificar si existe un siguiente episodio para evitar el popup en el final
    final episodesAsync = ref.watch(episodesProvider(EpisodesParams(
      url: _seriesListUrl,
      source: widget.source,
      title: widget.title,
      season: widget.season,
    )));

    final bool hasNext = episodesAsync.when(
      data: (data) {
        if (data == null || data.episodes.isEmpty) {
          if (widget.totalEpisodes != null) {
            final currentNum = int.tryParse(_activeEpisode ?? '') ?? 0;
            return currentNum < widget.totalEpisodes!;
          }
          return true; 
        }
        final currentNum = int.tryParse(_activeEpisode ?? '') ?? 0;
        return data.episodes.any((e) => e.number > currentNum);
      },
      loading: () => true,
      error: (_, __) => true,
    );

    return ValueListenableBuilder<bool>(
      valueListenable: _showNextNotifier,
      builder: (context, showNext, _) {
        // El botón es visible si estamos en el umbral del 93% O si el video ha terminado (countdown)
        // PERO solo si hay un siguiente episodio disponible (o si es el modo Reanudar).
        final bool isVisible = (showNext || isCountdown) && (_isAutoplayResume || hasNext);
        
        return Positioned(
          bottom: isMobile ? 120 : 160, 
          right: isMobile ? 16 : 40, 
          child: IgnorePointer(
            ignoring: !isVisible,
            child: Opacity(
              opacity: isVisible ? 1.0 : 0.0, 
              child: Container(
                height: 52,
                constraints: BoxConstraints(minWidth: isMobile ? 120 : 180), 
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: isCountdown ? const Color(0xFFB2B2B2) : Colors.white, 
                  borderRadius: BorderRadius.circular(8), 
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isVisible ? 0.3 : 0.0),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Stack(
                  children: [
                    // Capa de progreso: Animación de 5 segundos FLUIDA (una sola vez)
                    if (isCountdown)
                      Positioned.fill(
                        child: _NetflixProgressBar(
                          // Usamos una clave que persista durante toda la cuenta atrás
                          // Solo cambia si el modo (Resume vs Autoplay) cambia, pero no con cada segundo
                          key: ValueKey('netflix_persistent_bar_${_isAutoplayResume}'), 
                        ),
                      ),
                    
                    // Contenido: Siempre visible en NEGRO sobre la carga blanca
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isCountdown 
                            ? (_isAutoplayResume ? _handleResumeAction : () => _navigateToEpisode(true))
                            : () => _navigateToEpisode(true),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 24, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow_rounded, color: Colors.black, size: isMobile ? 26 : 30),
                              SizedBox(width: isMobile ? 8 : 12),
                              Text(
                                label,
                                style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              if (isCountdown) ...[
                                SizedBox(width: isMobile ? 10 : 18),
                                Container(width: 1, height: 24, color: Colors.black12),
                                SizedBox(width: isMobile ? 8 : 12),
                                GestureDetector(
                                  onTap: _isAutoplayResume ? _handleRestartAction : () {
                                    _autoplayTimer?.cancel();
                                    setState(() => _autoplayCountdown = -1);
                                  },
                                  child: Icon(
                                    _isAutoplayResume ? Icons.refresh_rounded : Icons.close_rounded,
                                    color: Colors.black54,
                                    size: isMobile ? 20 : 22,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileHeader() {
    final bool hideBack = _isFullscreen && !_isMobileDevice;

    return Positioned(
      top: 0, 
      left: 0, 
      right: 0, 
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top-Left: Back, Replay 10s, Options
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (!hideBack) ...[
                  _buildCircularButton(
                    icon: Symbols.arrow_back,
                    onTap: _exitPlayer,
                    size: 44,
                    iconSize: 22,
                    debugLabel: 'header_back',
                    focusNode: _headerFocusNode,
                    isTopButton: true,
                  ),
                  const SizedBox(width: 16),
                  _buildCircularButton(
                    icon: AurisIcons.repeat,
                    onTap: _restartToBeginning,
                    size: 44,
                    iconSize: 22,
                    debugLabel: 'header_replay',
                    isTopButton: true,
                  ),
                ] else ...[
                  _buildCircularButton(
                    icon: AurisIcons.repeat,
                    onTap: _skipBackward,
                    size: 44,
                    iconSize: 22,
                    debugLabel: 'header_replay',
                    focusNode: _headerFocusNode,
                    isTopButton: true,
                  ),
                ],
                const SizedBox(width: 16),
                _buildCircularButton(
                  icon: Symbols.settings,
                  onTap: _showConfigMenu,
                  size: 44,
                  iconSize: 22,
                  debugLabel: 'header_options',
                  isTopButton: true,
                ),
              ],
            ),
            // Top-Right: Show Title & Episode
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _displayTitle.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.0),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!_isMovie) ...[
                  const SizedBox(height: 4),
                  if (_activeEpisode != null)
                    Text(
                      _episodeLabel(),
                      style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                    )
                  else
                    Text(
                      (widget.category ?? '').toUpperCase(),
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayPauseButton({double? size, Color? backgroundColor, Color? iconColor, bool isCapsule = false}) {
    final double buttonSize = size ?? (_isMobileDevice ? 44 : 44);
    final Stream<bool> playStream = _player?.stream.playing ?? const Stream.empty();
    final bool initialPlay = _player?.state.playing ?? false;

    return StreamBuilder<bool>(
      stream: playStream, 
      initialData: initialPlay, 
      builder: (context, snapshot) {
        final isPlaying = snapshot.data ?? initialPlay;
        
        String iconData = isPlaying 
            ? AurisIcons.pauseFilled
            : AurisIcons.playFilled;
        if (_isCompleted) iconData = AurisIcons.restart;

        return _buildCircularButton(
          icon: iconData,
          size: buttonSize,
          fill: true,
          onTap: () {
            if (_isCompleted) {
              _autoplayTimer?.cancel();
              setState(() {
                _autoplayCountdown = -1;
                _isCompleted = false;
                _isStabilizing = true;
                _lastStablePositionMs = 0;
              });
              _player?.seek(Duration.zero);
              _player?.play();
            } else {
              if (isPlaying) {
                _userHasPaused = true;
                _player?.pause();
              } else {
                _userHasPaused = false;
                _player?.play();
              }
              _startHideTimer();
            }
          },
          backgroundColor: backgroundColor ?? (_isMobileDevice ? Colors.black.withValues(alpha: 0.15) : null),
          iconColor: isCapsule ? Colors.black : iconColor,
          isCapsule: isCapsule,
          iconSize: isCapsule ? 22 : (_isMobileDevice ? null : 30),
        );
      }
    );
  }

  Widget _buildCircularButton({
    required Object icon, 
    required VoidCallback onTap, 
    required double size,
    bool fill = false,
    Color? backgroundColor,
    double? iconSize,
    Color? iconColor,
    String? debugLabel,
    bool isCapsule = false,
    FocusNode? focusNode,
    bool isTopButton = false,
  }) {
    return Focus(
      focusNode: focusNode,
      debugLabel: debugLabel,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          final key = event.logicalKey;
          if (debugLabel == 'header_back' || debugLabel == 'header_replay' || debugLabel == 'header_options') {
            if (!_showControls) {
              setState(() => _showControls = true);
            }
            if (key == LogicalKeyboardKey.arrowDown) {
              _timelineFocusNode.requestFocus();
              _startHideTimer();
              return KeyEventResult.handled;
            } else if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
              onTap();
              _startHideTimer();
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final bool isFocused = Focus.of(context).hasFocus;
          if (isTopButton) {
            return AnimatedScale(
              scale: isFocused ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(size / 2),
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: Center(
                      child: icon is String
                          ? AurisIcon(
                              icon as String,
                              color: isFocused ? Colors.white : (iconColor ?? Colors.white.withOpacity(0.8)),
                              size: iconSize ?? 24,
                            )
                          : Icon(
                              icon as IconData?,
                              color: isFocused ? Colors.white : (iconColor ?? Colors.white.withOpacity(0.8)),
                              size: iconSize ?? 24,
                              fill: fill ? 1.0 : 0.0,
                            ),
                    ),
                  ),
                ),
              ),
            );
          }

          return AnimatedScale(
            scale: isFocused ? 1.15 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              width: isCapsule ? (size * 1.4) : size, height: size,
              decoration: BoxDecoration(
                color: isFocused ? const Color(0xFFEF7A1E) : (backgroundColor ?? Colors.black.withValues(alpha: 0.45)),
                borderRadius: isCapsule ? BorderRadius.circular(size / 2) : null,
                shape: isCapsule ? BoxShape.rectangle : BoxShape.circle,
                border: isFocused ? Border.all(color: Colors.white, width: 2) : null,
                boxShadow: isFocused ? [BoxShadow(color: const Color(0xFFEF7A1E).withOpacity(0.4), blurRadius: 12)] : null,
              ),
              padding: const EdgeInsets.all(4),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(size / 2),
                  hoverColor: Colors.white.withValues(alpha: 0.12),
                  splashColor: Colors.white.withValues(alpha: 0.08),
                  child: Center(
                    child: icon is String
                        ? AurisIcon(
                            icon as String,
                            color: isFocused ? Colors.black : (iconColor ?? Colors.white),
                            size: iconSize ?? (size * 0.55),
                          )
                        : Icon(
                            icon as IconData?, 
                            color: isFocused ? Colors.black : (iconColor ?? Colors.white), 
                            size: iconSize ?? (size * 0.55), 
                            fill: fill ? 1.0 : 0.0
                          ),
                  ),
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildCapsuleIconButton({
    required Object icon, 
    required VoidCallback onTap, 
    double size = 24, 
    bool fill = false,
    double minWidth = 48,
  }) {
    return Container(
      width: minWidth, height: 44, // Unificado a 44px
      padding: const EdgeInsets.all(4), // Inset de 4px para forma de cápsula interna
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18), // Forma de cápsula interna refinada (Radio 18 para alto 36)
          hoverColor: Colors.white.withValues(alpha: 0.12),
          splashColor: Colors.white.withValues(alpha: 0.08),
          child: Center(
            child: icon is String
                ? AurisIcon(icon as String, color: Colors.white, size: size)
                : Icon(icon as IconData?, color: Colors.white, size: size, fill: fill ? 1.0 : 0.0),
          ),
        ),
      ),
    );
  }

  Widget _buildSeekCapsule() {
    return Container(
      height: 44, // Unificado a 44px
      decoration: _controlCapsuleDecoration,
      clipBehavior: Clip.antiAlias, 
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 2), // Margen de seguridad inicial
          _buildCapsuleIconButton(
            icon: AurisIcons.backward10,
            onTap: _skipBackward,
            size: 30, // Unificado a 30px
            minWidth: 48,
          ),
          Container(width: 1, height: 16, color: Colors.white.withValues(alpha: 0.05)),
          _buildCapsuleIconButton(
            icon: AurisIcons.forward10,
            onTap: _skipForward,
            size: 30, // Unificado a 30px
            minWidth: 48,
          ),
          const SizedBox(width: 2),
        ],
      ),
    );
  }

  Widget _buildNavigationCapsule(bool hasPrevious, bool hasNext) {
    if (!hasPrevious && !hasNext) return const SizedBox.shrink();
    return Container(
      height: 44, // Unificado a 44px
      decoration: _controlCapsuleDecoration,
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 2),
          if (hasPrevious)
            _buildCapsuleIconButton(
              icon: AurisIcons.backwardStep,
              onTap: () => _navigateToEpisode(false),
              size: 30, // Unificado a 30px
              fill: true,
              minWidth: 48,
            ),
          if (hasPrevious && hasNext) 
            Container(width: 1, height: 16, color: Colors.white.withValues(alpha: 0.05)),
          if (hasNext)
            _buildCapsuleIconButton(
              icon: AurisIcons.forwardStep,
              onTap: () => _navigateToEpisode(true),
              size: 30, // Unificado a 30px
              fill: true,
              minWidth: 48,
            ),
          const SizedBox(width: 2),
        ],
      ),
    );
  }

  Widget _buildDurationCapsule() {
    final Stream<Duration> posStream = _player?.stream.position ?? const Stream.empty();
    final Duration initialPos = _player?.state.position ?? Duration.zero;

    return StreamBuilder<Duration>(
      stream: posStream,
      initialData: initialPos,
      builder: (context, snapshot) {
        final position = snapshot.data ?? initialPos;
        final duration = _player?.state.duration ?? Duration.zero;
        return Container(
          height: 44, // Unificado a 44px
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: _controlCapsuleDecoration,
          alignment: Alignment.center,
          child: Text(
            '${_formatDuration(position)} / ${_formatDuration(duration)}',
            style: const TextStyle(
              color: Colors.white, 
              fontSize: 14, 
              fontWeight: FontWeight.bold, 
              letterSpacing: 0.5
            ),
          ),
        );
      }
    );
  }

  // Central controls removed per user request

// _buildMobileBottomBar replaced by independent layers

  /// Orden visual de las pills (igual que [_buildMobilePillsLayer]).
  /// La navegación izq/der es explícita porque el scoring geométrico del
  /// traversal salta al timeline ancho en vez de a la pill vecina.
  List<FocusNode> get _pillTraversalOrder {
    final order = <FocusNode>[_serverPillFocusNode];
    if (!_isMovie) order.add(_episodesPillFocusNode);
    if (!_isMovie && !_isOpEd) order.add(_opedPillFocusNode);
    order.add(_languagePillFocusNode);
    return order;
  }

  Widget _buildPillButton({
    required String label, 
    Object? icon, 
    required bool isSelected, 
    required VoidCallback onTap,
    FocusNode? focusNode,
  }) {
    final node = focusNode ?? FocusNode();
    return Focus(
      focusNode: node,
      onFocusChange: (focused) {
        if (focused) {
          _lastFocusedPillNode = node;
        } else {
          // Al salir de la pill se reanuda el auto-ocultado.
          _startHideTimer();
        }
      },
      // D-pad en pills: OK/centro (select) activa —el mando de TV no manda
      // Enter sino `select`, sin binding por defecto— y arriba vuelve al
      // timeline. Izquierda/derecha/abajo se contienen en la fila con orden
      // explícito (los topes se tragan para no fugar el foco al timeline).
      // Se consume aquí para que Espacio no llegue al play/pausa global.
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.numpadEnter ||
              key == LogicalKeyboardKey.space) {
            if (event is KeyDownEvent) onTap();
            _startHideTimer();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowUp) {
            _timelineFocusNode.requestFocus();
            _startHideTimer();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowLeft ||
              key == LogicalKeyboardKey.arrowRight ||
              key == LogicalKeyboardKey.arrowDown) {
            final order = _pillTraversalOrder;
            final idx = order.indexOf(node);
            if (idx != -1 &&
                (key == LogicalKeyboardKey.arrowLeft ||
                    key == LogicalKeyboardKey.arrowRight)) {
              final next = key == LogicalKeyboardKey.arrowRight ? idx + 1 : idx - 1;
              if (next >= 0 && next < order.length) {
                order[next].requestFocus();
                _startHideTimer();
              }
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final bool isFocused = Focus.of(context).hasFocus;
          return AnimatedScale(
            scale: isFocused ? 1.0 : 0.95,
            alignment: Alignment.topCenter,
            duration: const Duration(milliseconds: 200),
            child: Container(
              decoration: BoxDecoration(
                color: isFocused
                    ? Colors.white
                    : (isSelected ? Colors.white : Colors.white.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isFocused ? Colors.white : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          icon is String
                              ? AurisIcon(icon, color: isFocused ? Colors.black : (isSelected ? Colors.black : Colors.white), size: 16)
                              : Icon(icon as IconData?, color: isFocused ? Colors.black : (isSelected ? Colors.black : Colors.white), size: 16),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          label,
                          style: TextStyle(
                            color: isFocused ? Colors.black : (isSelected ? Colors.black : Colors.white),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMobileTimeline() {
    final Stream<Duration> posStream = _player?.stream.position ?? const Stream.empty();
    final Duration initialPos = _player?.state.position ?? Duration.zero;
    final Stream<Duration> bufferStream = _player?.stream.buffer ?? const Stream.empty();
    final Duration initialBuffer = _player?.state.buffer ?? Duration.zero;

    return StreamBuilder<Duration>(
      stream: posStream,
      initialData: initialPos,
      builder: (context, snapshot) {
        final position = snapshot.data ?? initialPos;
        final duration = _player?.state.duration ?? Duration.zero;
        final double maxMs = duration.inMilliseconds.toDouble().clamp(0.01, double.infinity);
        final double currentMs = position.inMilliseconds.toDouble().clamp(0.0, maxMs);
        // Scrub en el propio timeline (estilo YouTube TV): el playhead y la
        // hora siguen al objetivo mientras se mantiene pulsado.
        final bool scrubbing = _holdDir != 0;
        final double displayMs = scrubbing
            ? _seekTargetDuration.inMilliseconds.toDouble().clamp(0.0, maxMs)
            : currentMs;

        return Focus(
          focusNode: _timelineFocusNode,
          onFocusChange: (focused) {
            if (focused) {
              _timelineFocusTime = DateTime.now();
            }
            if (mounted) setState(() {});
          },
          onKeyEvent: (node, event) {
            // Soltar ←/→ confirma el hold-scrub con un solo seek.
            if (event is KeyUpEvent &&
                (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                    event.logicalKey == LogicalKeyboardKey.arrowRight)) {
              _endHoldScrub();
              return KeyEventResult.handled;
            }
            if (event is KeyDownEvent || event is KeyRepeatEvent) {
              // El timeline consume las teclas antes que la raíz: si los
              // controles están ocultos hay que mostrarlos aquí también.
              if (!_showControls) {
                setState(() => _showControls = true);
              }
              final key = event.logicalKey;
              if (key == LogicalKeyboardKey.arrowLeft) {
                if (event is KeyDownEvent) _beginHoldScrub(-1);
                _startHideTimer();
                return KeyEventResult.handled;
              } else if (key == LogicalKeyboardKey.arrowRight) {
                if (event is KeyDownEvent) _beginHoldScrub(1);
                _startHideTimer();
                return KeyEventResult.handled;
              } else if (key == LogicalKeyboardKey.arrowUp) {
                _headerFocusNode.requestFocus();
                _startHideTimer();
                return KeyEventResult.handled;
              } else if (key == LogicalKeyboardKey.arrowDown) {
                if (DateTime.now().difference(_timelineFocusTime).inMilliseconds < 250) {
                  return KeyEventResult.handled;
                }
                (_lastFocusedPillNode ?? _serverPillFocusNode).requestFocus();
                _startHideTimer();
                return KeyEventResult.handled;
              } else if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
                _handlePlayPause();
                _startHideTimer();
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: Builder(
            builder: (context) {
              final bool isFocused = Focus.of(context).hasFocus;
              return AnimatedScale(
                scale: isFocused ? 1.0 : 0.95,
                alignment: Alignment.bottomCenter,
                duration: const Duration(milliseconds: 200),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExcludeFocus(
                      child: _buildPlayPauseButton(size: 54, backgroundColor: Colors.white, iconColor: Colors.black, isCapsule: false),
                    ),
                    const SizedBox(width: 10),
                    Builder(
                      builder: (context) {
                        final String timeText = _formatDuration(
                            scrubbing ? _seekTargetDuration : position);
                        final style = TextStyle(
                          color: scrubbing
                              ? const Color(0xFFEF7A1E)
                              : Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [
                            FontFeature.tabularFigures()
                          ],
                        );
                        // Solo durante el scrub: odómetro vertical por
                        // dígito en vez de saltos.
                        if (!scrubbing) return Text(timeText, style: style);
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            for (final ch in timeText.split(''))
                              int.tryParse(ch) != null
                                  ? _OdometerDigit(
                                      value: int.parse(ch),
                                      style: style,
                                      direction: _holdDir,
                                    )
                                  : Text(ch, style: style),
                          ],
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 520,
                      child: StreamBuilder<Duration>(
                        stream: bufferStream,
                        initialData: initialBuffer,
                        builder: (context, bufSnapshot) {
                          return ExcludeFocus(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 4,
                                trackShape: const _ZeroPaddingSliderTrackShape(),
                                thumbShape: RoundSliderThumbShape(
                                    enabledThumbRadius: scrubbing ? 11 : 7),
                                activeTrackColor: const Color(0xFFEF7A1E),
                                inactiveTrackColor: Colors.white.withValues(alpha: 0.25),
                                thumbColor: const Color(0xFFEF7A1E),
                                overlayColor: const Color(0xFFEF7A1E).withOpacity(0.3),
                              ),
                              child: Slider(
                                value: displayMs,
                                max: maxMs,
                                onChanged: (value) {
                                  final int targetMs = value.toInt();
                                  _isStabilizing = true;
                                  _isCompleted = false;
                                  _lastManualSeekTime = DateTime.now();
                                  _lastFrameMs = targetMs;
                                  _lastStablePositionMs = targetMs;
                                  _player?.seek(Duration(milliseconds: targetMs));
                                  _startStabilizationTimer();
                                  _updateHistory(positionMs: targetMs, durationMs: duration.inMilliseconds, force: true);
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _formatDuration(duration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // _buildLockToggle removed
}

class _PlayerTextButton extends StatefulWidget {
  final VoidCallback onPressed; final IconData icon; final String label; final bool isBold; final bool useBackground;
  const _PlayerTextButton({required this.onPressed, required this.icon, required this.label, this.isBold = false, this.useBackground = false});
  @override State<_PlayerTextButton> createState() => _PlayerTextButtonState();
}

class _PlayerTextButtonState extends State<_PlayerTextButton> {
  bool _isHovered = false;
  bool _isFocused = false;
  @override Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final bool isActive = _isHovered || _isFocused;
    return Focus(
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        child: AnimatedScale(
            scale: isActive ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: MouseRegion(
                onEnter: (_) => setState(() => _isHovered = true),
                onExit: (_) => setState(() => _isHovered = false),
                child: InkWell(
                    onTap: widget.onPressed,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? (widget.label.isEmpty ? 6 : 10) : 24, vertical: isMobile ? 6 : 12),
                        decoration: BoxDecoration(
                            color: _isFocused ? const Color(0xFFEF7A1E) : (widget.useBackground ? (isActive ? Colors.white24 : Colors.white10) : (isActive ? Colors.white10 : Colors.transparent)),
                            border: _isFocused ? Border.all(color: Colors.white, width: 2) : null,
                            borderRadius: BorderRadius.circular(8)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(widget.icon, color: _isFocused ? Colors.black : Colors.white, size: isMobile ? 20 : 30),
                          if (widget.label.isNotEmpty) ...[
                            SizedBox(width: isMobile ? 6 : 8),
                            Text(widget.label, style: TextStyle(color: _isFocused ? Colors.black : Colors.white, fontSize: isMobile ? 12 : 16, fontWeight: widget.isBold ? FontWeight.w900 : FontWeight.bold)),
                          ]
                        ]))))));
  }
}

/// Dígito con ruleta vertical (odómetro): tira 0-9 que rota hasta el
/// valor actual. La altura se mide de la propia fuente para un encaje exacto.
/// El wrap (9→0 / 0→9) usa duplicados en los bordes para seguir girando en
/// la dirección del scrub en vez de rebobinar.
class _OdometerDigit extends StatefulWidget {
  final int value; // 0-9
  final TextStyle style;
  final int direction; // +1 adelante, -1 atrás

  const _OdometerDigit({
    required this.value,
    required this.style,
    this.direction = 1,
  });

  @override
  State<_OdometerDigit> createState() => _OdometerDigitState();
}

class _OdometerDigitState extends State<_OdometerDigit> {
  late double _from;
  late double _to;
  double _lastRendered = 0;

  @override
  void initState() {
    super.initState();
    _from = _to = _lastRendered = widget.value.toDouble();
  }

  @override
  void didUpdateWidget(covariant _OdometerDigit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == oldWidget.value &&
        widget.direction == oldWidget.direction) {
      return;
    }
    double target = widget.value.toDouble();
    if (widget.direction >= 0 && widget.value == 0 && _to >= 8.5) {
      target = 10.0; // wrap adelante: girar al "0" duplicado
    } else if (widget.direction < 0 && widget.value == 9 && _to <= 0.5) {
      target = -1.0; // wrap atrás: girar al "9" duplicado
    }
    _from = _lastRendered;
    _to = target;
  }

  void _snapIfNeeded() {
    double? snap;
    if (_to == 10.0) {
      snap = 0.0;
    } else if (_to == -1.0) {
      snap = 9.0;
    }
    final target = snap;
    if (target == null) return;
    setState(() {
      _from = target;
      _to = target;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tp = TextPainter(
      text: TextSpan(text: '8', style: widget.style),
      textDirection: TextDirection.ltr,
    )..layout();
    final h = tp.height;
    // Tira con duplicados en los bordes: [9][0..9][0], altura exacta.
    return SizedBox(
      height: h,
      child: ClipRect(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: _from, end: _to),
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          onEnd: _snapIfNeeded,
          builder: (context, pos, _) {
            _lastRendered = pos ?? _to;
            return Transform.translate(
              offset: Offset(0, -(pos + 1) * h),
              child: SizedBox(
                height: h * 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: h, child: Text('9', style: widget.style)),
                    for (var i = 0; i <= 9; i++)
                      SizedBox(height: h, child: Text('$i', style: widget.style)),
                    SizedBox(height: h, child: Text('0', style: widget.style)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ZeroPaddingSliderTrackShape extends RoundedRectSliderTrackShape {
  const _ZeroPaddingSliderTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 4;
    final double trackLeft = offset.dx;
    final double trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
    double additionalActiveTrackHeight = 0.0,
  }) {
    if (sliderTheme.trackHeight == null || sliderTheme.trackHeight! <= 0) {
      return;
    }

    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final Paint activePaint = Paint()
      ..color = sliderTheme.activeTrackColor ?? const Color(0xFFEF7A1E);
    final Paint inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor ?? Colors.white.withOpacity(0.25);

    final Radius radius = Radius.circular(trackRect.height / 2);

    // Inactive track (full width)
    context.canvas.drawRRect(RRect.fromRectAndRadius(trackRect, radius), inactivePaint);

    // Active track (from left to thumb center)
    final double thumbRight = thumbCenter.dx.clamp(trackRect.left, trackRect.right);
    if (thumbRight > trackRect.left) {
      final Rect activeRect = Rect.fromLTRB(trackRect.left, trackRect.top, thumbRight, trackRect.bottom);
      context.canvas.drawRRect(RRect.fromRectAndRadius(activeRect, radius), activePaint);
    }
  }
}

class _NetflixProgressBar extends StatefulWidget {
  const _NetflixProgressBar({super.key});
  @override
  State<_NetflixProgressBar> createState() => _NetflixProgressBarState();
}

class _NetflixProgressBarState extends State<_NetflixProgressBar> {
  double _progress = 0.0;
  late DateTime _startTime;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    // CRONÓMETRO MANUAL: Garantiza 5 segundos reales independientemente del motor de frames
    _timer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      final elapsed = DateTime.now().difference(_startTime).inMilliseconds;
      final double newProgress = (elapsed / 5000).clamp(0.0, 1.0);
      
      if (mounted) {
        setState(() {
          _progress = newProgress;
        });
      }
      
      if (newProgress >= 1.0) {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: _progress,
      child: Container(
        color: const Color(0xFFFFFFFF),
      ),
    );
  }
}

class _RemoteMandoActionButton extends StatelessWidget {
  final Object icon;
  final String label;
  final VoidCallback onTap;

  const _RemoteMandoActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon is String
                ? AurisIcon(icon as String, color: Colors.white, size: 20)
                : Icon(icon as IconData?, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



// _ZeroPaddingSliderTrackShape removed
