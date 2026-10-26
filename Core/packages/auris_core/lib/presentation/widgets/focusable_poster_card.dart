import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:auris_core/auris_core.dart';
import '../../core/utils/responsive_utils.dart';
import 'marquee_text.dart';
import 'package:flutter_svg/flutter_svg.dart';

Color _colorFromString(String s) {
  final hash = s.codeUnits.fold<int>(0, (h, c) => h * 31 + c);
  // Paleta AurisTV: Naranjas, Grises Pro y Azules Cine
  const colors = [
    Color(0xFFEF7A1E), // Brand Orange
    Color(0xFF2A2A2A), // Deep Grey
    Color(0xFF1E1E26), // Blue Tint Grey
    Color(0xFF3D1D0A), // Dark Orange
    Color(0xFF1976D2), // Cinema Blue
  ];
  return colors[hash.abs() % colors.length];
}

Widget _letterPlaceholder(String title) {
  final baseColor = _colorFromString(title);
  
  return Container(
    decoration: BoxDecoration(
      color: const Color(0xFF0D0D0D),
      gradient: RadialGradient(
        center: Alignment.center,
        radius: 1.2,
        colors: [
          baseColor.withOpacity(0.15),
          const Color(0xFF0D0D0D),
        ],
      ),
    ),
    child: Center(
      child: Opacity(
        opacity: 0.15, // Un poco más visible ahora que no hay letra
        child: SvgPicture.asset(
          'assets/icons/auris-tv-icon.svg',
          width: 80, // Tamaño más equilibrado como icono central
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
      ),
    ),
  );
}

class FocusablePosterCard extends ConsumerStatefulWidget {
  final String title;
  final String posterUrl;
  final VoidCallback onTap;
  final String? badge;
  final Widget? badgeOverlay;
  final String? subtitle;
  final Color? subtitleColor;
  final String? rating;
  final Color? badgeColor;
  final Widget? airingOverlay; // Senior Fix: Slot para esquina superior izquierda
  final bool showInfo;
  final double? progress; // Senior Fix: Soporte para barra de progreso en póster
  final MediaItem? mediaItem;
  final ContentSports? sportsEvent;
  final VoidCallback? onDelete;
  final FavoriteItem? favoriteItem;

  const FocusablePosterCard({
    super.key,
    required this.title,
    required this.posterUrl,
    required this.onTap,
    this.badge,
    this.badgeOverlay,
    this.subtitle,
    this.subtitleColor,
    this.rating,
    this.badgeColor,
    this.airingOverlay,
    this.showInfo = true,
    this.progress,
    this.mediaItem,
    this.sportsEvent,
    this.onDelete,
    this.favoriteItem,
  });

  @override
  ConsumerState<FocusablePosterCard> createState() => _FocusablePosterCardState();
}

class _FocusablePosterCardState extends ConsumerState<FocusablePosterCard> {
  bool _focused = false;
  final ValueNotifier<bool> _hovered = ValueNotifier<bool>(false);

  bool get _isSportsItem => isSportsItemMetadata(
        title: widget.title,
        source: widget.mediaItem?.source,
        channels: widget.mediaItem?.channels,
      );

  void _handleTap(BuildContext context) {
    handleCardTapOrSportsNavigation(
      context,
      title: widget.title,
      imageUrl: widget.posterUrl,
      onTap: widget.onTap,
      source: widget.mediaItem?.source,
      channels: widget.mediaItem?.channels,
      subtitle: widget.subtitle,
    );
  }

  void _showOptionsModal(BuildContext context) {
    ref.read(bottomNavVisibleProvider.notifier).state = false;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18181B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: AurisIcon(AurisIcons.close, color: Colors.white70, size: 24),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  ListTile(
                    leading: AurisIcon(AurisIcons.info, color: Colors.white, size: 24),
                    title: Text('Ver detalles y más', style: GoogleFonts.poppins(color: Colors.white, fontSize: 15)),
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
                      Navigator.pop(context);
                      _handleTap(context);
                    },
                  ),
                  ListTile(
                    leading: AurisIcon(AurisIcons.download, color: Colors.white, size: 24),
                    title: Text('Descargar', style: GoogleFonts.poppins(color: Colors.white, fontSize: 15)),
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Descarga no disponible')),
                      );
                    },
                  ),
                  ListTile(
                    leading: AurisIcon(AurisIcons.close, color: Colors.white, size: 24),
                    title: Text('No es para mí', style: GoogleFonts.poppins(color: Colors.white, fontSize: 15)),
                    contentPadding: EdgeInsets.zero,
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Preferencia guardada')),
                      );
                    },
                  ),
                  if (widget.favoriteItem != null)
                    ListTile(
                      leading: AurisIcon(
                        ref.watch(favoritesProvider).any((f) => f.id == widget.favoriteItem!.id)
                            ? AurisIcons.bookmarkFilled
                            : AurisIcons.addCircleOutline,
                        color: Colors.white,
                        size: 24,
                      ),
                      title: Text(
                        ref.watch(favoritesProvider).any((f) => f.id == widget.favoriteItem!.id)
                            ? 'Quitar de Mi lista'
                            : 'Mi lista',
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
                      ),
                      contentPadding: EdgeInsets.zero,
                      onTap: () {
                        Navigator.pop(context);
                        final fav = widget.favoriteItem!;
                        final wasFav = ref.read(favoritesProvider).any((f) => f.id == fav.id);
                        ref.read(favoritesProvider.notifier).toggleFavorite(fav);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(wasFav ? 'Quitado de Mi lista' : 'Añadido a Mi lista')),
                        );
                      },
                    ),
                  if (widget.onDelete != null) ...[
                    const Divider(color: Colors.white12, height: 16),
                    ListTile(
                      leading: AurisIcon(AurisIcons.close, color: Colors.white, size: 24),
                      title: Text('Quitar de la fila', style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                      contentPadding: EdgeInsets.zero,
                      onTap: () {
                        Navigator.pop(context);
                        widget.onDelete!();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) {
        ref.read(bottomNavVisibleProvider.notifier).state = true;
      }
    });
  }

  void _showContextMenu(BuildContext context, Offset globalPosition) async {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      globalPosition & const Size(40, 40),
      Offset.zero & overlay.size,
    );

    final String? selected = await showMenu<String>(
      context: context,
      position: position,
      color: const Color(0xFF282828),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 8,
      items: [
        PopupMenuItem<String>(
          value: 'details',
          child: Row(
            children: [
              AurisIcon(AurisIcons.info, color: Colors.white70, size: 20),
              const SizedBox(width: 12),
              Text('Ver detalles y más', style: GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'download',
          child: Row(
            children: [
              AurisIcon(AurisIcons.download, color: Colors.white70, size: 20),
              const SizedBox(width: 12),
              Text('Descargar', style: GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'not_for_me',
          child: Row(
            children: [
              AurisIcon(AurisIcons.close, color: Colors.white70, size: 20),
              const SizedBox(width: 12),
              Text('No es para mí', style: GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        if (widget.favoriteItem != null)
          PopupMenuItem<String>(
            value: 'mylist',
            child: Row(
              children: [
                AurisIcon(AurisIcons.addCircleOutline, color: Colors.white70, size: 20),
                const SizedBox(width: 12),
                Text('Mi lista', style: GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
              ],
            ),
          ),
        if (widget.onDelete != null)
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                AurisIcon(AurisIcons.close, color: Colors.white70, size: 20),
                const SizedBox(width: 12),
                Text('Quitar de la fila', style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ],
    );

    if (selected != null) {
      if (selected == 'details') {
        _handleTap(context);
      } else if (selected == 'download') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Descarga no disponible')),
        );
      } else if (selected == 'not_for_me') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferencia guardada')),
        );
      } else if (selected == 'mylist' && widget.favoriteItem != null) {
        final fav = widget.favoriteItem!;
        final wasFav = ref.read(favoritesProvider).any((f) => f.id == fav.id);
        ref.read(favoritesProvider.notifier).toggleFavorite(fav);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(wasFav ? 'Quitado de Mi lista' : 'Añadido a Mi lista')),
        );
      } else if (selected == 'delete') {
        widget.onDelete?.call();
      }
    }
  }

  @override
  void dispose() {
    _hovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isSportsItem) {
      final sportsEvent = widget.sportsEvent ?? ContentSports(
        id: widget.mediaItem?.id ?? widget.title,
        title: widget.title,
        posterUrl: widget.posterUrl,
        bannerUrl: widget.mediaItem?.bannerUrl ?? widget.posterUrl,
        channels: (widget.mediaItem?.channels != null && widget.mediaItem!.channels!.isNotEmpty)
            ? widget.mediaItem!.channels!
            : [{'name': 'Canal Principal', 'url': widget.mediaItem?.detailUrl ?? ''}],
        source: widget.mediaItem?.source ?? 'ppv',
        league: widget.subtitle ?? widget.mediaItem?.subtitle,
      );
      return SportsCard(
        event: sportsEvent,
        isFocused: _focused,
      );
    }

    final isMobile = context.useMobileLayout;
    final isDesktopOrWeb = kIsWeb || MediaQuery.of(context).size.width >= 800;
    final double normalWidth = ResponsiveUtils.posterWidth(context);

    return MouseRegion(
      hitTestBehavior: HitTestBehavior.opaque,
      onEnter: (_) { if (!isMobile && mounted) _hovered.value = true; },
      onExit: (_) { if (!isMobile && mounted) _hovered.value = false; },
      onHover: (_) { if (!isMobile && !_hovered.value && mounted) _hovered.value = true; },
      child: Focus(
        onFocusChange: (focused) {
          if (!mounted) return;
          if (focused) {
            context.findRenderObject()?.showOnScreen(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
            );
          }
          setState(() => _focused = focused);
        },
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.enter || 
                event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.space) {
              _handleTap(context);
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: ValueListenableBuilder<bool>(
          valueListenable: _hovered,
          builder: (context, hovered, _) {
            final isActive = _focused || hovered;
            return GestureDetector(
              onTap: () => _handleTap(context),
              onLongPressStart: (details) {
                if (isDesktopOrWeb) {
                  _showContextMenu(context, details.globalPosition);
                } else {
                  _showOptionsModal(context);
                }
              },
              onSecondaryTapDown: (details) {
                if (isDesktopOrWeb) {
                  _showContextMenu(context, details.globalPosition);
                }
              },
              child: Container(
                width: normalWidth,
                margin: const EdgeInsets.only(right: 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AspectRatio(
                      aspectRatio: 2 / 3,
                      child: DisneyFocusShell(
                        active: isActive,
                        activeShadow: DisneyFocusTokens.shadowFor(context),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(DisneyFocusTokens.radius),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                                Builder(
                                  builder: (context) {
                                    final dpr = MediaQuery.of(context).devicePixelRatio;
                                    // Senior TV/Low-RAM Tuning: Pósters con tope de 400px en memoria
                                    // para no desbordar RAM en TV Boxes de 1GB ni provocar descarte en cache
                                    final targetWidth = (normalWidth * dpr).round().clamp(1, 400);
                                    final targetHeight = (targetWidth * 1.5).round().clamp(1, 600);
                                    return CuredNetworkImage(
                                      imageUrl: ApiEndpoints.proxyImage(
                                        widget.posterUrl,
                                        policy: ImageSize.poster,
                                      ),
                                      fit: BoxFit.cover,
                                      memCacheWidth: targetWidth,
                                      memCacheHeight: targetHeight,
                                      filterQuality: FilterQuality.medium,
                                      placeholder: (context, url) => _letterPlaceholder(widget.title),
                                      errorWidget: (context, url, error) => _letterPlaceholder(widget.title),
                                    );
                                  },
                                ),

                                ClipRRect(
                                  borderRadius: BorderRadius.circular(DisneyFocusTokens.radius),
                                  clipBehavior: Clip.antiAliasWithSaveLayer,
                                  child: Stack(
                                    children: [
                                      if (widget.airingOverlay != null)
                                        Positioned(
                                          top: -1, left: -1,
                                          child: widget.airingOverlay!
                                        ),
                                      if (widget.badge != null)
                                        Positioned(
                                          top: -1, right: -1,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: widget.badgeColor ?? const Color(0xFF1E1E26).withOpacity(0.9),
                                              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8)),
                                              border: Border.all(color: Colors.white10, width: 0.5),
                                            ),
                                            child: Text(
                                              widget.badge!,
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.5
                                              )
                                            ),
                                          ),
                                        ),
                                      if (widget.badgeOverlay != null)
                                        Positioned(
                                          bottom: (widget.progress != null && widget.progress! > 0) ? 3 : -1,
                                          right: -1,
                                          child: widget.badgeOverlay!
                                        ),
                                      if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
                                        Positioned(
                                          bottom: (widget.progress != null && widget.progress! > 0) ? 3 : -1,
                                          left: -1,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: widget.subtitleColor ?? const Color(0xFF1E1E26).withOpacity(0.95),
                                              borderRadius: const BorderRadius.only(topRight: Radius.circular(8)),
                                              border: Border.all(color: Colors.white10, width: 0.5),
                                            ),
                                            child: Text(
                                              widget.subtitle!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (widget.progress != null && widget.progress! > 0)
                                        Positioned(
                                          bottom: 0, left: 0, right: 0,
                                          child: Container(
                                            height: 4,
                                            color: Colors.black45,
                                            child: FractionallySizedBox(
                                              alignment: Alignment.centerLeft,
                                              widthFactor: widget.progress!.clamp(0.0, 1.0),
                                              child: Container(
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFEF7A1E),
                                                  boxShadow: [BoxShadow(color: Color(0xFFEF7A1E), blurRadius: 4)],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (widget.showInfo) ...[
                      SizedBox(height: isMobile ? ResponsiveUtils.sp(context, 8) : 8),
                      SizedBox(
                        height: isMobile ? ResponsiveUtils.sp(context, 22) : 28,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: MarqueeText(
                            text: widget.title,
                            animate: isMobile ? true : isActive,
                            style: GoogleFonts.poppins(
                              color: isActive ? Colors.white : Colors.white.withOpacity(0.95),
                              fontSize: ResponsiveUtils.posterTitleFontSize(context),
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ],
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
