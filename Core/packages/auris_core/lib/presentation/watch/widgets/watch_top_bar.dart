import 'package:flutter/material.dart';

/// Barra Superior de Navegación (TopBar) para la WatchScreen (Estilo Web Desktop).
///
/// Incluye:
/// - Botón de retroceso `← Volver` con animación al hacer hover.
/// - Ruta de migas de pan (Breadcrumbs) `Inicio > Categoría > Serie > Episodio > Servidor`.
/// - Muestra únicamente el servidor / fuente activa en una cápsula elegante.
class WatchTopBar extends StatelessWidget {
  const WatchTopBar({
    super.key,
    this.onBack,
    this.category,
    this.seriesTitle,
    this.episodeNumber,
    this.serverName,
    this.isBookmarked = false,
    this.onBookmarkToggle,
    this.onSharePressed,
  });

  final VoidCallback? onBack;
  final String? category;
  final String? seriesTitle;
  final String? episodeNumber;
  final String? serverName;
  final bool isBookmarked;
  final VoidCallback? onBookmarkToggle;
  final VoidCallback? onSharePressed;

  String _formatCategoryLabel(String? cat) {
    if (cat == null || cat.isEmpty) return 'Catálogo';
    switch (cat.toLowerCase()) {
      case 'anime':
        return 'Anime';
      case 'movie':
      case 'pelicula':
      case 'peliculas':
        return 'Películas';
      case 'series':
      case 'serie':
        return 'Series';
      case 'sports':
      case 'deportes':
        return 'Deportes';
      default:
        return cat[0].toUpperCase() + cat.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String categoryLabel = _formatCategoryLabel(category);
    final String mainTitle = seriesTitle ?? 'Contenido';
    final String epNumStr = (episodeNumber != null && episodeNumber!.isNotEmpty)
        ? (episodeNumber!.startsWith('E') ? episodeNumber! : 'Ep. $episodeNumber')
        : '';

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        border: const Border(
          bottom: BorderSide(color: Colors.white10, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // 1. Botón Volver con animación de Hover
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(20),
              hoverColor: Colors.white.withValues(alpha: 0.12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Volver',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),
          Container(
            height: 16,
            width: 1,
            color: Colors.white24,
          ),
          const SizedBox(width: 12),

          // 2. Ruta de Migas de Pan (Breadcrumbs) + Cápsula del Servidor Activo al final
          Expanded(
            child: Row(
              children: [
                // Inicio
                const Text(
                  'Inicio',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 16),
                ),

                // Categoría
                Text(
                  categoryLabel,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 16),
                ),

                // Título de la Serie / Película
                Flexible(
                  child: Text(
                    mainTitle,
                    style: const TextStyle(
                      color: Color(0xFFEF7A1E),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                if (epNumStr.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 16),
                  ),
                  Text(
                    epNumStr,
                    style: const TextStyle(
                      color: Color(0xDDFFFFFF),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                // Cápsula del Servidor / Fuente Activa
                if (serverName != null && serverName!.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 16),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12, width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4CAF50),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          serverName!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
