import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auris_core.dart';

class MiniPlayerBar extends ConsumerStatefulWidget {
  final VoidCallback onExpand;
  /// Entrada manual a PiP nativo (solo Movil Android; null = sin botón).
  final VoidCallback? onEnterPip;
  const MiniPlayerBar({super.key, required this.onExpand, this.onEnterPip});

  @override
  ConsumerState<MiniPlayerBar> createState() => _MiniPlayerBarState();
}

class _MiniPlayerBarState extends ConsumerState<MiniPlayerBar> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Offset _position = Offset.zero;
  /// La posición inicial se calcula en post-frame: hasta entonces no se
  /// pinta nada (evita 1 frame en (0,0) arriba-izquierda al volver de PiP).
  bool _positionReady = false;
  /// Suscripciones propias del mini (fin de video + umbral de preload).
  /// El motor es compartido con el fullscreen: solo actúan en modo mini.
  StreamSubscription<Duration>? _miniPosSub;
  StreamSubscription<bool>? _miniCompletedSub;
  Player? _listenedPlayer;
  String? _preloadedForKey;
  bool _showReplay = false;
  String? _lastMiniEpisode;
  String? _episodesSyncKey;
  bool _isDragging = false;
  bool _isHovered = false; 
  bool _isExpandedList = false; 
  /// Posición/ancho previos a desmontar (ida y vuelta a PiP nativo desmonta
  /// todo el árbol): estáticos para sobrevivir al State. Se restauran en
  /// initState; un inicio fresco usa la esquina por defecto.
  static Offset? _savedPosition;
  static double? _savedUserWidth;
  late AnimationController _snapController;
  late Animation<Offset> _snapAnimation;
  final FocusNode _keyboardFocusNode = FocusNode(); 
  // Controles tap-to-toggle (estilo YouTube mini): ocultos por defecto tras
  // 3s, tap en el video los muestra. El hover en desktop también los revela.
  bool _showControls = true;
  Timer? _controlsHideTimer;
  
  // Senior Adaptive Design System - breakpoints continuos (no binario desktop/mobile)
  double get _edgeMargin {
    final w = MediaQuery.of(context).size.width;
    if (w >= 1200) return 16.0;
    if (w >= 800) return 12.0;
    return 10.0;
  }
  double get _bottomOffset {
    final w = MediaQuery.of(context).size.width;
    if (w >= 1200) return 16.0;
    if (w >= 600) return 24.0;
    return 70.0; // móvil deja espacio para bottom nav
  }
  double get _topOffset => 16.0;

  /// Ancho fijado por pellizco (null = breakpoint por defecto). Como el PiP
  /// nativo: se conserva entre movimientos y solo lo acotan los bounds.
  double? _userWidth;
  double _scaleBaseWidth = 0.0;
  /// Posición previa a expandir la lista (para volver al contraer).
  Offset? _preExpandPosition;

  double get _breakpointWidth {
    final w = MediaQuery.of(context).size.width;
    if (w >= 1200) return 400.0; // desktop
    if (w >= 900) return 320.0; // compact desktop
    if (w >= 600) return 280.0; // tablet
    return 210.0; // móvil
  }

  double get _minPlayerWidth => 160.0;
  /// Controles por tipo de entrada, NO por ancho: la tablet (280px+) caía en
  /// el overlay desktop (hover) sin hover táctil → sin controles y tap =
  /// play/pausa. Táctil (Android/iOS) siempre lleva controles móviles.
  bool get _useMobileControls {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return true;
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return false;
    }
  }  double get _maxPlayerWidth {
    final w = MediaQuery.of(context).size.width;
    return (w - _edgeMargin * 2).clamp(160.0, 480.0);
  }

  double get _playerWidth {
    final base = _userWidth ?? _breakpointWidth;
    return base.clamp(_minPlayerWidth, _maxPlayerWidth);
  }
  double get _listHeight => _isExpandedList && _playerWidth >= 280 ? 300.0 : 0.0; 
  double get _totalHeight => _totalHeightFor(_playerWidth);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    
    // Posición inicial: la previa al desmontaje (vuelta de PiP) o abajo a
    // la derecha por defecto. Se acota a las métricas actuales.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.of(context).size;
      if (size.width > 100 && size.height > 100) {
        if (_savedUserWidth != null) {
          _userWidth = _savedUserWidth!.clamp(_minPlayerWidth, _maxPlayerWidth);
        }
        final Offset initial = _savedPosition ?? Offset(
          size.width - _playerWidth - _edgeMargin,
          size.height - _totalHeight - _bottomOffset,
        );
        setState(() {
          _position = _clampPosition(initial, _playerWidth);
          _positionReady = true;
        });
      }
    });
    // Auto-ocultar controles a los 3s (tap en video los revela).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _restartControlsTimer();
    });
  }

  @override
  void didChangeMetrics() {
    // Senior: al redimensionar/rotar/volver de PiP, RE-ACOTAR sin re-anclar:
    // la posición del usuario se respeta (el anclaje al borde es solo al
    // soltar un arrastre). Re-anclar aquí movía el mini a una esquina al
    // volver de PiP.
    if (!mounted || _isDragging) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_userWidth != null) {
        _userWidth = _userWidth!.clamp(_minPlayerWidth, _maxPlayerWidth);
      }
      setState(() {
        _position = _clampPosition(_position, _playerWidth);
      });
    });
  }

  @override
  void dispose() {
    _miniPosSub?.cancel();
    _miniCompletedSub?.cancel();
    // Guardar el punto visual real (si hay glide en curso, el valor animado).
    _savedPosition =
        _snapController.isAnimating ? _snapAnimation.value : _position;
    _savedUserWidth = _userWidth;
    WidgetsBinding.instance.removeObserver(this);
    _controlsHideTimer?.cancel();
    _snapController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _revealControls() {
    if (!mounted) return;
    setState(() => _showControls = true);
    _restartControlsTimer();
  }

  void _toggleControls() {
    if (!mounted) return;
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _restartControlsTimer();
    } else {
      _controlsHideTimer?.cancel();
    }
  }

  void _restartControlsTimer() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showControls = false);
    });
  }

  /// Los botones viven anidados sobre la capa de tap-toggle: ambos disparan.
  /// Re-mostrar en post-frame gana determinísticamente al toggle.
  void _keepControlsVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _revealControls();
    });
  }

  /// Acota una posición a la pantalla con el ancho dado.
  Offset _clampPosition(Offset p, double w) {
    final size = MediaQuery.of(context).size;
    final h = _totalHeightFor(w);
    return Offset(
      p.dx.clamp(_edgeMargin, (size.width - w - _edgeMargin).clamp(_edgeMargin, size.width)),
      p.dy.clamp(_topOffset, (size.height - h - _bottomOffset).clamp(_topOffset, size.height)),
    );
  }

  double _totalHeightFor(double w, [bool? expanded]) {
    final showList = expanded ?? _isExpandedList;
    final videoH = w * (9 / 16);
    final metaH = w >= 280 ? 62.0 : 0.0;
    final listH = (showList && w >= 280) ? 300.0 : 0.0;
    return videoH + metaH + listH + (w >= 280 ? 4.0 : 0.0);
  }

  /// Asentamiento estilo PiP nativo: proyección por velocidad (fricción) y
  /// anclaje al borde lateral más cercano manteniendo la Y (no a esquinas).
  /// Un solo tween easeOut ~280ms: arranque con inercia, llegada suave.
  void _settle(Offset velocity, {bool animate = true}) {
    final size = MediaQuery.of(context).size;
    final w = _playerWidth;
    Offset start = _clampPosition(_position, w);

    // Proyección con fricción solo si hay impulso real.
    const double kFlingThreshold = 350.0;
    const double kFrictionDistance = 0.22;
    Offset projected = start;
    if (velocity.distance > kFlingThreshold) {
      projected = _clampPosition(
        start + Offset(velocity.dx * kFrictionDistance, velocity.dy * kFrictionDistance),
        w,
      );
    }

    // Borde lateral más cercano por centro; Y clampada donde quedó.
    final double centerX = projected.dx + w / 2;
    final double targetX = centerX > size.width / 2
        ? size.width - w - _edgeMargin
        : _edgeMargin;
    final target = _clampPosition(Offset(targetX, projected.dy), w);

    _snapController.stop();
    if (!animate) {
      setState(() => _position = target);
      return;
    }
    _glideTo(target);
  }

  /// Deslizamiento animado a un punto arbitrario (expandir/contraer lista).
  void _glideTo(Offset target) {
    _snapController.stop();
    _snapAnimation = _snapController.drive(
      Tween<Offset>(begin: _position, end: target)
          .chain(CurveTween(curve: Curves.easeOutCubic)),
    );
    _snapController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _position = target;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activePlayerProvider);
    if (state.uiState != PlayerUIState.mini || state.currentItem == null) {
      return const SizedBox.shrink();
    }
    // Posición aún no calculada (primer frame tras montar, p. ej. vuelta de
    // PiP): no pintar a (0,0), esperar al post-frame con la posición real.
    if (!_positionReady) return const SizedBox.shrink();

    _listenMiniPlayer(state.player);
    // Cambio de episodio: resetear replay/preload (sincrono en build, sin
    // setState: el build en curso ya lee los valores frescos).
    if (state.episode != _lastMiniEpisode) {
      _lastMiniEpisode = state.episode;
      _showReplay = false;
      _preloadedForKey = null;
    }
    // Convergencia de sesión: si el fullscreen no sincronizó la lista (deep
    // link, fetch tardío), traerla una vez para que el auto-avance, el
    // preload y los títulos la vean. Con key anti re-sync.
    _syncMiniEpisodes(state);

    final item = state.currentItem!;
    final bool isDesktop = ResponsiveUtils.isDesktop(context);

    return AnimatedBuilder(
      animation: _snapController,
      builder: (context, child) {
        final currentPos = _snapController.isAnimating ? _snapAnimation.value : _position;
        
        return Positioned(
          left: currentPos.dx,
          top: currentPos.dy,
          child: child!,
        );
      },
      child: MouseRegion(
        onEnter: (_) { if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _isHovered = true); }); },
        onExit: (_) { if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _isHovered = false); }); },
        child: GestureDetector(
          // Arrastre 1:1 + pellizco para redimensionar (estilo PiP nativo).
          // onScale cubre ambos (un dedo = mover, dos = mover+escalar).
          onScaleStart: (details) {
            _snapController.stop();
            _scaleBaseWidth = _playerWidth;
            // Si el usuario lo mueve a mano, esa es su nueva casa: no
            // restaurar la previa al contraer.
            _preExpandPosition = null;
            setState(() => _isDragging = true);
          },
          onScaleUpdate: (details) {
            setState(() {
              _position += details.focalPointDelta;
              if ((details.scale - 1.0).abs() > 0.01) {
                _userWidth = (_scaleBaseWidth * details.scale)
                    .clamp(_minPlayerWidth, _maxPlayerWidth);
              }
              _position = _clampPosition(_position, _playerWidth);
            });
          },
          onScaleEnd: (details) {
            setState(() => _isDragging = false);
            _settle(details.velocity.pixelsPerSecond);
          },
          child: KeyboardListener(
            focusNode: _keyboardFocusNode,
            autofocus: true,
            onKeyEvent: (event) {
              if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyI) {
                widget.onExpand();
              }
            },
            child: Material( 
              type: MaterialType.transparency,
              child: Container(
                width: _playerWidth,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F0F),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(_isDragging || _isHovered ? 0.6 : 0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. VIDEO AREA (16:9)
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        children: [
                          // CAPA 0: VIDEO / POSTER
                          Positioned.fill(
                            child: state.controller != null
                                ? Video(
                                    key: state.videoKey, 
                                    controller: state.controller!,
                                    fill: Colors.black,
                                    controls: NoVideoControls,
                                  )
                                : Image.network(item.posterUrl, fit: BoxFit.cover),
                          ),

                          // CAPA TAP-TOGGLE (solo controles móviles): en desktop el
                          // propio overlay raíz ya alterna (dos toggles apilados
                          // se cancelarían). Tap en botón dispara ambos y el
                          // botón re-muestra en post-frame.
                          if (_useMobileControls)
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _toggleControls,
                              ),
                            ),

                          // Adaptive overlay: desktop = SOLO hover, móvil/táctil =
                          // tap-toggle con auto-hide 3s (independiente del ancho).
                          if (!_useMobileControls)
                            Positioned.fill(
                              child: AnimatedOpacity(
                                opacity: _isHovered ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 200),
                                child: _buildDesktopOverlay(state),
                              ),
                            )
                          else
                            Positioned.fill(child: _buildMobileOverlay(state)),

                          // Fin del video: Repetir + Cerrar + Fullscreen (si no hay
                          // siguiente, el auto-avance ya cambió de episodio).
                          // Botones explícitos (sin tap-en-cualquiera: un tap
                          // en X no debe disparar también el replay).
                          if (_showReplay)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black54,
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: AurisIcon(AurisIcons.close,
                                            color: Colors.white, size: 28),
                                        onPressed: () => ref
                                            .read(activePlayerProvider.notifier)
                                            .stop(),
                                      ),
                                      const SizedBox(width: 16),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: AurisIcon(
                                                AurisIcons.restart,
                                                color: Color(0xFFEF7A1E),
                                                size: 44),
                                            onPressed: _replayMini,
                                          ),
                                          const Text('Repetir',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      const SizedBox(width: 16),
                                      IconButton(
                                        icon: AurisIcon(
                                            AurisIcons.grid,
                                            color: Colors.white,
                                            size: 28),
                                        onPressed: widget.onExpand,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Progress siempre visible (slim en móvil), metadata/lista solo si hay espacio
                    _buildProgressBar(state),
                    if (_playerWidth >= 280) _buildMetadataArea(item, state),
                    // Acordeón: misma curva/duración que el deslizamiento de
                    // posición (280ms easeOutCubic) para moverse como una pieza.
                    if (_playerWidth >= 280)
                      ClipRect(
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: _isExpandedList
                              ? _buildEpisodesList(state)
                              : const SizedBox.shrink(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopOverlay(ActivePlayerState state) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Tap en el overlay alterna Play/Pause (los controles solo viven
        // mientras el mouse está encima).
        onTap: () {
          final player = state.player;
          if (player != null) {
            if (player.state.playing) player.pause();
            else player.play();
          }
        },
        child: IgnorePointer(
          // Ocultos = no clicables (solo visibles en hover).
          ignoring: !_isHovered,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.2),
                  Colors.transparent,
                  Colors.black.withOpacity(0.4),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: Stack(
              children: [
                // 1. Expandir - Top Left
                Positioned(
                  top: 10, left: 10,
                  child: GestureDetector(
                    onTap: widget.onExpand,
                    child: AurisIcon(AurisIcons.toPip, color: Colors.white, size: 24),
                  ),
                ),
                
                // 2. Cerrar (X) - Top Right
                Positioned(
                  top: 10, right: 10,
                  child: GestureDetector(
                    onTap: () => ref.read(activePlayerProvider.notifier).stop(),
                    child: AurisIcon(AurisIcons.close, color: Colors.white, size: 26),
                  ),
                ),
                
                // 3. Play/Pause Icon - Center (solo indicador; el tap del
                // overlay alterna play/pausa)
                IgnorePointer(
                  child: Center(
                    child: StreamBuilder<bool>(
                      stream: state.player?.stream.playing,
                      initialData: state.player?.state.playing ?? false,
                      builder: (context, snapshot) {
                        final playing = snapshot.data ?? false;
                        return AurisIcon(
                          playing ? AurisIcons.pause : AurisIcons.play,
                          color: Colors.white,
                          size: 64,
                        );
                      },
                    ),
                  ),
                ),
                
                // 4. Time - Bottom Left
                Positioned(
                  bottom: 12, left: 14,
                  child: _buildTimeDisplay(state),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileOverlay(ActivePlayerState state) {
    // El tap-toggle vive en la capa de video (debajo); aquí solo fade +
    // bloqueo de toques cuando están ocultos.
    return AnimatedOpacity(
      opacity: _showControls ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !_showControls,
        child: Stack(
          children: [
            Positioned(
              top: 4, right: 4,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: AurisIcon(AurisIcons.close, color: Colors.white, size: 20),
                onPressed: () => ref.read(activePlayerProvider.notifier).stop(),
              ),
            ),
            Positioned(
              top: 4, left: 4,
              child: StreamBuilder<bool>(
                stream: state.player?.stream.playing,
                initialData: state.player?.state.playing ?? false,
                builder: (context, snapshot) {
                  final playing = snapshot.data ?? false;
                  return IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: AurisIcon(
                      playing ? AurisIcons.pause : AurisIcons.play,
                      color: Colors.white.withOpacity(0.9),
                      size: 20,
                    ),
                    onPressed: () {
                      playing ? state.player?.pause() : state.player?.play();
                      _keepControlsVisible();
                    },
                  );
                },
              ),
            ),
            // Reabrir fullscreen (no existía en el overlay móvil).
            Positioned(
              bottom: 4, right: 4,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: AurisIcon(AurisIcons.grid, color: Colors.white, size: 20),
                onPressed: () {
                  widget.onExpand();
                  _keepControlsVisible();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(ActivePlayerState state) {
    return StreamBuilder<Duration>(
      stream: state.player?.stream.position,
      builder: (context, snapshot) {
        final pos = snapshot.data?.inMilliseconds ?? state.player?.state.position.inMilliseconds ?? 0;
        final dur = state.player?.state.duration.inMilliseconds ?? 1;
        final progress = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
        
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null || dur <= 0) return;
            final tapX = details.localPosition.dx;
            final seekProgress = (tapX / box.size.width).clamp(0.0, 1.0);
            ref.read(activePlayerProvider.notifier).seekTo(seekProgress);
          },
          onHorizontalDragUpdate: (details) {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null || dur <= 0) return;
            final tapX = details.localPosition.dx.clamp(0.0, box.size.width);
            final seekProgress = (tapX / box.size.width).clamp(0.0, 1.0);
            ref.read(activePlayerProvider.notifier).seekTo(seekProgress);
          },
          child: Container(
            height: _isHovered ? 6 : 4,
            width: double.infinity,
            color: Colors.white.withOpacity(0.15),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(color: const Color(0xFFEF7A1E)),
                ),
                // Thumb visible on hover or drag
                if (_isHovered || _isDragging)
                  Positioned(
                    left: (progress * _playerWidth) - 6,
                    top: -4,
                    child: Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF7A1E),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 4)],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetadataArea(MediaItem item, ActivePlayerState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      width: double.infinity,
      color: const Color(0xFF0F0F0F),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, decoration: TextDecoration.none),
                ),
                const SizedBox(height: 2),
                Text(
                  state.source ?? 'AurisTV',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w500, decoration: TextDecoration.none),
                ),
              ],
            ),
          ),
          if (state.episode != 'OP' && state.episode != 'ED')
            Container(
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), shape: BoxShape.circle),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    // Expandir: recordar posición y subir SOLO lo necesario
                    // para que quepa la lista (no a un punto fijo).
                    // Contraer: volver a la posición previa.
                    final size = MediaQuery.of(context).size;
                    if (!_isExpandedList) {
                      _preExpandPosition = _position;
                      final expandedH = _totalHeightFor(_playerWidth, true);
                      final overflow = (_position.dy + expandedH) -
                          (size.height - _bottomOffset);
                      setState(() => _isExpandedList = true);
                      if (overflow > 0) {
                        final target = _clampPosition(
                          Offset(_position.dx, _position.dy - overflow),
                          _playerWidth,
                        );
                        _glideTo(target);
                      }
                    } else {
                      final back = _preExpandPosition;
                      _preExpandPosition = null;
                      setState(() => _isExpandedList = false);
                      if (back != null) {
                        _glideTo(_clampPosition(back, _playerWidth));
                      }
                    }
                  },
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: AurisIcon(_isExpandedList ? AurisIcons.chevronUp : AurisIcons.chevronDown, color: Colors.white.withOpacity(0.9), size: 24),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEpisodesList(ActivePlayerState state) {
    // Senior Streaming: Prioriza datos ya compartidos del player (sin re-fetch).
    // Si availableEpisodes ya viene del player via updateSession, lo reutiliza directo (cache HIT).
    if (state.availableEpisodes.isNotEmpty) {
      return Container(
        height: _listHeight,
        color: const Color(0xFF0F0F0F),
        child: Column(
          children: [
            const Divider(color: Colors.white10, height: 1),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: state.availableEpisodes.length,
                itemBuilder: (context, index) {
                  final ep = state.availableEpisodes[index];
                  final isCurrent = ep.number.toString() == state.episode;
                  return _buildEpisodeItem(ep, isCurrent, state);
                },
              ),
            ),
          ],
        ),
      );
    }

    // Fallback: Si se minimizó antes de que el player cargara episodios (o tras cold start),
    // reutiliza el mismo episodesProvider con caché inteligente (no duplica network si ya está en caché).
    final String? url = state.url;
    final String? source = state.source;
    final String? title = state.currentItem?.title;
    if (url == null || url.isEmpty || source == null || source.isEmpty) {
      return Container(
        height: _listHeight,
        color: const Color(0xFF0F0F0F),
        child: const Center(child: Text('Cargando episodios...', style: TextStyle(color: Colors.white54, fontSize: 12))),
      );
    }
    final episodesAsync = ref.watch(episodesProvider(EpisodesParams(
      url: url,
      source: source,
      title: title,
      season: state.season ?? 1,
    )));
    return Container(
      height: _listHeight,
      color: const Color(0xFF0F0F0F),
      child: episodesAsync.when(
        data: (data) {
          if (data == null || data.episodes.isEmpty) {
            return const Center(child: Text('Sin episodios', style: TextStyle(color: Colors.white54, fontSize: 12)));
          }
          // Sincroniza al estado global para futuros expands sin re-fetch
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (data.episodes.isNotEmpty && state.availableEpisodes.isEmpty) {
              ref.read(activePlayerProvider.notifier).updateSession(episodes: data.episodes);
            }
          });
          return Column(
            children: [
              const Divider(color: Colors.white10, height: 1),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: data.episodes.length,
                  itemBuilder: (context, index) {
                    final ep = data.episodes[index];
                    final isCurrent = ep.number.toString() == state.episode;
                    return _buildEpisodeItem(ep, isCurrent, state);
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24))),
        error: (_, __) => const Center(child: Text('Error al cargar', style: TextStyle(color: Colors.white54, fontSize: 12))),
      ),
    );
  }

  /// Episodios para el mini: lista sincronizada primero, lectura directa
  /// después (el fullscreen pudo no sincronizarla). Sin esto el auto-avance
  /// creía que E1 era único.
  List<EpisodeInfo> _miniEpisodes(ActivePlayerState st) {
    if (st.availableEpisodes.isNotEmpty) return st.availableEpisodes;    try {
      final url = st.url ?? '';
      final source = st.source ?? '';
      if (url.isEmpty || source.isEmpty) return const [];
      final eps = ref
          .read(episodesProvider(EpisodesParams(
            url: url,
            source: source,
            title: st.currentItem?.title,
            season: st.season,
          )))
          .valueOrNull
          ?.episodes;
      return eps ?? const [];
    } catch (_) {
      return const [];
    }
  }

  /// Converge la lista de la sesión (una vez por contenido). Con huella, no
  /// solo longitud: así el full enriquecido reemplaza al fast pobre aunque
  /// midan igual. Sin el early-return por lista no vacía, a propósito.
  void _syncMiniEpisodes(ActivePlayerState st) {
    final url = st.url ?? '';
    final source = st.source ?? '';
    if (url.isEmpty || source.isEmpty) return;
    List<EpisodeInfo>? eps;
    try {
      eps = ref
          .read(episodesProvider(EpisodesParams(
            url: url,
            source: source,
            title: st.currentItem?.title,
            season: st.season,
          )))
          .valueOrNull
          ?.episodes;
    } catch (_) {}
    if (eps == null || eps.isEmpty) return;
    final key = '$url|$source|${st.season}|${episodesFingerprint(eps)}';
    if (_episodesSyncKey == key) return;
    _episodesSyncKey = key;
    Future.microtask(() {
      try {
        ref.read(activePlayerProvider.notifier).updateSession(episodes: eps!);
      } catch (_) {}
    });
  }

  /// Fin de video + preload en el mini (paridad con el fullscreen). El motor
  /// es compartido: estas suscripciones solo actúan en modo mini para no
  /// duplicar el autoplay/preload del player grande.
  void _listenMiniPlayer(Player? player) {
    if (player == _listenedPlayer) return;
    _miniPosSub?.cancel();
    _miniCompletedSub?.cancel();
    _listenedPlayer = player;
    if (player == null) return;

    bool _isMiniActive() {
      try {
        return ref.read(activePlayerProvider).uiState == PlayerUIState.mini;
      } catch (_) {
        return false;
      }
    }

    // Umbral 90%: precargar el siguiente (una vez por episodio).
    _miniPosSub = player.stream.position.listen((pos) {
      if (!mounted || !_isMiniActive()) return;
      if (_showReplay) {
        final d = player.state.duration.inMilliseconds;
        if (d <= 0 || pos.inMilliseconds < (d * 0.9).toInt()) {
          setState(() => _showReplay = false);
        }
        return;
      }
      final d = player.state.duration.inMilliseconds;
      if (d <= 0 || pos.inMilliseconds / d < 0.9) return;
      try {
        final st = ref.read(activePlayerProvider);
        if (st.episode == null) return;
        final key = '${st.url}|${st.episode}';
        if (_preloadedForKey == key) return;
        _preloadedForKey = key;
        final eps = _miniEpisodes(st);
        final int? total = eps.isEmpty
            ? null
            : eps.map((e) => e.number).reduce((a, b) => a > b ? a : b);
        ref.read(playerPreloadControllerProvider).triggerNextPreload(
              currentSource: st.source ?? '',
              currentEpisode: st.episode,
              totalEpisodes: total,
              currentSourceUrl: st.url ?? '',
              category: st.currentItem?.type.name,
            );
      } catch (_) {}
    });

    // Fin: auto-avanzar si hay siguiente, si no mostrar Repetir.
    _miniCompletedSub = player.stream.completed.listen((completed) {
      if (!mounted || !completed || !_isMiniActive()) return;
      try {
        final st = ref.read(activePlayerProvider);
        if (player.state.duration.inMilliseconds <= 0) return;
        if (player.state.position.inMilliseconds <= 0) return;
        final cur = int.tryParse(st.episode ?? '');
        if (cur == null) {
          if (mounted) setState(() => _showReplay = true);
          return;
        }
        EpisodeInfo? next;
        for (final e in _miniEpisodes(st)) {
          if (e.number == cur + 1) {
            next = e;
            break;
          }
        }
        if (next != null && !_isSwitchingEp) {
          _switchEpisodeMini(next, st);
        } else if (mounted) {
          setState(() => _showReplay = true);
        }
      } catch (_) {}
    });
  }

  void _replayMini() {
    try {
      final st = ref.read(activePlayerProvider);
      st.player?.seek(Duration.zero);
      st.player?.play();
      if (mounted) setState(() => _showReplay = false);
    } catch (_) {}
  }

  bool _isSwitchingEp = false;
  Future<void> _switchEpisodeMini(EpisodeInfo ep, ActivePlayerState state) async {    if (_isSwitchingEp) return;
    setState(() => _isSwitchingEp = true);
    try {
      await ref.read(activePlayerProvider.notifier).switchEpisodeInSession(ep);
    } catch (e) {
      debugPrint('[mini] switch ep fail: $e');
    } finally {
      if (mounted) setState(() => _isSwitchingEp = false);
    }
  }

  Widget _buildEpisodeItem(EpisodeInfo ep, bool isCurrent, ActivePlayerState state) {
    return InkWell(
      onTap: () {
        if (isCurrent || _isSwitchingEp) return;
        _switchEpisodeMini(ep, state);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: isCurrent ? Colors.white.withOpacity(0.05) : null,
        child: Row(
          children: [
            Container(
              width: 80, height: 45,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                image: (ep.thumbnail != null && ep.thumbnail!.isNotEmpty) 
                  ? DecorationImage(image: NetworkImage(ep.thumbnail!), fit: BoxFit.cover)
                  : null,
                color: Colors.white10,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_getEpisodeDisplayTitle(ep), maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: isCurrent ? const Color(0xFFEF7A1E) : Colors.white, fontSize: 12, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal, decoration: TextDecoration.none)),
                  if (ep.duration != null && ep.duration!.isNotEmpty)
                    Text(ep.duration!, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10, decoration: TextDecoration.none)),
                ],
              ),
            ),
            if (isCurrent) AurisIcon(AurisIcons.play, color: Color(0xFFEF7A1E), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeDisplay(ActivePlayerState state) {
    return StreamBuilder<Duration>(
      stream: state.player?.stream.position,
      builder: (context, snapshot) {
        final pos = snapshot.data ?? Duration.zero;
        final dur = state.player?.state.duration ?? Duration.zero;
        return Text(
          '${_formatDuration(pos)} / ${_formatDuration(dur)}',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, decoration: TextDecoration.none, shadows: const [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1))]),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _getEpisodeDisplayTitle(EpisodeInfo ep) {
    final String rawTitle = (ep.title != null && ep.title!.isNotEmpty) ? ep.title! : 'Episodio ${ep.number}';
    if (ep.episodeType != null) {
      if (ep.episodeType == 'special' && ep.number > 0) return '${ep.number}. $rawTitle';
      return rawTitle;
    }
    if (ep.number == 0) {
      final bool already = rawTitle.toLowerCase().startsWith('ep ') || rawTitle.toLowerCase().startsWith('ep0') || rawTitle.startsWith('0');
      return already ? rawTitle : 'EP 0 · $rawTitle';
    }
    final bool startsWithNumber = rawTitle.startsWith('${ep.number}') || rawTitle.startsWith('0${ep.number}') || rawTitle.toLowerCase().startsWith('episodio') || rawTitle.toLowerCase().startsWith('ep ') || rawTitle.contains('${ep.number}\u00AA') || rawTitle.contains('${ep.number}.');
    return startsWithNumber ? rawTitle : '${ep.number}. $rawTitle';
  }
}
