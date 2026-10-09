import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/api_endpoints.dart';
import '../../data/models/server/episodes_response.dart';

/// Fila de episodio para listas two-panel (player, overlays).
/// Compartida por TV / Móvil / Web.
///
/// - Miniatura 16:9 con resolución ADAPTATIVA: mide su ancho real con
///   [LayoutBuilder], lo multiplica por la densidad y pide a weserv el tamaño
///   justo (webp recortado) + acota el bitmap en RAM. Sin fijos: si la
///   plataforma cambia el ancho, la resolución lo sigue.
/// - Foco D-pad / mouse con el lenguaje Auris (fondo blanco + texto negro).
class AurisEpisodeListCard extends StatelessWidget {
  final EpisodeInfo ep;
  final bool isCurrent;
  final bool autofocus;
  final VoidCallback onTap;

  /// Ancho lógico del thumb. La resolución se deriva de aquí × densidad.
  final double thumbWidth;

  final double titleSize;
  final double subtitleSize;
  final double overlineSize;
  final bool showDescription;
  final double borderRadius;
  final Color accentColor;

  const AurisEpisodeListCard({
    super.key,
    required this.ep,
    required this.isCurrent,
    required this.onTap,
    this.autofocus = false,
    this.thumbWidth = 112,
    this.titleSize = 15,
    this.subtitleSize = 12,
    this.overlineSize = 11,
    this.showDescription = true,
    this.borderRadius = 16,
    this.accentColor = const Color(0xFFEF7A1E),
  });

  @override
  Widget build(BuildContext context) {
    final bool hasThumb = ep.thumbnail?.isNotEmpty ?? false;
    final String displayTitle =
        (ep.title?.isNotEmpty ?? false) ? ep.title! : 'Episodio ${ep.number}';
    final bool hasDesc = showDescription && (ep.description?.isNotEmpty ?? false);

    return Focus(
      autofocus: autofocus,
      child: Builder(
        builder: (context) {
          final bool isFocused = Focus.of(context).hasFocus;
          final Color titleColor = isFocused ? Colors.black : Colors.white;
          final Color subColor = isFocused ? Colors.black54 : Colors.white60;
          final Color overColor =
              isFocused ? Colors.black54 : (isCurrent ? accentColor : Colors.white38);
          return AnimatedScale(
            scale: isFocused ? 1.02 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                color: isFocused ? Colors.white : const Color(0xFF272727),
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  focusColor: Colors.transparent,
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: thumbWidth,
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: isCurrent
                                    ? Border.all(
                                        color: isFocused ? Colors.black54 : accentColor,
                                        width: 2,
                                      )
                                    : null,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: hasThumb
                                    ? LayoutBuilder(
                                        builder: (context, constraints) {
                                          final double base = constraints.maxWidth.isFinite
                                              ? constraints.maxWidth
                                              : 320.0;
                                          final int w =
                                              (base * MediaQuery.devicePixelRatioOf(context)).ceil();
                                          final int h = (w * 9 / 16).ceil();
                                          return CachedNetworkImage(
                                            imageUrl: ApiEndpoints.proxyImage(
                                              ep.thumbnail!,
                                              width: w,
                                              height: h,
                                            ),
                                            fit: BoxFit.cover,
                                            memCacheWidth: w,
                                            memCacheHeight: h,
                                            placeholder: (context, url) => Container(
                                              color: Colors.white.withValues(alpha: 0.05),
                                            ),
                                            errorWidget: (context, url, error) => Center(
                                              child: Text(
                                                '${ep.number}',
                                                style: TextStyle(
                                                  color: subColor,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    : Center(
                                        child: Text(
                                          '${ep.number}',
                                          style: TextStyle(
                                            color: subColor,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'EPISODIO ${ep.number}',
                                style: TextStyle(
                                  color: overColor,
                                  fontSize: overlineSize,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: titleColor,
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (hasDesc) ...[
                                const SizedBox(height: 2),
                                Text(
                                  ep.description!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    color: subColor,
                                    fontSize: subtitleSize,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (isCurrent)
                          Icon(
                            Icons.check_rounded,
                            color: isFocused ? Colors.black : Colors.white,
                            size: 22,
                          )
                        else
                          Icon(
                            Icons.chevron_right_rounded,
                            color: isFocused ? Colors.black54 : Colors.white30,
                            size: 20,
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
}
