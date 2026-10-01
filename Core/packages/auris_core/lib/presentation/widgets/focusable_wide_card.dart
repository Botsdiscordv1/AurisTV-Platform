import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auris_core.dart';

/// Widget de tarjeta panorámica (16:9) enfocado en la experiencia de usuario premium.
/// Soporta estados de foco, hover, escala animada, logos de contenido y barra de progreso.
class FocusableWideCard extends ConsumerStatefulWidget {
  final String title;
  final String imageUrl;
  final String? logoUrl;
  final double? progress;
  final String? subtitle;
  /// Segunda línea opcional bajo el subtítulo (ej. "Quedan X" bajo
  /// "T1:E7 . Título"). La fila debe reservar 2 líneas (subtitleLines: 2).
  final String? subtitle2;
  final String? rating;
  final Widget? badgeOverlay;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  /// Datos para "Mi lista" (opcional): si viene, el menú ofrece
  /// agregar/quitar de verdad; si no, la opción no se muestra.
  final FavoriteItem? favoriteItem;
  final double width;
  final double height;

  const FocusableWideCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.onTap,
    this.logoUrl,
    this.onDelete,
    this.favoriteItem,
    this.progress,
    this.subtitle,
    this.subtitle2,
    this.rating,
    this.badgeOverlay,
    this.width = 440,
    this.height = 248,
  });

  @override
  ConsumerState<FocusableWideCard> createState() => _FocusableWideCardState();
}

class _FocusableWideCardState extends ConsumerState<FocusableWideCard> {
  final ValueNotifier<bool> _isHovered = ValueNotifier<bool>(false);
  bool _isFocused = false;

  @override
  void dispose() {
    _isHovered.dispose();
    super.dispose();
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
                      SafeTap.run(widget.onTap);
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
                AurisIcon(AurisIcons.close, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('Quitar de la fila', style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ],
    );

    if (selected != null) {
      if (selected == 'details') {
        SafeTap.run(widget.onTap);
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
  Widget build(BuildContext context) {
    final isMobile = context.useMobileLayout;
    final isDesktopOrWeb = kIsWeb || MediaQuery.of(context).size.width >= 800;

    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: MouseRegion(
        hitTestBehavior: HitTestBehavior.opaque,
        onEnter: (_) { if (mounted) _isHovered.value = true; },
        onExit: (_) { if (mounted) _isHovered.value = false; },
        onHover: (_) { if (!_isHovered.value && mounted) _isHovered.value = true; },
        child: ValueListenableBuilder<bool>(
          valueListenable: _isHovered,
          builder: (context, hovered, _) {
            final isSelected = hovered || _isFocused;
            return GestureDetector(
              onTap: () => SafeTap.run(widget.onTap),
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
              child: SizedBox(
                width: widget.width,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: AnimatedScale(
                        scale: isSelected ? 1.06 : 1.0,
                        duration: kIsWeb ? const Duration(milliseconds: 250) : const Duration(milliseconds: 400),
                        curve: Curves.easeOutQuint,
                        alignment: Alignment.center,
                        child: AnimatedContainer(
                          duration: kIsWeb ? const Duration(milliseconds: 250) : const Duration(milliseconds: 400),
                          curve: Curves.easeOutQuint,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [],
                            border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: isSelected ? 2.5 : 0.0),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CuredNetworkImage(
                                  imageUrl: widget.imageUrl,
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.medium,
                                  placeholder: (context, url) => Container(color: Colors.white10),
                                  errorWidget: (context, url, error) => Center(child: AurisIcon(AurisIcons.trailer, color: Colors.white24, size: 24)),
                                ),                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                          colors: [Colors.transparent, Colors.black.withOpacity(isSelected ? 0.7 : 0.5)],
                                          stops: const [0.6, 1.0],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (widget.logoUrl != null && widget.logoUrl!.isNotEmpty)
                                  Positioned(
                                    bottom: 16, left: 12,
                                    // Caja + imagen con geometría idéntica antes y
                                    // después de cargar (sin esto el logo aparece
                                    // centrado y salta a bottomLeft al resolver).
                                    child: SizedBox(
                                      height: widget.height * 0.35,
                                      width: widget.width * 0.65,
                                      child: CachedNetworkImage(
                                        imageUrl: widget.logoUrl!,
                                        width: widget.width * 0.65,
                                        height: widget.height * 0.35,
                                        fit: BoxFit.contain,
                                        alignment: Alignment.bottomLeft,
                                        filterQuality: FilterQuality.medium,
                                        fadeInDuration:
                                            const Duration(milliseconds: 150),
                                        placeholder: (context, url) => Container(
                                          width: widget.width * 0.65,
                                          height: widget.height * 0.35,
                                          color: Colors.white.withOpacity(0.04),
                                        ),
                                        errorWidget: (_, __, ___) =>
                                            const SizedBox.shrink(),
                                      ),
                                    ),
                                  )
                                else
                                  Positioned(
                                    bottom: 12, left: 12, right: 12,
                                    child: Text(
                                      widget.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: ResponsiveUtils.bannerTitleFontSize(context),
                                        fontWeight: FontWeight.w700,
                                        shadows: [
                                          Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 10, offset: const Offset(0, 2)),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (widget.badgeOverlay != null) Positioned(top: 10, left: 10, child: widget.badgeOverlay!),

                                if (widget.progress != null && widget.progress! > 0)
                                  Positioned(
                                    bottom: 0, left: 0, right: 0,
                                    child: Container(
                                      height: 4, color: Colors.white24,
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: widget.progress!.clamp(0.0, 1.0),
                                        child: Container(decoration: const BoxDecoration(color: Color(0xFFEF7A1E), boxShadow: [BoxShadow(color: Color(0xFFEF7A1E), blurRadius: 4)])),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: ResponsiveUtils.sp(context, 20),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text.rich(
                                  subtitleRichSpan(
                                    widget.subtitle!,
                                    TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: ResponsiveUtils.bannerTitleFontSize(context) - 2.0,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            if (widget.subtitle2 != null &&
                                widget.subtitle2!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              SizedBox(
                                height: ResponsiveUtils.sp(context, 20),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text.rich(
                                  subtitleRichSpan(
                                    widget.subtitle2!,
                                    TextStyle(
                                      color: Colors.white,
                                      fontSize: ResponsiveUtils.bannerTitleFontSize(context) - 2.0,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ],
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