import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auris_core.dart';

class MiniPlayerBar extends ConsumerStatefulWidget {
  final VoidCallback onExpand;
  const MiniPlayerBar({super.key, required this.onExpand});

  @override
  ConsumerState<MiniPlayerBar> createState() => _MiniPlayerBarState();
}

class _MiniPlayerBarState extends ConsumerState<MiniPlayerBar> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Offset _position = Offset.zero;
  bool _isDragging = false;
  bool _isHovered = false; 
  bool _isExpandedList = false; 
  late AnimationController _snapController;
  late Animation<Offset> _snapAnimation;
  final FocusNode _keyboardFocusNode = FocusNode(); 
  
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
  
  double get _playerWidth {
    final w = MediaQuery.of(context).size.width;
    if (w >= 1200) return 400.0; // desktop
    if (w >= 900) return 320.0;  // compact desktop
    if (w >= 600) return 280.0;  // tablet
    return 210.0; // móvil
  }
  double get _videoHeight => _playerWidth * (9 / 16);
  double get _metadataHeight => _playerWidth >= 280 ? 62.0 : 0.0; 
  double get _listHeight => _isExpandedList && _playerWidth >= 280 ? 300.0 : 0.0; 
  double get _totalHeight => _videoHeight + _metadataHeight + _listHeight + (_playerWidth >= 280 ? 4.0 : 0.0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    // Posición inicial: Abajo a la derecha con márgenes senior
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.of(context).size;
      if (size.width > 100 && size.height > 100) {
        setState(() {
          _position = Offset(
            size.width - _playerWidth - _edgeMargin,
            size.height - _totalHeight - _bottomOffset,
          );
        });
      }
    });
  }

  @override
  void didChangeMetrics() {
    // Senior: Re-snap al redimensionar (rotación tablet, resize desktop estrecho)
    if (!mounted || _isDragging) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _snapToCorner(Offset.zero);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _snapController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _snapToCorner(Offset velocity) {
    final size = MediaQuery.of(context).size;
    final double centerX = _position.dx + (_playerWidth / 2);
    final double centerY = _position.dy + (_totalHeight / 2);

    double targetX = _edgeMargin;
    if (centerX > size.width / 2) {
      targetX = size.width - _playerWidth - _edgeMargin;
    }

    double targetY = _topOffset;
    if (centerY > size.height / 2) {
      targetY = size.height - _totalHeight - _bottomOffset;
    }

    final targetOffset = Offset(targetX, targetY);

    _snapAnimation = _snapController.drive(
      Tween<Offset>(begin: _position, end: targetOffset),
    );

    _snapController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _position = targetOffset;
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
          onPanStart: (_) {
            _snapController.stop();
            setState(() => _isDragging = true);
          },
          onPanUpdate: (details) {
            setState(() {
              _position += details.delta;
            });
          },
          onPanEnd: (details) {
            setState(() => _isDragging = false);
            _snapToCorner(details.velocity.pixelsPerSecond);
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

                          // Adaptive overlay: >=280 usa hover desktop, <280 usa controles móviles siempre visibles
                          if (_playerWidth >= 280)
                            Positioned.fill(
                              child: AnimatedOpacity(
                                opacity: _isHovered ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 200),
                                child: _buildDesktopOverlay(state),
                              ),
                            )
                          else
                            Positioned.fill(child: _buildMobileOverlay(state)),
                        ],
                      ),
                    ),

                    // Progress siempre visible (slim en móvil), metadata/lista solo si hay espacio
                    _buildProgressBar(state),
                    if (_playerWidth >= 280) _buildMetadataArea(item, state),
                    if (_playerWidth >= 280 && _isExpandedList) _buildEpisodesList(state),
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
        onTap: () {
          // Senior: Click en cualquier parte del overlay alterna Play/Pause
          final player = state.player;
          if (player != null) {
            if (player.state.playing) player.pause();
            else player.play();
          }
        },
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
              // 1. Expandir (PiP) - Top Left
              Positioned(
                top: 10, left: 10,
                child: GestureDetector(
                  onTap: widget.onExpand,
                  child: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white, size: 24),
                ),
              ),
              
              // 2. Cerrar (X) - Top Right
              Positioned(
                top: 10, right: 10,
                child: GestureDetector(
                  onTap: () => ref.read(activePlayerProvider.notifier).stop(),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                ),
              ),
              
              // 3. Play/Pause Icon - Center
              IgnorePointer(
                child: Center(
                  child: StreamBuilder<bool>(
                    stream: state.player?.stream.playing,
                    initialData: state.player?.state.playing ?? false,
                    builder: (context, snapshot) {
                      final playing = snapshot.data ?? false;
                      return Icon(
                        playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
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
    );
  }

  Widget _buildMobileOverlay(ActivePlayerState state) {
    return Stack(
      children: [
        Positioned(
          top: 4, right: 4,
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
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
                icon: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white.withOpacity(0.9),
                  size: 20,
                ),
                onPressed: () => playing ? state.player?.pause() : state.player?.play(),
              );
            },
          ),
        ),
      ],
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
                    setState(() {
                      final size = MediaQuery.of(context).size;
                      final double bottomLimit = size.height - _bottomOffset;
                      final bool wasAtBottom = (_position.dy + _totalHeight) >= (bottomLimit - 10);
                      _isExpandedList = !_isExpandedList;
                      if (_isExpandedList) {
                        if (_position.dy + _totalHeight > bottomLimit) _position = Offset(_position.dx, bottomLimit - _totalHeight);
                      } else if (wasAtBottom) {
                        _position = Offset(_position.dx, bottomLimit - _totalHeight);
                      }
                    });
                  },
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Icon(_isExpandedList ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded, color: Colors.white.withOpacity(0.9), size: 24),
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

  bool _isSwitchingEp = false;
  Future<void> _switchEpisodeMini(EpisodeInfo ep, ActivePlayerState state) async {
    if (_isSwitchingEp) return;
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
              child: Center(child: Text(ep.number.toString(), style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
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
            if (isCurrent) const Icon(Icons.play_arrow_rounded, color: Color(0xFFEF7A1E), size: 16),
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
