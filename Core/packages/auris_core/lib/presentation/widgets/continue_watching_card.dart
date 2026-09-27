import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../auris_core.dart';

/// Widget reutilizable para "Continuar Viendo", basado en el diseño oficial de AurisTV.
class ContinueWatchingCard extends ConsumerStatefulWidget {
  final PlaybackHistory history;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final double? width;
  final double? height;

  const ContinueWatchingCard({
    super.key,
    required this.history,
    this.onTap,
    this.onDelete,
    this.width,
    this.height,
  });

  @override
  ConsumerState<ContinueWatchingCard> createState() => _ContinueWatchingCardState();
}

class _ContinueWatchingCardState extends ConsumerState<ContinueWatchingCard> {
  final ValueNotifier<bool> _isHovered = ValueNotifier<bool>(false);
  bool _isFocused = false;

  @override
  void dispose() {
    _isHovered.dispose();
    super.dispose();
  }

  void _showOptionsModal(BuildContext context, String titleText) {
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
                        titleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12, height: 24),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.white),
                  title: const Text('Ver detalles y más', style: TextStyle(color: Colors.white, fontSize: 15)),
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    Navigator.pop(context);
                    if (widget.onTap != null) SafeTap.run(widget.onTap!);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download_rounded, color: Colors.white),
                  title: const Text('Descargar', style: TextStyle(color: Colors.white, fontSize: 15)),
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Descarga no disponible')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.thumb_down_outlined, color: Colors.white),
                  title: const Text('No es para mí', style: TextStyle(color: Colors.white, fontSize: 15)),
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Preferencia guardada')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.add_rounded, color: Colors.white),
                  title: const Text('Mi lista', style: TextStyle(color: Colors.white, fontSize: 15)),
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Añadido a Mi lista')),
                    );
                  },
                ),
                if (widget.onDelete != null) ...[
                  const Divider(color: Colors.white12, height: 16),
                  ListTile(
                    leading: const Icon(Icons.close_rounded, color: Colors.white),
                    title: const Text('Quitar de la fila', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
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

  void _showContextMenu(BuildContext context, Offset globalPosition, String titleText) async {
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
              const Icon(Icons.info_outline, color: Colors.white70, size: 20),
              const SizedBox(width: 12),
              const Text('Ver detalles y más', style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'download',
          child: Row(
            children: [
              const Icon(Icons.download_rounded, color: Colors.white70, size: 20),
              const SizedBox(width: 12),
              const Text('Descargar', style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'not_for_me',
          child: Row(
            children: [
              const Icon(Icons.thumb_down_outlined, color: Colors.white70, size: 20),
              const SizedBox(width: 12),
              const Text('No es para mí', style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'mylist',
          child: Row(
            children: [
              const Icon(Icons.add_rounded, color: Colors.white70, size: 20),
              const SizedBox(width: 12),
              const Text('Mi lista', style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        if (widget.onDelete != null)
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                const Text('Quitar de la fila', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ],
    );

    if (selected != null) {
      if (selected == 'details') {
        if (widget.onTap != null) SafeTap.run(widget.onTap!);
      } else if (selected == 'download') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Descarga no disponible')),
        );
      } else if (selected == 'not_for_me') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferencia guardada')),
        );
      } else if (selected == 'mylist') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Añadido a Mi lista')),
        );
      } else if (selected == 'delete') {
        widget.onDelete?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const brandOrange = Color(0xFFEF7A1E);
    const textPrimary = Color(0xFFF5F5F5);
    const progressTrack = Color(0xFF39393D);
    final isDesktopOrWeb = kIsWeb || MediaQuery.of(context).size.width >= 800;

    final double effectiveWidth = widget.width ?? ResponsiveUtils.bannerWidth(context);
    final String? imageUrl = widget.history.bannerUrl ?? widget.history.posterUrl;
    final String? logoUrl = widget.history.logoUrl;
    final remainingMs = widget.history.durationInMilliseconds - widget.history.positionInMilliseconds;

    final String titleText = isMovieLike(widget.history.category, widget.history.title, widget.history.durationInMilliseconds)
        ? (widget.history.title ?? '').replaceAll(RegExp(r'^[Ee]p\s*\d+\s*[.\-•]\s*'), '').trim()
        : '${widget.history.episode != null ? 'Ep ${widget.history.episode} • ' : ''}${widget.history.title ?? ''}';

    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: MouseRegion(
        onEnter: (_) { _isHovered.value = true; },
        onExit: (_) { _isHovered.value = false; },
        child: ValueListenableBuilder<bool>(
          valueListenable: _isHovered,
          builder: (context, hovered, _) {
            final isActive = hovered || _isFocused;
            return GestureDetector(
              onTap: widget.onTap != null ? () => SafeTap.run(widget.onTap!) : null,
              onLongPressStart: (details) {
                if (isDesktopOrWeb) {
                  _showContextMenu(context, details.globalPosition, titleText);
                } else {
                  _showOptionsModal(context, titleText);
                }
              },
              onSecondaryTapDown: (details) {
                if (isDesktopOrWeb) {
                  _showContextMenu(context, details.globalPosition, titleText);
                }
              },
              child: Container(
                width: effectiveWidth,
                margin: const EdgeInsets.only(right: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: AnimatedScale(
                        scale: isActive ? 1.06 : 1.0,
                        duration: kIsWeb ? const Duration(milliseconds: 250) : const Duration(milliseconds: 400),
                        curve: Curves.easeOutQuint,
                        alignment: Alignment.center,
                        child: AnimatedContainer(
                          duration: kIsWeb ? const Duration(milliseconds: 250) : const Duration(milliseconds: 400),
                          curve: Curves.easeOutQuint,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: isActive ? [BoxShadow(color: Colors.white.withOpacity(0.12), blurRadius: 40, spreadRadius: 0)] : [],
                            border: Border.all(color: isActive ? Colors.white : Colors.transparent, width: isActive ? 2.5 : 0.0),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (imageUrl != null)
                                  CachedNetworkImage(
                                    imageUrl: ApiEndpoints.proxyImage(
                                      imageUrl,
                                      width: (widget.history.category == 'movie' || widget.history.category == 'movie_anime') ? 1280 : 800,
                                    ),
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(color: Colors.white10),
                                    errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image, color: Colors.white24)),
                                  )
                                else
                                  const Center(child: Icon(Icons.movie, color: Colors.white24)),

                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                          colors: [Colors.transparent, Colors.black.withOpacity(isActive ? 0.7 : 0.5)],
                                          stops: const [0.6, 1.0],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                if (logoUrl != null && logoUrl.isNotEmpty)
                                  Positioned(
                                    bottom: 16, left: 12,
                                    child: Container(
                                      height: (effectiveWidth / 1.77) * 0.35,
                                      width: effectiveWidth * 0.65,
                                      alignment: Alignment.bottomLeft,
                                      child: CachedNetworkImage(
                                        imageUrl: ApiEndpoints.proxyImage(logoUrl),
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.medium,
                                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                                      ),
                                    ),
                                  )
                                else
                                  Positioned(
                                    bottom: 12, left: 12, right: 12,
                                    child: Text(
                                      titleText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: textPrimary,
                                        fontSize: ResponsiveUtils.bannerTitleFontSize(context),
                                        fontWeight: FontWeight.w700,
                                        shadows: const [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 2))],
                                      ),
                                    ),
                                  ),

                                if (widget.history.progress > 0)
                                  Positioned(
                                    bottom: 0, left: 0, right: 0,
                                    child: Container(
                                      height: 4,
                                      color: progressTrack,
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: widget.history.progress.clamp(0.0, 1.0),
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            color: brandOrange,
                                            boxShadow: [BoxShadow(color: brandOrange, blurRadius: 4)],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (remainingMs > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SizedBox(
                          height: ResponsiveUtils.sp(context, 20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              'Quedan ${AurisStringUtils.formatRemainingTime(remainingMs)}',
                              style: TextStyle(
                                color: textPrimary.withOpacity(0.6),
                                fontSize: ResponsiveUtils.bannerTitleFontSize(context) - 2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
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
