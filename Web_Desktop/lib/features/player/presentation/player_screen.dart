import 'dart:async';
import 'dart:io';
import 'dart:ui';

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
import 'package:volume_controller/volume_controller.dart';
import 'package:collection/collection.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'package:auris_core/auris_core.dart';
import '../../../core/utils/app_fullscreen.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/utils/url_utils.dart';
import '../../../core/utils/screen_brightness.dart';
import '../../../core/utils/web_utils.dart';

import '../../remote_control/presentation/providers/remote_control_provider.dart';
import '../../remote_control/data/models/remote_device.dart';
import '../../remote_control/presentation/widgets/device_selector_dialog.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final String contentId;
  final String sourceUrl;
  final String source;
  final String? episode;
  final int? season;
  final String? serverName;
  final String? language;
  final int? startPosition;
  final String? category;
  final int? totalEpisodes;
  final String? title;
  final String? metadataTitle;
  final String? episodeTitle;
  final String? posterUrl;
  final String? bannerUrl;
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
    this.language,
    this.startPosition,
    this.category,
    this.totalEpisodes,
    this.title,
    this.metadataTitle,
    this.episodeTitle,
    this.posterUrl,
    this.bannerUrl,
    this.video720,
    this.video1080,
    this.skipResume = false,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

enum PlayerOverlay { none, language, server, quality }

class _PlayerScreenState extends ConsumerState<PlayerScreen> with WidgetsBindingObserver {
  bool get _isMovie => widget.category == 'movie' || widget.category == 'movie_anime' || widget.episode == 'Trailer';
  Player? _player;
  VideoController? _controller;
  int _selectedTrackIndex = 0;

  String get _currentTrackQuality {
    if (_allTracks.isEmpty) return '';
    final i = _selectedTrackIndex < _allTracks.length ? _selectedTrackIndex : 0;
    return _allTracks[i].quality;
  }

  // StreamSubscription<Tracks>? _tracksSubscription;
  WebViewController? _webViewController;
  bool _hasInitialized = false;

  bool _showControls = true;
  bool _isLocked = false;
  bool _isLandscapeOnly = true;
  bool _hasResetPosition = false;
  int _resumePosition = 0;
  DateTime? _resumeGuardUntil;
  int _resumeGuardRetries = 0;
  Timer? _hideTimer;
  double _playbackSpeed = 1.0;
  StreamSubscription? _posSubscription;
  StreamSubscription? _completedSubscription;
  StreamSubscription? _fullscreenSubscription;
  bool _isStabilizing = false;
  Timer? _stabilizationTimer;
  bool _isMobileDevice = false;
  bool _isFullscreen = false;
  bool _isBoostActive = false; // Senior Fix: Flag para rastrear si el audio ya está enganchado a WebAudio
  bool _isExiting = false;
  bool _showEpisodesOverlay = false;
  bool _webNeedsInteraction = false; // Senior Web Fix: Autoplay blocker
  YoutubePlayerController? _ytController;
  PlayerOverlay _activeOverlay = PlayerOverlay.none;
  bool _isVolumePillHovered = false;
  Timer? _volumeExitTimer;
  String _selectedQuality = 'auto';
  bool _userHasPaused = false;
  bool _showCenterIndicator = false;
  IconData _centerIndicatorIcon = Symbols.play_arrow;
  Timer? _centerIndicatorTimer;
  // final GlobalKey _sliderKey = GlobalKey();
  final ValueNotifier<Offset?> _hoverInfoNotifier = ValueNotifier<Offset?>(null);

  // Senior Pro Gestures State
  // double? _gestureStartX;
  int _lastSkipValue = 0;
  Timer? _skipVisualTimer;
  bool _showLeftSkip = false;
  bool _showRightSkip = false;
  // double _lastGestureValue = 0.0;
  bool? _isBrightnessGesture;
  double _lastAppliedBrightness = -1.0;
  double _lastAppliedVolume = -1.0;
  bool _showSeekIndicator = false;
  Duration _seekTargetDuration = Duration.zero;
  Duration _seekDiff = Duration.zero;
  Timer? _historySaveTimer;

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
      // Senior Fix: En Web, solo usamos el ciclo de iconos si ya estamos en Fullscreen (Modo Táctico)
      // o si es un dispositivo móvil detectado.
      return ResponsiveUtils.isTactic(context) && _isFullscreen;
    }
    return _isMobileDevice || ResponsiveUtils.isTablet(context);
  }

  bool _isLoading = true;
  bool _isCompleted = false;
  StreamSubscription<bool>? _bufferingSubscription;
  StreamSubscription<double>? _volumeSubscription;

  List<VideoTrackOption> _extractTracks = [];
  List<VideoTrackOption> _allTracks = [];

  /// Calidades disponibles de la pista actual (parseadas del master HLS).
  List<QualityOption> _qualityOptions = [];

  /// Stream base de la pista actual (para volver a "Automático").
  String _currentStreamUrl = '';
  Map<String, String> _currentStreamHeaders = const {};

  double _volume = 1.0;
  double _brightness = 0.5;
  bool _showVolumeIndicator = false;
  bool _showBrightnessIndicator = false;
  Timer? _indicatorTimer;

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

  // Un especial (Temporada 0) debe mostrar su propio título en el player, no el
  // del anime/temporada. Para eso content_screen envía `episodeTitle`.
  bool get _isSpecial => widget.season == 0;
  String get _displayTitle {
    if (_isTrailer) return 'Tráiler: ${widget.title ?? widget.contentId}';
    if (_isSpecial && widget.episodeTitle?.isNotEmpty == true) return widget.episodeTitle!;
    if (_isSpecial) return widget.title ?? widget.contentId;
    return widget.title ?? widget.contentId;
  }

  /// Si el contenido actual es un Opening (OP) o Ending (ED).
  bool get _isOpEd => widget.episode == 'OP' || widget.episode == 'ED';
  bool get _isTrailer => widget.episode == 'Trailer';

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
    // Escuchar comandos y cambios de estado remoto
    Future.delayed(Duration.zero, () {
      if (!mounted) return;
      
      // 1. Escuchar comandos entrantes (cuando somos el RECEPTOR/TARGET)
      ref.listenManual(
        remoteControlProvider.select((s) => s.lastReceivedCommand),
        (previous, next) {
          if (next != null && next != previous) {
            _handleRemoteCommand(next);
          }
        },
      );

      // 2. Escuchar si empezamos a transmitir (cuando somos el EMISOR/CONTROLADOR)
      ref.listenManual(
        remoteControlProvider.select((s) => s.activeTargetDeviceId),
        (previous, next) {
          if (next != null && previous == null) {
            // Empezamos a transmitir: Parar local para ahorrar recursos y evitar eco
            _player?.pause();
            _userHasPaused = true;
            debugPrint('[AurisRemote] Local playback paused. Entering remote mode.');
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
    // Throttling: solo cada 3 segundos para comandos fluidos pero eficientes
    // EXCEPCIÓN: Si los tracks acaban de cargar, forzamos reporte.
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

  void _showDeviceSelector() {
    showDialog(
      context: context,
      builder: (context) => const DeviceSelectorDialog(),
    );
  }

  Widget _buildCastIcon(double iconSize, {Color? color}) {
    final remoteState = ref.watch(remoteControlProvider);
    final activeTargetId = remoteState.activeTargetDeviceId;
    final isCasting = activeTargetId != null;
    
    IconData castIcon = Symbols.devices;
    Color iconColor = color ?? Colors.white;

    if (isCasting) {
      iconColor = const Color(0xFFEF7A1E);
      final targetDevice = remoteState.availableDevices.firstWhereOrNull((d) => d.id == activeTargetId);
      if (targetDevice != null) {
        switch (targetDevice.type) {
          case RemoteDeviceType.web: castIcon = Symbols.desktop_windows; break;
          case RemoteDeviceType.android: castIcon = Symbols.airplay; break;
          case RemoteDeviceType.windows: castIcon = Symbols.desktop_windows; break;
          case RemoteDeviceType.ios: castIcon = Symbols.phone_iphone; break;
          default: castIcon = Symbols.devices_other;
        }
      }
    }

    return IconButton(
      icon: Icon(
        castIcon, 
        color: iconColor, 
        size: _isMobileDevice ? iconSize : 30,
        fill: isCasting ? 1.0 : 0.0,
      ),
      onPressed: _showDeviceSelector,
    );
  }

  void _applyVolume() {
    // Senior Web/Desktop Fix: Solo usamos el volumen nativo (0-100%) para evitar problemas de CORS
    // y asegurar compatibilidad total en Web y WebView2.
    _player?.setVolume((_volume * 100).clamp(0, 100));
    
    if (kIsWeb && _isBoostActive) {
      // Si el boost estaba activo, lo reseteamos a 1.0 una última vez y dejamos de usarlo.
      WebUtils.applyAudioBoost(1.0);
      _isBoostActive = false;
    }
  }

  void _updateHistory({required int positionMs, required int durationMs, bool force = false}) {
    if (widget.contentId.isEmpty || _historyNotifier == null || _isOpEd || _isTrailer) return;
    
    // Senior Performance Fix: Throttling de guardado en base de datos.
    // Solo guardamos si es 'force' o si han pasado 1s desde el último movimiento.
    if (!force) {
      _historySaveTimer?.cancel();
      _historySaveTimer = Timer(const Duration(seconds: 1), () {
        if (!mounted) return;
        _performHistoryUpdate(positionMs, durationMs, force: false);
      });
      return;
    }
    
    _performHistoryUpdate(positionMs, durationMs, force: true);
  }

  void _performHistoryUpdate(int positionMs, int durationMs, {bool force = false}) {
    _historyNotifier!.updatePosition(
      contentId: widget.contentId,
      season: widget.season,
      episode: _activeEpisode,
      positionMs: positionMs,
      durationMs: durationMs,
      title: widget.title,
      posterUrl: widget.posterUrl,
      bannerUrl: widget.bannerUrl,
      category: widget.category,
      source: widget.source,
      url: _currentSourceUrl,
      language: _currentLanguage,
      alternativeSources: ref.read(activeContentSourcesProvider),
      force: force,
    );
  }

  PlaybackHistoryNotifier? _historyNotifier;
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
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _historyNotifier = ref.read(playbackHistoryStateProvider.notifier);

    if (kIsWeb) {
      _fullscreenSubscription = onFullscreenChanged()?.listen((_) {
        // Senior Web Fix: Si el navegador sale de fullscreen (ej: gesto back del sistema)
        // pero nuestra UI cree que sigue en fullscreen, cerramos el player.
        if (mounted && _isFullscreen && !isAppFullscreen()) {
          _exitPlayer();
        }
      });
    }
    
    _currentSourceUrl = widget.sourceUrl;
    _currentSource = widget.source;
    _currentServerName = widget.serverName;
    _currentLanguage = widget.language;
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
    // [Trailer Fix] Los tráilers no necesitan buscar alternativas ni restaurar fuentes.
    final currentSources = ref.read(activeContentSourcesProvider);
    if (currentSources.isEmpty && !_isTrailer) {
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
      if (!_isTrailer) _findAlternatives();
    } else {
      if (!_isTrailer) _findAlternatives();
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
          quality: widget.language ?? '',
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
    if (kIsWeb && state == AppLifecycleState.resumed) {
      // Senior Web Seamless Fix: Eliminamos el 'seek' para evitar el microcorte de audio.
      // En su lugar, forzamos un rebuild de la UI de Flutter. Esto obliga al widget 'Video'
      // a re-vincularse con la textura del Canvas de media_kit sin interrumpir el stream.
      if (_player != null && _player!.state.playing) {
        debugPrint('[player web] Tab resumed. Waking up renderer without audio interruption.');
        setState(() {
          // El rebuild es suficiente para despertar al motor de dibujo.
        });
      }
    }

    if (!_isMobileDevice) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Senior Shield: Si el usuario minimiza la app o apaga la pantalla, 
      // restauramos la UI del sistema para no "secuestrar" los botones de volumen fuera del player.
      VolumeController().showSystemUI = true;
      _volumeControlChannel.invokeMethod('setIntercept', {'enabled': false});
    } else if (state == AppLifecycleState.resumed) {
      // Al volver al player, retomamos el control total de la interfaz de volumen.
      VolumeController().showSystemUI = false;
      _volumeControlChannel.invokeMethod('setIntercept', {'enabled': true});
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
      padding: isSidebar ? const EdgeInsets.symmetric(horizontal: 16) : EdgeInsets.zero,
      itemCount: servers.length,
      itemBuilder: (context, index) {
        final sName = servers[index];
        final isCurrent = sName == simplifySourceName(_currentSource);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Material(
            color: isCurrent ? const Color(0xFFEF7A1E).withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                if (!isSidebar) Navigator.pop(context);
                else setState(() => _activeOverlay = PlayerOverlay.none);
                
                if (!isCurrent) {
                  _switchSource(_groupedSources[sName]!.first);
                }
              },
              leading: Container(
                width: 44, height: 44, // Senior Fix: Unificado tamaño con selector de idiomas
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: isCurrent ? Border.all(color: const Color(0xFFEF7A1E), width: 2) : null,
                ),
                child: const Center(
                  child: Icon(Symbols.dns, color: Colors.white70, size: 20),
                ),
              ),
              title: Text(
                sName,
                style: TextStyle(
                  color: isCurrent ? Colors.white : Colors.white.withOpacity(0.9),
                  fontSize: 15,
                  fontWeight: isCurrent ? FontWeight.w900 : FontWeight.bold,
                ),
              ),
              subtitle: Text(
                '${_groupedSources[sName]!.length} opciones disponibles',
                style: TextStyle(
                  color: isCurrent ? const Color(0xFFEF7A1E).withOpacity(0.8) : Colors.white38,
                  fontSize: 12,
                ),
              ),
              trailing: isCurrent 
                ? const Icon(Symbols.check_circle, color: Color(0xFFEF7A1E))
                : const Icon(Symbols.arrow_forward_ios, color: Colors.white12, size: 14),
            ),
          ),
        );
      },
    );
  }

  void _showServerSelector() {
    _hideTimer?.cancel();

    setState(() {
      _activeOverlay = _activeOverlay == PlayerOverlay.server ? PlayerOverlay.none : PlayerOverlay.server;
      if (_activeOverlay != PlayerOverlay.none) {
        _showControls = true;
        _hideTimer?.cancel();
      } else {
        _startHideTimer();
      }
    });
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

  void _showQualitySelector() {
    _hideTimer?.cancel();

    setState(() {
      _activeOverlay = _activeOverlay == PlayerOverlay.quality ? PlayerOverlay.none : PlayerOverlay.quality;
      if (_activeOverlay != PlayerOverlay.none) {
        _showControls = true;
        _hideTimer?.cancel();
      } else {
        _startHideTimer();
      }
    });
  }

  Widget _buildQualitySelectorContent({bool isSidebar = false}) {
    final List<Map<String, dynamic>> options = _qualityMenuOptions;

    return ListView.builder(
      shrinkWrap: !isSidebar,
      padding: isSidebar ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8) : EdgeInsets.zero,
      itemCount: options.length,
      itemBuilder: (context, index) {
        final option = options[index];
        final String key = option['key'] as String;
        final String label = option['label'] as String;
        final String sub = option['sub'] as String? ?? '';
        final String? url = option['url'] as String?;
        final bool isAvailable = url != null && url.isNotEmpty;
        final bool isCurrent = _selectedQuality == key;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Material(
            color: isCurrent ? const Color(0xFFEF7A1E).withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              enabled: isAvailable,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                if (!isSidebar) Navigator.pop(context);
                else setState(() => _activeOverlay = PlayerOverlay.none);
                
                if (isAvailable && !isCurrent) {
                  _changeQuality(key);
                }
              },
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: isCurrent ? const Color(0xFFEF7A1E).withOpacity(0.1) : Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCurrent ? Icons.check_circle_rounded : Icons.hd_rounded,
                  color: isCurrent ? const Color(0xFFEF7A1E) : (isAvailable ? Colors.white70 : Colors.white24),
                  size: 24,
                ),
              ),
              title: Text(
                label,
                style: TextStyle(
                  color: isCurrent ? Colors.white : (isAvailable ? Colors.white70 : Colors.white24),
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                isAvailable ? sub : 'No disponible para este tema',
                style: TextStyle(
                  color: isCurrent ? const Color(0xFFEF7A1E).withOpacity(0.7) : Colors.white38,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  BoxDecoration get _controlCapsuleDecoration => BoxDecoration(
    color: Colors.black.withOpacity(0.2), // Ultra-transparente estilo YouTube
    borderRadius: BorderRadius.circular(22),
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
    final bool isBoost = false;
    final int displayPercent = (_volume * 100).round();
    
    IconData volIcon = Symbols.volume_up;
    if (_volume == 0) volIcon = Symbols.volume_off;
    else if (_volume <= 0.5) volIcon = Symbols.volume_down;
    else if (isBoost) volIcon = Symbols.bolt;

    return MouseRegion(
      onEnter: (_) {
        _volumeExitTimer?.cancel();
        if (!_isVolumePillHovered) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _isVolumePillHovered = true);
          });
        }
      },
      onExit: (_) {
        _volumeExitTimer?.cancel();
        _volumeExitTimer = Timer(const Duration(milliseconds: 150), () {
          if (mounted) setState(() => _isVolumePillHovered = false);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        height: 44,
        width: _isVolumePillHovered ? 160 : 44,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(22),
        ),
        padding: const EdgeInsets.all(4), 
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggleMute,
            borderRadius: BorderRadius.circular(18), 
            hoverColor: Colors.white.withOpacity(0.1),
            splashColor: Colors.white.withOpacity(0.1),
            child: Stack(
              children: [
                // Icono (Anclado al inicio)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 36, 
                  child: Center(
                    child: Icon(
                      volIcon, 
                      color: isBoost ? const Color(0xFFEF7A1E) : Colors.white, 
                      size: 20
                    ),
                  ),
                ),
                // Contenido expandible
                Positioned(
                  left: 32,
                  top: 0,
                  bottom: 0,
                  width: 120,
                  child: Row(
                    children: [
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2.5,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6, elevation: 3),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                            activeTrackColor: isBoost ? const Color(0xFFEF7A1E) : Colors.white,
                            inactiveTrackColor: Colors.white.withOpacity(0.2),
                            thumbColor: isBoost ? const Color(0xFFEF7A1E) : Colors.white,
                            overlayColor: (isBoost ? const Color(0xFFEF7A1E) : Colors.white).withOpacity(0.15),
                          ),
                          child: Slider(
                            value: _volume,
                            min: 0.0,
                            max: 1.0,
                            onChanged: (v) {
                              setState(() {
                                _volume = v;
                                _applyVolume();
                              });
                              _startHideTimer();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEpisodesCarousel() {
    setState(() {
      _showEpisodesOverlay = !_showEpisodesOverlay;
      if (_showEpisodesOverlay) {
        _showControls = true;
        _hideTimer?.cancel();
      } else {
        _startHideTimer();
      }
    });
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
    final isMobile = ResponsiveUtils.isMobile(context);
    final sourceOptions = _getLanguageOptions();
    if (sourceOptions.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Text('No hay fuentes disponibles', style: TextStyle(color: Colors.white54)),
      ));
    }

    return ListView.builder(
      shrinkWrap: !isSidebar,
      padding: isSidebar ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8) : EdgeInsets.zero,
      itemCount: sourceOptions.length,
      itemBuilder: (context, index) {
        final entry = sourceOptions[index];
        final s = entry.result;
        final serverName = entry.server;
        final quality = s.quality.toUpperCase();
        final type = trackQualityType(s.quality);
        final isLatino = type != 'SUB';
        final isCastellano = type == 'CAST';
        

        final accentColor = isLatino 
            ? Colors.greenAccent 
            : (isCastellano ? Colors.orangeAccent : Colors.blueAccent);
        
        // Senior Logic: Identificación precisa de la fuente actual
        // Si es un track (sub-fuente), comparamos por índice.
        // Si es una fuente base (servidor), comparamos por URL.
        final bool isCurrent = entry.isTrack 
            ? entry.trackIndex == _selectedTrackIndex
            : s.url == _currentSourceUrl;

        final String? trackBadge = entry.isTrack
            ? _allTracks[entry.trackIndex].label.toUpperCase()
            : null;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Material(
            color: isCurrent ? const Color(0xFFEF7A1E).withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            leading: Stack(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                    border: isCurrent ? Border.all(color: Colors.white, width: 2) : null,
                  ),
                ),
                if (isCurrent)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Color(0xFF0B0B0D), shape: BoxShape.circle),
                      child: const Icon(Icons.check_circle, color: Color(0xFFEF7A1E), size: 16),
                    ),
                  ),
              ],
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMobile || trackBadge == null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      serverName,
                      style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ),
                if (trackBadge != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC107).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFFC107).withOpacity(0.3), width: 1),
                    ),
                    child: Text(
                      trackBadge,
                      style: const TextStyle(color: Color(0xFFFFC107), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                  ),
                ],
                // Idioma/calidad como badge para TODAS las opciones, incluido SUB
                // (antes los SUB solo mostraban la bandera, sin etiqueta de texto,
                // por lo que parecía que todo era DUB). SUB en azul, resto en naranja.
                if (quality.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (trackQualityType(s.quality) == 'SUB')
                          ? Colors.blueAccent.withOpacity(0.14)
                          : const Color(0xFFEF7A1E).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      quality,
                      style: TextStyle(
                        color: (trackQualityType(s.quality) == 'SUB')
                            ? Colors.blueAccent
                            : const Color(0xFFEF7A1E),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: null,
            trailing: isCurrent 
              ? Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF7A1E).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Color(0xFFEF7A1E), size: 20),
                )
              : const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white12, size: 14),
          ),
        ),
      );
    },
  );
  }

  void _showLanguageSelector() {
    _hideTimer?.cancel();

    setState(() {
      _activeOverlay = _activeOverlay == PlayerOverlay.language ? PlayerOverlay.none : PlayerOverlay.language;
      if (_activeOverlay != PlayerOverlay.none) {
        _showControls = true;
        _hideTimer?.cancel();
      } else {
        _startHideTimer();
      }
    });
  }

  @override
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isMobileDevice = kIsWeb && ResponsiveUtils.isTactic(context);
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

    final preloaded = ref.read(nextEpisodePreloadProvider);
    if (preloaded != null && next) {
      final tracks = preloaded.tracks.where((t) => !t.isDownload).toList();
      final sources = ref.read(activeContentSourcesProvider);
      final baseSource = sources.firstWhereOrNull((s) => s.source == _currentSource);
      final String nextSourceUrl = baseSource != null
          ? buildEpisodeUrl(baseSource.url, baseSource.source, nextNum)
          : _currentSourceUrl;

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
        final trackIdx = _indexForLanguage(tracks, _currentLanguage);
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

    _onEpisodeChanged(nextNum);
  }

  void _onEpisodeChanged(int epNum) {
    // Senior Web Fix: Al cambiar de episodio vía Autoplay o Menú, 
    // simplemente actualizamos el estado interno. Como el reproductor
    // es un diálogo/overlay, no necesitamos tocar la URL del navegador.
    final currentNum = int.tryParse(_currentEpisode ?? '1') ?? 1;
    if (epNum == currentNum) return;

    final sources = ref.read(activeContentSourcesProvider);
    final baseSource = sources.firstWhereOrNull((s) => s.source == _currentSource);
    final String nextSourceUrl = baseSource != null
        ? buildEpisodeUrl(baseSource.url, baseSource.source, epNum)
        : _currentSourceUrl;

    setState(() {
      _showEpisodesOverlay = false;
      _currentEpisode = epNum.toString();
      _currentSourceUrl = nextSourceUrl;
      _hasInitialized = false; 
      _isStabilizing = true;
      _skipResumeOnNextInit = true;
      _resumePosition = 0;
      _isAutoplayResume = false;
      _hasResetPosition = false;
      _showNextNotifier.value = false;
      _autoplayCountdown = -1;
    });

    if (baseSource != null && baseSource.source == 'Aniyae') {
      _resolveEpisodeUrl(baseSource, epNum);
    }
  }

  /// Senior Language Fix: Devuelve el índice de la pista a reproducir según el
  /// idioma elegido. Si el doblaje (LAT) aún no está subido para este episodio,
  /// cae automáticamente al SUB; si tampoco hay SUB, usa la primera disponible.
  int _indexForLanguage(List<VideoTrackOption> tracks, String? language) {
    if (tracks.isEmpty) return 0;

    // Senior Fix: Usar preferencia del usuario si no hay un idioma forzado por la navegación
    final settings = ref.read(settingsProvider);
    final String pref = settings.preferredLanguage;
    final String effectiveLang = language ?? (pref == 'latino' ? 'LAT' : (pref == 'castellano' ? 'CAST' : 'SUB'));

    final isLat = effectiveLang == 'LAT' || effectiveLang == 'DUB';
    final isCast = effectiveLang == 'CAST';
    
    final latIdx = tracks.indexWhere((t) => trackQualityType(t.quality) == 'DUB');
    final castIdx = tracks.indexWhere((t) => trackQualityType(t.quality) == 'CAST');
    final subIdx = tracks.indexWhere((t) => trackQualityType(t.quality) == 'SUB');

    if (isLat && latIdx >= 0) return latIdx;
    if (isCast && castIdx >= 0) return castIdx;
    if (subIdx >= 0) return subIdx;
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
    if (_isTrailer) return; // [Trailer Fix] No hay reproducción automática para tráilers

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

  void _handleVolumeStep(double step) {
    // _lastManualVolumeTime = DateTime.now();
    _safeSetState(() {
      double currentSnapped = (_volume * 20).round() / 20.0;
      double nextVol = currentSnapped + step;

      if (currentSnapped < 1.0 && nextVol > 1.0) nextVol = 1.0;
      else if (currentSnapped > 1.0 && nextVol < 1.0) nextVol = 1.0;
      else if ((nextVol - 1.0).abs() < 0.02) nextVol = 1.0;
      
      _volume = nextVol.clamp(0.0, 1.0);
      _applyVolume();
      _showVolumeIndicator = true;
      _showBrightnessIndicator = false;
    });
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showVolumeIndicator = false);
    });
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    final key = event.logicalKey;
    final isVolumeKey = key == LogicalKeyboardKey.audioVolumeUp || key == LogicalKeyboardKey.audioVolumeDown;
    
    // Senior Elite Shield: Para las teclas de volumen, interceptamos TODO el ciclo de vida
    // (KeyDown, KeyRepeat, KeyUp) para garantizar que el sistema nunca vea el evento.
    if (isVolumeKey) {
      if (event is KeyDownEvent || event is KeyRepeatEvent) {
        _handleVolumeStep((key == LogicalKeyboardKey.audioVolumeUp) ? 0.05 : -0.05);
      }
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent) {
      if (_isLocked) return KeyEventResult.ignored;
      
      if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) {
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
        _toggleControls();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyL) {
        _skipForward();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyJ) {
        _skipBackward();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.keyF) {
        _toggleFullscreen();
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.keyM) {
        setState(() {
          _volume = _volume > 0 ? 0.0 : 1.0;
          _applyVolume();
          _showVolumeIndicator = true;
        });
        _indicatorTimer?.cancel();
        _indicatorTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showVolumeIndicator = false);
        });
        return KeyEventResult.handled;
      } else if (key == LogicalKeyboardKey.escape) {
        _handleBackNavigation();
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
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_isLocked) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    if (!mounted) return;
    setState(() {
      _showControls = !_showControls;
      if (_showControls) _startHideTimer();
    });
  }

  void _showCentralIndicator(bool playing) {
    _centerIndicatorTimer?.cancel();
    setState(() {
      _centerIndicatorIcon = playing ? Symbols.play_arrow : Symbols.pause;
      _showCenterIndicator = true;
    });
    _centerIndicatorTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showCenterIndicator = false);
    });
  }

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

    // Activamos Visual Feedback con acumulación
    setState(() {
      _lastSkipValue = isRapidFire ? _lastSkipValue + 10 : 10;
      _showRightSkip = true;
      _showLeftSkip = false;
    });

    _skipVisualTimer?.cancel();
    _skipVisualTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() { _showLeftSkip = false; _showRightSkip = false; });
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

    // Activamos Visual Feedback con acumulación
    setState(() {
      _lastSkipValue = isRapidFire ? _lastSkipValue + 10 : 10;
      _showLeftSkip = true;
      _showRightSkip = false;
    });

    _skipVisualTimer?.cancel();
    _skipVisualTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() { _showLeftSkip = false; _showRightSkip = false; });
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
    // Senior Youtube Fix: Detectar URLs de YouTube para usar el player especializado
    // y evitar errores del motor nativo (MPV) sin yt-dlp.
    if (videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be')) {
      final id = _extractYoutubeId(videoUrl);
      if (id != null) {
        _initYoutubePlayer(id);
        return;
      }
    }

    // En Android el backend devuelve URLs con localhost:3000 (el servidor corre
    // en el PC); hay que apuntar a la IP real de la LAN para que el dispositivo
    // pueda llegar al servidor.
    videoUrl = ApiEndpoints.fixUrl(videoUrl);
    final bool isHls = videoUrl.contains('.m3u8');

    // Senior Quality Fix: Guardar el stream base para poder volver a "Automático".
    _currentStreamUrl = videoUrl;
    _currentStreamHeaders = headers;
    
    // Senior: Obtener historial al inicio para setear la propiedad 'start' de MPV
    // [PlaybackHistory] Ignoramos historial para OP/ED y Tráilers
    final history = (_isOpEd || _isTrailer) ? null : _historyNotifier?.getProgress(widget.contentId, widget.season, _activeEpisode);
    final int historyPos = (history != null && history.positionInMilliseconds > 3000) ? history.positionInMilliseconds : 0;

    final bool isSwitching = _resumePosition > 0;
    // Senior Autoplay Fix: Si venimos de una navegación de episodio, saltamos el
    // diálogo de "reanudar" aunque el widget se haya recreado (widget.skipResume).
    final bool skipResume = _skipResumeOnNextInit || widget.skipResume;
    _skipResumeOnNextInit = false;

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
           _hasResetPosition = false; 
        } else if (!skipResume && historyPos > 0) {
           _resumePosition = historyPos;
           _hasResetPosition = false;
           // En lugar de mostrar el diálogo estático, disparamos el contador blanco de reanudación
           WidgetsBinding.instance.addPostFrameCallback((_) {
             if (mounted) _startAutoplayCountdown(isResume: true);
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
    _fullscreenSubscription?.cancel();
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
        platform.setProperty('msg-level', 'all=error');
        platform.setProperty('cache', 'yes');
        platform.setProperty('cache-on-disk', 'no');
        platform.setProperty('demuxer-max-bytes', '536870912'); 
        platform.setProperty('demuxer-readahead-secs', '120');
        platform.setProperty('video-sync', 'audio'); 
        platform.setProperty('mc', '0'); 
        platform.setProperty('autosync', '30'); 
        platform.setProperty('audio-buffer', '3'); 
        platform.setProperty('volume-max', '200');
        platform.setProperty('cache-pause', 'yes'); 
        platform.setProperty('stream-buffer-size', '10MiB'); 
        platform.setProperty('vd-lavc-threads', '8'); 
        platform.setProperty('hwdec', 'auto-safe'); // Senior Fix: Usar auto-safe para evitar bloqueos si el codec falla
        platform.setProperty('tls-verify', 'no');
        platform.setProperty('demuxer-lavf-o', 'probesize=10000000,analyzeduration=10000000,fflags=+genpts,seek2any=1');
        platform.setProperty('user-agent', finalHeaders['User-Agent'] ?? 'Mozilla/5.0');

        if (finalHeaders.containsKey('Referer')) {
          platform.setProperty('referrer', finalHeaders['Referer']!);
        }
      }
    } catch (_) {}

    _controller ??= VideoController(player, configuration: const VideoControllerConfiguration(androidAttachSurfaceAfterVideoParameters: false));

    _checkAutoFullscreen();

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
        unawaited(_resumeSeekWhenReady(Duration(milliseconds: _resumePosition), player));
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
            unawaited(_webResumeSeek(player, resumeMs));
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
  Future<void> _resumeSeekWhenReady(Duration target, Player player) async {
    int waited = 0;
    while (waited < 60 && mounted) {
      await Future.delayed(const Duration(milliseconds: 100));
      waited++;
      final d = player.state.duration;
      final p = player.state.position.inMilliseconds;
      if (d > Duration.zero) break;
      if (p > 150) break;
    }
    if (!mounted) return;

    final tMs = target.inMilliseconds;
    for (int attempt = 0; attempt < 3 && mounted; attempt++) {
      final before = player.state.position.inMilliseconds;
      if (before >= tMs - 2000 && before <= tMs + 4000) {
        debugPrint('[player] Resume confirmado en $before (objetivo $tMs)');
        return;
      }
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
  Future<void> _webResumeSeek(Player player, int targetMs) async {
    int waited = 0;
    while (waited < 80 && mounted) {
      await Future.delayed(const Duration(milliseconds: 100));
      waited++;
      if (player.state.position.inMilliseconds > 0) break;
      if (player.state.duration > Duration.zero) break;
    }
    if (!mounted) return;

    for (int attempt = 0; attempt < 3 && mounted; attempt++) {
      final before = player.state.position.inMilliseconds;
      if (before >= targetMs - 1500) break;
      debugPrint('[player] Web resume seek $targetMs (attempt ${attempt + 1}, pos $before)');
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

  void _initYoutubePlayer(String videoId) {
    if (_player != null) {
      _player!.pause();
    }
    _ytController = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        mute: false,
        playsInline: true,
      ),
    );
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasInitialized = true;
        _playbackError = null;
      });
      _checkAutoFullscreen();
    }
  }

  void _checkAutoFullscreen() {
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
  }

  String? _extractYoutubeId(String url) {
    try {
      if (url.contains('v=')) return url.split('v=').last.split('&').first;
      if (url.contains('youtu.be/')) return url.split('/').last.split('?').first;
      if (url.contains('embed/')) return url.split('embed/').last.split('?').first;
      final uri = Uri.parse(url);
      if (uri.pathSegments.isNotEmpty && (uri.host.contains('youtube.com') || uri.host.contains('youtu.be'))) {
        return uri.pathSegments.last;
      }
    } catch (_) {}
    return null;
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
    // Senior Fix: Cancelar TODOS los timers para evitar fugas de memoria y llamadas a setState
    _loadWatchdogTimer?.cancel();
    _hideTimer?.cancel();
    _autoplayTimer?.cancel();
    _stabilizationTimer?.cancel();
    _indicatorTimer?.cancel();
    _historySaveTimer?.cancel();
    _bufferingDebounceTimer?.cancel();
    _volumeSubscription?.cancel();
    _volumeControlChannel.setMethodCallHandler(null);
    
    if (_isMobileDevice && _isExiting) {
      VolumeController().showSystemUI = true;
      _volumeControlChannel.invokeMethod('setIntercept', {'enabled': false});
    }
    _posSubscription?.cancel();
    _bufferingSubscription?.cancel();
    _completedSubscription?.cancel();
    _fullscreenSubscription?.cancel();
    _errorSubscription?.cancel();
    _logSubscription?.cancel();
    _playingSubscription?.cancel();
    _ytController?.close();

    final ms = _player?.state.position.inMilliseconds ?? 0;
    final duration = _player?.state.duration.inMilliseconds ?? 0;
    
    // Senior Shield: Solo guardamos si el reproductor realmente logró sincronizar la posición
    // de reanudación. Si cerramos antes de que MPV enganche, evitamos sobreescribir con 0ms.
    if (_hasResetPosition && ms > 3000 && duration > 0) {
      _updateHistory(
        positionMs: ms,
        durationMs: duration,
        force: true,
      );
    }
    
    _historyNotifier?.flush();

    WidgetsBinding.instance.removeObserver(this);

    _indicatorTimer?.cancel();
    _historySaveTimer?.cancel();
    _skipVisualTimer?.cancel();
    _centerIndicatorTimer?.cancel();
    _stabilizationTimer?.cancel();
    _volumeExitTimer?.cancel();

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
      _volumeControlChannel.invokeMethod('setIntercept', {'enabled': false});
    }
    
    _showNextNotifier.dispose();
    _hoverInfoNotifier.dispose();
    super.dispose();
  }

  void _handleBackNavigation() {
    if (_activeOverlay != PlayerOverlay.none) {
      setState(() => _activeOverlay = PlayerOverlay.none);
      _startHideTimer();
      return;
    }

    if (_showEpisodesOverlay) {
      setState(() => _showEpisodesOverlay = false);
      _startHideTimer();
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
      _volumeControlChannel.invokeMethod('setIntercept', {'enabled': false});
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      VolumeController().showSystemUI = true;
    }

    // 3. Salida limpia usando GoRouter para asegurar consistencia
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/'); 
          }
        }
      });
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

    // Senior Direct Flow: Fuentes que ya entregan el stream directo o proxied
    final bool isDirectSource = _currentSource == 'Themes' || _currentSource == 'YouTube';

    if (_isTrailer || isDirectSource || (widget.source.isEmpty && widget.sourceUrl.isNotEmpty)) {
      if (!_hasInitialized) {
        _hasInitialized = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _initPlayer(widget.sourceUrl);
        });
      }
      return Material(color: Colors.black, child: _playerView(settings: settings));
    }

    final extractAsync = ref.watch(extractProvider(ExtractParams(
      url: _currentSourceUrl, 
      source: _currentSource,
      category: widget.category,
    )));

    return Material(
      color: Colors.black,
      child: extractAsync.when(
        data: (result) {
          final tracks = result.tracks;
          final playableTracks = tracks.where((t) => !t.isDownload).toList();
          if (!_hasInitialized) {
            _hasInitialized = true;
            _selectedTrackIndex = _indexForLanguage(playableTracks, _currentLanguage);
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
      backgroundColor: const Color(0xFF0B0B0D),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double h = constraints.maxHeight;
          final bool isLandscape = h < 550;

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
                        padding: EdgeInsets.symmetric(
                          horizontal: isLandscape ? 32 : 40,
                          vertical: isLandscape ? 8 : 20,
                        ),
                        child: Column(
                          children: [
                            if (isLandscape)
                              _buildLandscapeRemoteLayout(target)
                            else
                              _buildPortraitRemoteLayout(target),
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
          _buildCastIcon(28),
        ],
      ),
    );
  }

  Widget _buildPortraitRemoteLayout(RemoteDevice target) {
    return Column(
      children: [
        const SizedBox(height: 60),
        Text(
          _displayTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
        ),
        if (_activeEpisode != null && !_isMovie)
          Text(
            _isSpecial ? 'Temporada 0' : 'Episodio $_activeEpisode',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 18, fontWeight: FontWeight.bold),
          ),
        const SizedBox(height: 60),
        _buildRemoteControls(target),
      ],
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
            _isSpecial ? 'Temporada 0' : 'Episodio $_activeEpisode',
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
            if (!_isTrailer) ...[
              IconButton(
                iconSize: 32,
                icon: const Icon(Symbols.skip_previous, color: Colors.white70),
                onPressed: () => _handleRemoteNavigation(false, target),
              ),
              const SizedBox(width: 16),
            ],
            IconButton(
              iconSize: 40,
              icon: const Icon(Symbols.replay_10, color: Colors.white),
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
                icon: Icon(
                  target.isPlaying ? Symbols.pause : Symbols.play_arrow,
                  color: Colors.black,
                  fill: 1.0,
                ),
                onPressed: () => _sendRemoteAction(target, target.isPlaying ? RemoteAction.pause : RemoteAction.play),
              ),
            ),
            const SizedBox(width: 32),
            IconButton(
              iconSize: 40,
              icon: const Icon(Symbols.forward_10, color: Colors.white),
              onPressed: () => _sendRemoteSeek(target, 10000),
            ),
            if (!_isTrailer) ...[
              const SizedBox(width: 16),
              IconButton(
                iconSize: 32,
                icon: const Icon(Symbols.skip_next, color: Colors.white70),
                onPressed: () => _handleRemoteNavigation(true, target),
              ),
            ],
          ],
        ),
        if (!_isMobileDevice) ...[
          const SizedBox(height: 32),
          Row(
            children: [
              const Icon(Symbols.volume_down, color: Colors.white54, size: 20),
              Expanded(
                child: Slider(
                  value: target.volume.clamp(0.0, 1.0),
                  activeColor: const Color(0xFFEF7A1E),
                  inactiveColor: Colors.white10,
                  onChanged: (v) => _sendRemoteAction(target, RemoteAction.setVolume, {'volume': v}),
                ),
              ),
              const Icon(Symbols.volume_up, color: Colors.white54, size: 20),
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
                icon: Symbols.fast_forward,
                label: 'SALTAR OP/ED',
                onTap: () => _sendRemoteAction(target, RemoteAction.skipOpEd),
              ),
            if (!_isOpEd && target.availableTracks.length > 1) ...[
              const SizedBox(width: 16),
              _RemoteMandoActionButton(
                icon: Symbols.subtitles,
                label: 'IDIOMA',
                onTap: () => _showRemoteLanguageSelector(target),
              ),
            ],
            if (!_isOpEd && !_isMovie) ...[
              const SizedBox(width: 16),
              _RemoteMandoActionButton(
                icon: Symbols.video_library,
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
      backgroundColor: const Color(0xFF1A1A1A),
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
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final episodesAsync = ref.watch(episodesProvider(EpisodesParams(
          url: widget.sourceUrl,
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
                      return ListView.builder(
                        controller: scrollController,
                        itemCount: data.episodes.length,
                        itemBuilder: (context, index) {
                          final ep = data.episodes[index];
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
    final baseSource = sources.firstWhereOrNull((s) => s.source == _currentSource);

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
    if (_ytController != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),
          Center(
            child: YoutubePlayer(
              controller: _ytController!,
              aspectRatio: 16 / 9,
            ),
          ),
          Positioned(
            top: 60,
            left: 16,
            child: SafeArea(
              child: PointerInterceptor(
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 30),
                  onPressed: _exitPlayer,
                  style: IconButton.styleFrom(backgroundColor: Colors.black45),
                ),
              ),
            ),
          ),
        ],
      );
    }

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

  Widget _buildGestureIndicator(bool isBrightness, double value) {
    final bool isBoost = false;
    final IconData icon = isBrightness 
        ? (value > 0.7 ? Icons.brightness_7_rounded : (value > 0.3 ? Icons.brightness_6_rounded : Icons.brightness_2_rounded))
        : (value > 1.0 ? Icons.bolt_rounded : (value > 0.5 ? Icons.volume_up_rounded : (value > 0 ? Icons.volume_down_rounded : Icons.volume_off_rounded)));

    return Align(
      alignment: isBrightness ? Alignment.centerLeft : Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
                border: Border.all(color: isBoost ? Colors.orangeAccent.withOpacity(0.5) : Colors.white10),
              ),
              child: Icon(icon, color: isBoost ? Colors.orangeAccent : Colors.white, size: 28),
            ),
            const SizedBox(height: 16),
            Container(
              height: 160,
              width: 8,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  FractionallySizedBox(
                    heightFactor: isBrightness ? value.clamp(0.0, 1.0) : (value / 2.0).clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isBoost ? Colors.orangeAccent : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${(value * 100).toInt()}%',
              style: TextStyle(
                color: isBoost ? Colors.orangeAccent : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkipVisual(bool isRight) {
    final bool isMobile = ResponsiveUtils.isMobile(context);
    
    return Align(
      alignment: isRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: MediaQuery.sizeOf(context).width / 4,
        height: double.infinity,
        // Solo mostramos un fondo sutil en móvil para delimitar la zona táctil
        decoration: isMobile ? BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.only(
            topLeft: isRight ? const Radius.circular(500) : Radius.zero,
            bottomLeft: isRight ? const Radius.circular(500) : Radius.zero,
            topRight: !isRight ? const Radius.circular(500) : Radius.zero,
            bottomRight: !isRight ? const Radius.circular(500) : Radius.zero,
          ),
        ) : null,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isRight) const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 36),
              const SizedBox(width: 4),
              Text(
                '${isRight ? "+" : "-"}${_lastSkipValue}',
                style: GoogleFonts.poppins(
                  color: Colors.white, 
                  fontWeight: FontWeight.w500, 
                  fontSize: isMobile ? 22 : 32,
                  shadows: const [Shadow(color: Colors.black45, blurRadius: 8)],
                ),
              ),
              const SizedBox(width: 4),
              if (isRight) const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 36),
            ],
          ),
        ),
      ),
    );
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
    final bool isAnyGestureActive = _isBrightnessGesture != null || _showSeekIndicator;
    final bool showAnyway = (_showControls || _isLocked || (_autoplayCountdown >= 0 && _isAutoplayResume) || _showEpisodesOverlay || _activeOverlay != PlayerOverlay.none) && !isAnyGestureActive;

    return Focus(
      autofocus: true, 
      onKeyEvent: (node, event) => _handleKeyEvent(event), 
      child: Stack(
        fit: StackFit.expand, 
        children: [
          if (_webViewController != null)
            RepaintBoundary(child: WebViewWidget(controller: _webViewController!))
          else if (_controller != null)
            RepaintBoundary(
              child: AnimatedOpacity(
                // Senior Visual Shield: Opacidad 0 hasta que el seek de reanudación sea estable
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

          // EL DETECTOR UNIVERSAL DE GESTOS Y CAPA DE CONTROLES
          // Senior Elite Fix: Unificamos todo bajo un solo PointerInterceptor para evitar que
          // las capas de UI bloqueen el GestureDetector de fondo en Web.
          Positioned.fill(
            child: PointerInterceptor(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // CAPA 1: El detector de gestos (Fondo)
                  MouseRegion(
                    onHover: (_) { 
                      if (ResponsiveUtils.isTactic(context)) return;
                      if (!_showControls && !_isLocked) setState(() => _showControls = true); 
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
                          if (_isLocked) return;
                          if (!_isMobileDevice) {
                            final bool wasPlaying = _player?.state.playing ?? false;
                            if (wasPlaying) _player?.pause(); else _player?.play();
                            _showCentralIndicator(!wasPlaying);
                            if (!_showControls) setState(() => _showControls = true);
                            _startHideTimer();
                          } else {
                            _toggleControls();
                          }
                        },
                        behavior: HitTestBehavior.opaque, 
                        onDoubleTapDown: (details) { 
                          if (_isLocked) return; 
                          final width = MediaQuery.sizeOf(context).width; 
                          final bool isRight = details.globalPosition.dx >= width / 2;
                          if (isRight) _skipForward(); else _skipBackward();
                        }, 
                        onHorizontalDragStart: (details) {
                          if (_isLocked || !ResponsiveUtils.isNative) return;
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
                          // Senior Plus: Sensibilidad de búsqueda (deslizar toda la pantalla = 2 min de búsqueda o duración total si es menor)
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
                        onVerticalDragStart: (details) {
                          if (_isLocked || !ResponsiveUtils.isNative) return;
                          final width = MediaQuery.sizeOf(context).width;
                          _isBrightnessGesture = details.globalPosition.dx < width / 2;
                          setState(() => _showControls = false);
                        },
                        onVerticalDragUpdate: (details) { 
                          if (_isLocked || !ResponsiveUtils.isNative || _isBrightnessGesture == null) return; 
                          
                          // Senior Plus: Sensibilidad adaptativa (80% de la altura = 100% de cambio)
                          final double screenHeight = MediaQuery.sizeOf(context).height;
                          final double sensitivity = screenHeight > 0 ? screenHeight * 0.8 : 400.0;
                          final delta = details.primaryDelta! / -sensitivity; 
                          
                          if (_isBrightnessGesture!) {
                            final double oldB = _brightness;
                            final newBrightness = (_brightness + delta).clamp(0.0, 1.0);
                            
                            if (newBrightness != oldB) {
                              setState(() { 
                                _brightness = newBrightness; 
                                _showBrightnessIndicator = true; 
                                _showVolumeIndicator = false; 
                               });
                               
                               // Senior Plus: Feedback Háptico en límites (0% y 100%)
                               if ((newBrightness == 0.0 || newBrightness == 1.0) && oldB != newBrightness) {
                                 HapticFeedback.selectionClick();
                               }
                               
                               // Throttling de brillo
                               if ((_brightness - _lastAppliedBrightness).abs() > 0.03 || _brightness == 1.0 || _brightness == 0.0) {
                                 _lastAppliedBrightness = _brightness;
                                 ScreenBrightnessController.setBrightness(_brightness);
                               }
                            }
                           } else {
                             // _lastManualVolumeTime = DateTime.now();
                             final double oldV = _volume;
                             double nextVol = _volume + delta;
                             
                             // Senior Plus: Snap magnético en 100% (límite de hardware)
                             if (oldV < 1.0 && nextVol > 1.0) nextVol = 1.0;
                             else if (oldV > 1.0 && nextVol < 1.0) nextVol = 1.0;
                             else if ((nextVol - 1.0).abs() < 0.02) nextVol = 1.0;
                             
                             final newVolume = nextVol.clamp(0.0, 1.0);
                             if (newVolume != oldV) {
                               setState(() { 
                                 _volume = newVolume;
                                 _showVolumeIndicator = true; 
                                 _showBrightnessIndicator = false; 
                               });

                               // Senior Plus: Feedback Háptico en límites y cambio de modo Boost
                               if ((newVolume == 0.0 || newVolume == 2.0 || (newVolume == 1.0 && oldV != 1.0)) && oldV != newVolume) {
                                 HapticFeedback.mediumImpact();
                               }

                               // Senior Plus: Throttling de volumen nativo (0.05 delta para fluidez)
                               if ((_volume - _lastAppliedVolume).abs() > 0.05 || _volume == 1.0 || _volume == 0.0) {
                                 _lastAppliedVolume = _volume;
                                 _applyVolume();
                               }
                             }
                           } 
                           _indicatorTimer?.cancel(); 
                           _indicatorTimer = Timer(const Duration(seconds: 2), () { 
                             if (mounted) setState(() { _showVolumeIndicator = false; _showBrightnessIndicator = false; }); 
                           }); 
                         }, 
                         onVerticalDragEnd: (_) {
                           // Asegurar que aplicamos el valor final exacto al terminar el gesto
                           if (_isBrightnessGesture == true) {
                             ScreenBrightnessController.setBrightness(_brightness);
                             _lastAppliedBrightness = _brightness;
                           } else if (_isBrightnessGesture == false) {
                             _applyVolume();
                             _lastAppliedVolume = _volume;
                           }
                           _isBrightnessGesture = null;
                           setState(() => _showControls = true);
                           _startHideTimer();
                         },
                         child: Container(color: Colors.transparent),
                       ),
                     ),
                   ),

                  // CAPA 2: Indicador Central (Play/Pause Feedback)
                  if (_showCenterIndicator)
                    IgnorePointer(
                      child: Center(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _showCenterIndicator ? 1.0 : 0.0,
                          child: Container(
                            width: 100, height: 100,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _centerIndicatorIcon,
                              color: Colors.white,
                              size: 60,
                              fill: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),

                   // CAPA 2: Los controles reales (Superpuestos)
                   IgnorePointer(
                     ignoring: !showAnyway, 
                     child: AnimatedOpacity(
                       opacity: showAnyway ? 1.0 : 0.0, 
                       duration: const Duration(milliseconds: 300), 
                       child: Stack(
                         fit: StackFit.expand,
                         children: [
                           if (!_isLocked && !(_autoplayCountdown >= 0 && _isAutoplayResume)) 
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
           // Senior UI Fix: El overlay se muestra durante TODA la carga (antes
           // se ocultaba con `!_showControls`, pero al abrir el stream los
           // controles ya son visibles y el usuario veía negro + 0:00).
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
           
           if (_showVolumeIndicator) IgnorePointer(child: _buildGestureIndicator(false, _volume)),
           if (_showBrightnessIndicator) IgnorePointer(child: _buildGestureIndicator(true, _brightness)),
           if (_showSeekIndicator) Positioned.fill(child: IgnorePointer(child: _buildSeekIndicator())),
           
           if (_showLeftSkip) _buildSkipVisual(false),
           if (_showRightSkip) _buildSkipVisual(true),
           
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
           
           // CAPA: Carrusel de Episodios (Estilo Netflix/Prime Video)
           if (_showEpisodesOverlay && !_isLocked && !(_autoplayCountdown >= 0 && _isAutoplayResume))
             Positioned.fill(
               child: Column(
                 children: [
                   // Senior Lazy-Close Shield: Si el usuario toca el área vacía superior, cerramos el carrusel
                   Expanded(
                     child: GestureDetector(
                       onTap: () => setState(() => _showEpisodesOverlay = false),
                       child: Container(color: Colors.transparent),
                     ),
                   ),
                   _EpisodesCarouselPanel(
                     title: widget.title ?? widget.contentId,
                     sourceUrl: widget.sourceUrl,
                     source: _currentSource,
                     currentEpisode: _activeEpisode,
                     season: widget.season ?? 1,
                     category: widget.category ?? 'anime',
                     onClose: () => setState(() => _showEpisodesOverlay = false),
                     onEpisodeSelected: (epNum, epUrl, epTitle) {
                       if (epNum.toString() == _activeEpisode) return;
                       
                       // Senior Navigation Fix: Reemplazar la URL actual para limpiar historial de "Mouse 4"
                       final String cleanUri = UrlUtils.buildPlayerUri(
                         title: widget.title ?? '',
                         contentId: widget.contentId,
                         episode: epNum.toString(),
                         source: _currentSource ?? '',
                         url: epUrl,
                         season: widget.season,
                         serverName: _currentServerName,
                         language: _currentLanguage,
                         category: widget.category,
                         totalEpisodes: widget.totalEpisodes,
                         posterUrl: widget.posterUrl,
                         bannerUrl: widget.bannerUrl,
                       );
                       context.replace(cleanUri);

                       setState(() {
                         _showEpisodesOverlay = false;
                         _currentEpisode = epNum.toString();
                         _currentSourceUrl = epUrl;
                         _hasInitialized = false;
                         _resumePosition = 0;
                         _isAutoplayResume = false;
                         _hasResetPosition = false;
                         _isStabilizing = true;
                       });
                     }
                   ),
                 ],
               ),
             ),

           // CAPA: Side Panel (Adaptive Unified UI)
           if (_activeOverlay != PlayerOverlay.none)
             Positioned.fill(
               child: Stack(
                 children: [
                   // Backdrop transparente para cerrar al tocar fuera
                   GestureDetector(
                     onTap: () {
                       setState(() => _activeOverlay = PlayerOverlay.none);
                       _startHideTimer();
                     },
                     behavior: HitTestBehavior.opaque,
                     child: Container(color: Colors.transparent),
                   ),
                   _PlayerSidePanel(
                     title: switch (_activeOverlay) {
                       PlayerOverlay.language => 'Fuentes Disponibles (${_getLanguageOptions().length})',
                       PlayerOverlay.server => 'Servidores (${_groupedSources.keys.length})',
                       PlayerOverlay.quality => 'Calidad de Video',
                       _ => '',
                     },
                     onClose: () {
                       setState(() => _activeOverlay = PlayerOverlay.none);
                       _startHideTimer();
                     },
                     child: switch (_activeOverlay) {
                       PlayerOverlay.language => _buildLanguageSelectorContent(isSidebar: true),
                       PlayerOverlay.server => _buildServerSelectorContent(isSidebar: true),
                       PlayerOverlay.quality => _buildQualitySelectorContent(isSidebar: true),
                       _ => const SizedBox.shrink(),
                     },
                   ),
                 ],
               ),
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
    );
  }

  Widget _buildControlsStack() {
    return Stack(children: [
        if (!_isLocked) ...[
          _buildMobileHeader(),
          _buildMobileCenterControls(),
          _buildMobileBottomBar(),
          _buildNextEpisodeOverlay(),
        ],
        if (_autoplayCountdown == -1 && _isMobileDevice) _buildLockToggle(),
      ]);
  }

  Widget _buildNextEpisodeOverlay() {
    if (_isTrailer) return const SizedBox.shrink();
    final isMobile = ResponsiveUtils.isMobile(context);
    final bool isCountdown = _autoplayCountdown >= 0;
    final String label = _isAutoplayResume ? 'Reanudar' : 'Siguiente episodio';

    // Senior Autoplay Shield: Verificar si existe un siguiente episodio para evitar el popup en el final
    final episodesAsync = ref.watch(episodesProvider(EpisodesParams(
      url: widget.sourceUrl,
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
    final double iconSize = _isMobileDevice ? 24 : 30;
    final double spacing = _isMobileDevice ? 8 : 12;

    return Positioned(top: 0, left: 0, right: 0, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            if (!hideBack) ...[
              IconButton(iconSize: iconSize, icon: const Icon(Symbols.arrow_back, color: Colors.white), onPressed: _handleBackNavigation),
              SizedBox(width: spacing),
            ],
            Expanded(
              child: Consumer(
                builder: (context, ref, _) {
                  final targetId = ref.watch(remoteControlProvider.select((s) => s.activeTargetDeviceId));
                  final devices = ref.watch(remoteControlProvider.select((s) => s.availableDevices));
                  final targetDevice = devices.firstWhereOrNull((d) => d.id == targetId);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayTitle,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (targetDevice != null)
                        Row(
                          children: [
                            const Icon(Icons.cast_connected_rounded, color: Color(0xFFEF7A1E), size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'Reproduciendo en ${targetDevice.name}',
                              style: const TextStyle(color: Color(0xFFEF7A1E), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        )
                      else if (_activeEpisode != null && !_isMovie)
                        Text(
                          _isSpecial ? 'Temporada 0' : 'Episodio $_activeEpisode',
                          style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                        )
                    ],
                  );
                },
              ),
            ),
            Builder(
              builder: (context) {
                final currentTrack = _allTracks.isNotEmpty
                    ? _allTracks[_selectedTrackIndex < _allTracks.length ? _selectedTrackIndex : 0]
                    : null;

                // Senior Fix: Usar estrictamente la etiqueta de idioma (quality) y no la de la fuente (label)
                final String label = currentTrack?.quality ?? _currentTrackQuality;

                Color color = const Color(0xFFEF7A1E);
                if (currentTrack?.color != null) {
                  color = Color(currentTrack!.color!);
                } else {
                  // Fallback visual por tipo de contenido
                  final type = trackQualityType(label);
                  if (type == 'SUB') color = Colors.blueAccent;
                }

                return ActiveSourceBadge(
                  serverName: _currentServerName ?? widget.serverName ?? widget.source,
                  label: label,
                  color: color,
                );
              },
            ),
            const SizedBox(width: 16),
            if (_isMobileDevice)
              _buildCastIcon(iconSize),
          ])));
  }

  Widget _buildPlayPauseButton({double? size}) {
    final double buttonSize = size ?? (_isMobileDevice ? 64 : 44); // Unificado a 44px
    final Stream<bool> playStream = _player?.stream.playing ?? const Stream.empty();
    final bool initialPlay = _player?.state.playing ?? false;

    return StreamBuilder<bool>(
      stream: playStream, 
      initialData: initialPlay, 
      builder: (context, snapshot) {
        final isPlaying = snapshot.data ?? initialPlay;
        
        IconData iconData = isPlaying ? Symbols.pause : Symbols.play_arrow;
        if (_isCompleted) iconData = Symbols.replay;

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
          backgroundColor: _isMobileDevice ? Colors.black.withOpacity(0.15) : null,
          iconSize: _isMobileDevice ? null : 30, // Unificado a 30px para Desktop
        );
      }
    );
  }

  Widget _buildCircularButton({
    required IconData icon, 
    required VoidCallback onTap, 
    required double size,
    bool fill = false,
    Color? backgroundColor,
    double? iconSize,
    Color? iconColor,
    double padding = 4, // Senior Fix: Padding configurable para el resaltado interno
  }) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.black.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      padding: EdgeInsets.all(padding),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size / 2 - padding),
          hoverColor: Colors.white.withOpacity(0.12),
          splashColor: Colors.white.withOpacity(0.08),
          child: Center(
            child: Icon(
              icon, 
              color: iconColor ?? Colors.white, 
              size: iconSize ?? (size * 0.55), 
              fill: fill ? 1.0 : 0.0
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCapsuleIconButton({
    required IconData icon, 
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
          hoverColor: Colors.white.withOpacity(0.12),
          splashColor: Colors.white.withOpacity(0.08),
          child: Center(
            child: Icon(icon, color: Colors.white, size: size, fill: fill ? 1.0 : 0.0),
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
            icon: Symbols.replay_10,
            onTap: _skipBackward,
            size: 30, // Unificado a 30px
            minWidth: 48,
          ),
          Container(width: 1, height: 16, color: Colors.white.withOpacity(0.05)),
          _buildCapsuleIconButton(
            icon: Symbols.forward_10,
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
    if (_isTrailer || (!hasPrevious && !hasNext)) return const SizedBox.shrink();
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
              icon: Symbols.skip_previous,
              onTap: () => _navigateToEpisode(false),
              size: 30, // Unificado a 30px
              fill: true,
              minWidth: 48,
            ),
          if (hasPrevious && hasNext) 
            Container(width: 1, height: 16, color: Colors.white.withOpacity(0.05)),
          if (hasNext)
            _buildCapsuleIconButton(
              icon: Symbols.skip_next,
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

  Widget _buildMobileCenterControls() {
    if (!_isMobileDevice) return const SizedBox.shrink();
    
    final double iconSize = _isMobileDevice ? 44 : 56;
    final double playSize = _isMobileDevice ? 64 : 90;
    // Senior UI: Espaciado aumentado para evitar toques accidentales en el botón central en móviles
    final double spacing = _isMobileDevice ? 56 : 40;

    return Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _buildCircularCenterAction(icon: Symbols.replay_10, size: iconSize, onTap: _skipBackward),
          SizedBox(width: spacing), 
          _buildPlayPauseButton(size: playSize),
          SizedBox(width: spacing),
          _buildCircularCenterAction(icon: Symbols.forward_10, size: iconSize, onTap: _skipForward),
        ]));
  }

  Widget _buildCircularCenterAction({required IconData icon, required double size, required VoidCallback onTap}) {
    return _buildCircularButton(
      icon: icon,
      onTap: onTap,
      size: size + 20, // Ajuste para el padding del contenedor circular
      fill: true,
      backgroundColor: _isMobileDevice ? Colors.black.withOpacity(0.15) : Colors.transparent,
      iconSize: size,
    );
  }

  Widget _buildMobileBottomBar() {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bool showLabels = screenWidth > 750;

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final double vPadding = _isMobileDevice && isLandscape ? 8 : 16;
    
    final double iconSize = _isMobileDevice ? 24 : 30;
    final double spacing = _isMobileDevice ? 8 : 12;
    final double playSize = _isMobileDevice ? 28 : 44; // Unificado a 44px

    // Senior Navigation Shield: Verificar si existen episodios anterior/siguiente
    final episodesAsync = ref.watch(episodesProvider(EpisodesParams(
      url: widget.sourceUrl,
      source: widget.source,
      title: widget.title,
      season: widget.season,
    )));

    final currentNum = int.tryParse(_activeEpisode ?? '') ?? 0;
    final bool hasPrevious = currentNum > 1;
    final bool hasNext = episodesAsync.when(
      data: (data) {
        if (data == null || data.episodes.isEmpty) {
          if (widget.totalEpisodes != null) return currentNum < widget.totalEpisodes!;
          return true; 
        }
        return data.episodes.any((e) => e.number > currentNum);
      },
      loading: () => true,
      error: (_, __) => true,
    );

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: vPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMobileTimeline(),
            SizedBox(height: isLandscape ? 4 : 12),
            // Senior: Usar SingleChildScrollView para evitar overflow en pantallas pequeñas/anchas
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: screenWidth - 48),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (_isMobileDevice)
                          IconButton(
                            iconSize: iconSize,
                            icon: Icon(
                              _useVideoFitCycle 
                                ? (_videoFit == BoxFit.contain ? Symbols.aspect_ratio : (_videoFit == BoxFit.fill ? Symbols.fit_screen : Symbols.fullscreen))
                                : (_isFullscreen ? Symbols.close_fullscreen : Symbols.open_in_full),
                              color: Colors.white,
                              weight: 300,
                            ),
                            onPressed: _toggleFullscreen,
                          )
                        else
                          _buildCircularButton(
                            icon: _useVideoFitCycle 
                                ? (_videoFit == BoxFit.contain ? Symbols.aspect_ratio : (_videoFit == BoxFit.fill ? Symbols.fit_screen : Symbols.fullscreen))
                                : (_isFullscreen ? Symbols.close_fullscreen : Symbols.open_in_full),
                            onTap: _toggleFullscreen,
                            size: 44,
                            iconSize: 30,
                            padding: 4, // Senior Fix: Padding 4px para consistencia con la familia de cápsulas
                          ),
                        // Controles desktop solo si no estamos en móvil (donde se usan gestos y centro)
                        if (!_isMobileDevice) ...[
                          const SizedBox(width: 12), // Espaciado de familia
                          _buildPlayPauseButton(size: playSize),
                          const SizedBox(width: 12),
                          _buildSeekCapsule(),
                          const SizedBox(width: 12),
                          _buildNavigationCapsule(hasPrevious, hasNext),
                          const SizedBox(width: 12),
                          _buildVolumePill(),
                          const SizedBox(width: 12),
                          _buildDurationCapsule(),
                        ],
                        // Rotación (Nativo y Web Móvil)
                        if (_isMobileDevice) ...[
                          SizedBox(width: spacing),
                          IconButton(
                            iconSize: iconSize,
                            icon: const Icon(Symbols.screen_rotation, color: Colors.white),
                            onPressed: () {
                              setState(() {
                                _isLandscapeOnly = !_isLandscapeOnly;
                                if (_isLandscapeOnly) {
                                  lockAppOrientation();
                                } else {
                                  unlockAppOrientation();
                                }
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                    if (!_isOpEd && _isMobileDevice && !_isTrailer)
                    Row(
                      children: [
                        if (hasPrevious)
                        _PlayerTextButton(
                          onPressed: () => _navigateToEpisode(false),
                          icon: Symbols.skip_previous,
                          label: showLabels ? 'Anterior' : '',
                        ),
                        if (hasPrevious && hasNext) const SizedBox(width: 12),
                        if (hasNext)
                        _PlayerTextButton(
                          onPressed: () => _navigateToEpisode(true),
                          icon: Symbols.skip_next,
                          label: showLabels ? 'Siguiente' : '',
                          isBold: true,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          iconSize: iconSize,
                          icon: const Icon(Symbols.speed, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              const speeds = [0.5, 0.7, 1.0, 1.2, 1.5, 1.7, 2.0];
                              int currentIndex = speeds.indexOf(_playbackSpeed);
                              if (currentIndex == -1) currentIndex = 2; // Default a 1.0 si hay un valor intermedio
                              
                              _playbackSpeed = speeds[(currentIndex + 1) % speeds.length];
                              _player?.setRate(_playbackSpeed);
                            });
                          },
                        ),
                        Text('${_playbackSpeed.toStringAsFixed(1)}x', style: TextStyle(color: Colors.white, fontSize: _isMobileDevice ? 13 : 14, fontWeight: FontWeight.w900)),
                        SizedBox(width: spacing),
                        if (!_isOpEd) ...[
                          IconButton(iconSize: iconSize, icon: const Icon(Symbols.dns, color: Colors.white), onPressed: _showServerSelector),
                          SizedBox(width: spacing),
                        ],
                        if (_hasQualityOptions) ...[
                          _PlayerTextButton(
                            onPressed: _showQualitySelector,
                            icon: Symbols.hd,
                            label: _selectedQuality == 'auto'
                                ? 'Calidad'
                                : (_qualityMenuOptions.firstWhereOrNull((o) => o['key'] == _selectedQuality)?['label'] as String? ?? 'Calidad'),
                            useBackground: true,
                          ),
                          SizedBox(width: spacing),
                        ],
                        if (!_isOpEd && !_isTrailer) ...[
                          IconButton(iconSize: iconSize, icon: const Icon(Symbols.subtitles, color: Colors.white), onPressed: _showLanguageSelector),
                          SizedBox(width: spacing),
                        ],
                        if (!_isOpEd && !_isMovie && !_isTrailer)
                        IconButton(
                          iconSize: iconSize, 
                          icon: const Icon(Symbols.video_library, color: Colors.white), 
                          onPressed: _showEpisodesCarousel
                        ),
                        SizedBox(width: spacing),
                        _buildCastIcon(iconSize),
                        if (!_isOpEd && !_isMovie && !_isTrailer) ...[
                          SizedBox(width: spacing),
                          _PlayerTextButton(onPressed: _skipOpEd, icon: Symbols.fast_forward, label: 'OP / ED', useBackground: true),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileTimeline() {
    final Stream<Duration> posStream = _player?.stream.position ?? const Stream.empty();
    final Duration initialPos = _player?.state.position ?? Duration.zero;
    final Stream<Duration> bufferStream = _player?.stream.buffer ?? const Stream.empty();
    final Duration initialBuffer = _player?.state.buffer ?? Duration.zero;

    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double sliderWidth = (screenWidth - 48).clamp(0.0, double.infinity);

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // ÁREA DE EVENTOS (Capa invisible para el ratón - Aislada de StreamBuilders)
            if (!_isMobileDevice)
              Positioned.fill(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onHover: (event) {
                    final duration = _player?.state.duration ?? Duration.zero;
                    if (duration.inMilliseconds <= 0) return;
                    
                    final double localX = event.localPosition.dx - 24; 
                    if (localX >= 0 && localX <= sliderWidth) {
                      final double ms = (localX / sliderWidth) * duration.inMilliseconds;
                      _hoverInfoNotifier.value = Offset(event.localPosition.dx, ms);
                    } else {
                      _hoverInfoNotifier.value = null;
                    }
                  },
                  onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { _hoverInfoNotifier.value = null; }),
                  child: Container(color: Colors.transparent),
                ),
              ),

            // CAPA DE DIBUJO (Solo barras y slider - Se actualizan con el video)
            StreamBuilder<Duration>(
              stream: posStream,
              initialData: initialPos,
              builder: (context, snapshot) {
                final position = snapshot.data ?? initialPos;
                final duration = _player?.state.duration ?? Duration.zero;
                final double maxMs = duration.inMilliseconds.toDouble().clamp(0.01, double.infinity);
                final double currentMs = position.inMilliseconds.toDouble().clamp(0.0, maxMs);

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    StreamBuilder<Duration>(
                      stream: bufferStream,
                      initialData: initialBuffer,
                      builder: (context, bufSnapshot) {
                        final bPos = bufSnapshot.data ?? initialBuffer;
                        final double bufferValue = (bPos.inMilliseconds / maxMs).clamp(0.0, 1.0);
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: SizedBox(
                            height: 2,
                            child: LinearProgressIndicator(
                              value: bufferValue,
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.25)),
                            ),
                          ),
                        );
                      },
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                        activeTrackColor: const Color(0xFFEF7A1E),
                        inactiveTrackColor: Colors.white10,
                        thumbColor: Colors.white,
                        overlayColor: const Color(0xFFEF7A1E).withOpacity(0.2),
                      ),
                      child: Slider(
                        value: currentMs,
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
                  ],
                );
              },
            ),

            // CAPA DE TIEMPO (Independiente de los StreamBuilders y del Layout del video)
            if (!_isMobileDevice)
              IgnorePointer(
                child: ValueListenableBuilder<Offset?>(
                  valueListenable: _hoverInfoNotifier,
                  builder: (context, info, _) {
                    if (info == null) return const SizedBox.shrink();
                    return Positioned(
                      left: 0,
                      right: 0,
                      bottom: 40,
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Transform.translate(
                          offset: Offset(info.dx - 40, 0),
                          child: RepaintBoundary(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Text(
                                _formatDuration(Duration(milliseconds: info.dy.toInt())),
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
        
        // Tiempos Current/Duration (Ocultos en Desktop porque se usa DurationCapsule)
        if (_isMobileDevice)
        StreamBuilder<Duration>(
          stream: posStream,
          initialData: initialPos,
          builder: (context, snapshot) {
            final position = snapshot.data ?? initialPos;
            final duration = _player?.state.duration ?? Duration.zero;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_formatDuration(position), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  Text(_formatDuration(duration), style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold))
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLockToggle() {
    return Positioned(top: 60, right: 16, child: IconButton(icon: Icon(_isLocked ? Icons.lock : Icons.lock_open, color: Colors.white), onPressed: () { setState(() { _isLocked = !_isLocked; if (_isLocked) _showControls = false; else { _showControls = true; _startHideTimer(); } }); }));
  }
}

class _PlayerTextButton extends StatefulWidget {
  final VoidCallback onPressed; final IconData icon; final String label; final bool isBold; final bool useBackground;
  const _PlayerTextButton({required this.onPressed, required this.icon, required this.label, this.isBold = false, this.useBackground = false});
  @override State<_PlayerTextButton> createState() => _PlayerTextButtonState();
}

class _PlayerTextButtonState extends State<_PlayerTextButton> {
  bool _isHovered = false;
  @override Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    return MouseRegion(
        onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _isHovered = true); }),
        onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _isHovered = false); }),
        child: AnimatedScale(
            scale: _isHovered ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: InkWell(
                onTap: widget.onPressed,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? (widget.label.isEmpty ? 6 : 10) : 24, vertical: isMobile ? 6 : 12),
                    decoration: BoxDecoration(
                        color: widget.useBackground ? (_isHovered ? Colors.white24 : Colors.white10) : (_isHovered ? Colors.white10 : Colors.transparent),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(widget.icon, color: Colors.white, size: isMobile ? 20 : 30),
                      if (widget.label.isNotEmpty) ...[
                        SizedBox(width: isMobile ? 6 : 8),
                        Text(widget.label, style: TextStyle(color: Colors.white, fontSize: isMobile ? 12 : 16, fontWeight: widget.isBold ? FontWeight.w900 : FontWeight.bold)),
                      ]
                    ])))));
  }
}

class _EpisodesCarouselPanel extends ConsumerStatefulWidget {
  final String title;
  final String sourceUrl;
  final String source;
  final String? currentEpisode;
  final int season;
  final String category;
  final VoidCallback onClose;
  final Function(int, String, String?) onEpisodeSelected;

  const _EpisodesCarouselPanel({
    required this.title,
    required this.sourceUrl,
    required this.source,
    required this.currentEpisode,
    required this.season,
    required this.category,
    required this.onClose,
    required this.onEpisodeSelected,
  });

  @override
  ConsumerState<_EpisodesCarouselPanel> createState() => _EpisodesCarouselPanelState();
}

class _EpisodesCarouselPanelState extends ConsumerState<_EpisodesCarouselPanel> {
  final ScrollController _scrollController = ScrollController();
  bool _showLeftArrow = false;
  bool _showRightArrow = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateArrows);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateArrows());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateArrows);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateArrows() {
    if (!mounted || !_scrollController.hasClients) return;
    final bool left = _scrollController.offset > 10;
    final bool right = _scrollController.offset < _scrollController.position.maxScrollExtent - 10;
    if (left != _showLeftArrow || right != _showRightArrow) {
      setState(() {
        _showLeftArrow = left;
        _showRightArrow = right;
      });
    }
  }

  void _scroll(bool right) {
    final double offset = right ? 800 : -800;
    _scrollController.animateTo(
      (_scrollController.offset + offset).clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    final episodesAsync = ref.watch(episodesProvider(EpisodesParams(
      url: widget.sourceUrl,
      source: widget.source,
      title: widget.title,
      season: widget.season,
    )));

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        bottom: isMobile ? 0 : 12, // Senior Fix: Eliminado padding inferior en móvil para máximo aprovechamiento
        top: isMobile ? (isLandscape ? 5 : 60) : 40 
      ), 
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.98),
            Colors.black.withOpacity(0.85),
            Colors.black.withOpacity(0.4),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 0.7, 1.0],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 48),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EPISODIOS',
                      style: TextStyle(
                        color: const Color(0xFFEF7A1E), 
                        fontSize: isMobile ? (isLandscape ? 11 : 13) : 15, 
                        fontWeight: FontWeight.w900, 
                        letterSpacing: 2
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'TEMPORADA ${widget.season}',
                      style: TextStyle(
                        color: Colors.white, 
                        fontSize: isMobile ? (isLandscape ? 16 : 18) : 26, 
                        fontWeight: FontWeight.w900
                      ),
                    ),
                  ],
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Symbols.close, color: Colors.white, size: isMobile ? (isLandscape ? 28 : 36) : 48),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          
          SizedBox(height: isMobile ? 2 : 16), // Senior Fix: Reducido al mínimo el espacio bajo el título
          
          Stack(
            children: [
              SizedBox(
                height: isMobile ? (isLandscape ? 250 : 280) : 440, // Senior Fix: Ajustado a 250px en landscape para eliminar aire inferior
                child: episodesAsync.when(
                  data: (data) {
                    if (data == null || data.episodes.isEmpty) {
                      return const Center(child: Text('No hay episodios disponibles', style: TextStyle(color: Colors.white54)));
                    }
                    return ListView.builder(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      padding: EdgeInsets.only(
                        left: isMobile ? 24 : 48, 
                        right: isMobile ? 24 : 48,
                        top: isLandscape ? 5 : 10, // Senior Fix: Reducido espacio superior en horizontal
                        bottom: 0,
                      ),
                      itemCount: data.episodes.length,
                      itemBuilder: (context, index) {
                        final ep = data.episodes[index];
                        final isCurrent = ep.number.toString() == widget.currentEpisode;
                        return _EpisodeCarouselItem(
                          key: ValueKey('ep_${ep.number}'),
                          number: ep.number,
                          title: ep.title,
                          thumbnail: ep.thumbnail,
                          description: ep.description,
                          isCurrent: isCurrent,
                          onTap: () => widget.onEpisodeSelected(ep.number, ep.url, ep.title),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFEF7A1E))),
                  error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.redAccent))),
                ),
              ),

              // Senior: Flechas de Navegación Proactivas
              if (!isMobile) ...[
                Positioned(
                  left: 0, 
                  top: 0, 
                  bottom: 180, // Senior Fix: Ajustado al área de la imagen
                  child: AnimatedOpacity(
                    opacity: _showLeftArrow ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: IgnorePointer(
                      ignoring: !_showLeftArrow,
                      child: Center(
                        child: _CarouselArrow(isRight: false, onTap: () => _scroll(false)),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0, 
                  top: 0, 
                  bottom: 180, // Senior Fix: Ajustado al área de la imagen
                  child: AnimatedOpacity(
                    opacity: _showRightArrow ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: IgnorePointer(
                      ignoring: !_showRightArrow,
                      child: Center(
                        child: _CarouselArrow(isRight: true, onTap: () => _scroll(true)),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CarouselArrow extends StatefulWidget {
  final bool isRight;
  final VoidCallback onTap;

  const _CarouselArrow({required this.isRight, required this.onTap});

  @override
  State<_CarouselArrow> createState() => _CarouselArrowState();
}

class _CarouselArrowState extends State<_CarouselArrow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _isHovered = true); }),
      onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _isHovered = false); }),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.2 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: Container(
            width: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: widget.isRight ? Alignment.centerLeft : Alignment.centerRight,
                end: widget.isRight ? Alignment.centerRight : Alignment.centerLeft,
                colors: [
                  Colors.black.withOpacity(0.0),
                  Colors.black.withOpacity(0.8),
                ],
              ),
            ),
            child: Center(
              child: Icon(
                widget.isRight ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EpisodeCarouselItem extends StatefulWidget {
  final int number;
  final String? title;
  final String? thumbnail;
  final String? description;
  final bool isCurrent;
  final VoidCallback onTap;

  const _EpisodeCarouselItem({
    super.key,
    required this.number,
    this.title,
    this.thumbnail,
    this.description,
    required this.isCurrent,
    required this.onTap,
  });

  @override
  State<_EpisodeCarouselItem> createState() => _EpisodeCarouselItemState();
}

class _EpisodeCarouselItemState extends State<_EpisodeCarouselItem> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    
    // Senior UI Adaptive logic:
    final double cardWidth = isMobile ? 240.0 : 440.0;
    final bool isActive = _isHovered || _isFocused;
    
    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: MouseRegion(
        onEnter: (_) { if (mounted) setState(() => _isHovered = true); },
        onExit: (_) { if (mounted) setState(() => _isHovered = false); },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: isActive ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: Container(
              width: cardWidth,
              margin: EdgeInsets.only(right: isMobile ? 20 : 32), 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(isMobile ? 10 : 16),
                        border: Border.all(
                          color: widget.isCurrent ? const Color(0xFFEF7A1E) : (isActive ? Colors.white : Colors.white.withOpacity(0.1)), 
                          width: widget.isCurrent ? (isMobile ? 3 : 5) : (isActive ? 3 : 1)
                        ),
                        boxShadow: (widget.isCurrent || isActive) ? [
                          BoxShadow(
                            color: (widget.isCurrent ? const Color(0xFFEF7A1E) : Colors.white).withOpacity(0.4), 
                            blurRadius: isMobile ? 15 : 30, 
                            spreadRadius: 1
                          )
                        ] : [],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(isMobile ? 8 : 13),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (widget.thumbnail != null && widget.thumbnail!.isNotEmpty)
                              CachedNetworkImage(
                                imageUrl: ApiEndpoints.proxyImage(widget.thumbnail!),
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(color: Colors.white.withOpacity(0.05)),
                                errorWidget: (context, url, error) => Container(color: Colors.black26),
                              )
                            else
                              Container(color: Colors.white.withOpacity(0.05), child: Icon(Icons.movie_outlined, color: Colors.white10, size: isMobile ? 48 : 72)),
                            
                            if (widget.isCurrent)
                              Positioned.fill(
                                child: Container(
                                  color: const Color(0xFFEF7A1E).withOpacity(0.15), // Senior: Tinte sutil en lugar de icono play
                                ),
                              ),
                            
                            // Badge de EP (Esquina inferior derecha)
                            Positioned(
                              bottom: isMobile ? 8 : 12, 
                              right: isMobile ? 8 : 12,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 12, vertical: isMobile ? 2 : 5),
                                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(isMobile ? 4 : 8)),
                                child: Text('EP ${widget.number}', style: TextStyle(color: Colors.white, fontSize: isMobile ? 10 : 14, fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12), // Senior Fix: Más compacto
                  // Información del episodio
                  Builder(
                    builder: (context) {
                      final String rawTitle = widget.title ?? "Episodio ${widget.number}";
                      // Senior Clean Logic: Evitamos duplicados si el título ya trae el número o la palabra Episodio/EP
                      final bool startsWithNumber = rawTitle.startsWith('${widget.number}') || 
                                                  rawTitle.startsWith('0${widget.number}') ||
                                                  rawTitle.toLowerCase().startsWith('episodio') ||
                                                  rawTitle.toLowerCase().startsWith('ep ') ||
                                                  rawTitle.contains('${widget.number}ª');
                      
                      final String cleanTitle = startsWithNumber ? rawTitle : '${widget.number} . $rawTitle';

                      return Text(
                        cleanTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.isCurrent || isActive ? Colors.white : Colors.white.withOpacity(0.9),
                          fontSize: isMobile ? 14 : 22, 
                          fontWeight: widget.isCurrent || isActive ? FontWeight.w900 : FontWeight.bold,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.description ?? 'Sin descripción disponible para este episodio.',
                    maxLines: isMobile ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55), 
                      fontSize: isMobile ? 11 : 17, 
                      height: 1.4,
                      fontWeight: FontWeight.w500
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerSidePanel extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback onClose;
  final double width;

  const _PlayerSidePanel({
    required this.title,
    required this.child,
    required this.onClose,
    this.width = 450,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    // Senior UI Adaptive logic:
    // En móvil landscape o tablet, el ancho es 380. En desktop 450.
    final double panelWidth = isMobile ? (isLandscape ? 380 : MediaQuery.of(context).size.width * 0.85) : width;
    final double padding = isMobile ? 12 : 24;

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Material(
          color: const Color(0xFF16161C),
          borderRadius: BorderRadius.circular(isMobile ? 16 : 24),
          elevation: 10,
          shadowColor: Colors.black.withOpacity(0.6),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: panelWidth,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isMobile ? 16 : 24),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Senior: Permitir que el panel sea más corto si hay pocos items
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(isMobile ? 20 : 32, isMobile ? 20 : 32, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: isMobile ? 12 : 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                      IconButton(
                        onPressed: onClose,
                        icon: Icon(Icons.close_rounded, color: Colors.white54, size: isMobile ? 20 : 24),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),
                Flexible(child: child),
              ],
            ),
          ),
        ),
      ),
    );
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
  final IconData icon;
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
            Icon(icon, color: Colors.white, size: 20),
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
