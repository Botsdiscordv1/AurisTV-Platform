import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:auris_core/auris_core.dart';

import 'episodes_detail_overlay.dart';

/// Pantalla fullscreen de detalles de un contenido.
///
/// Fondo: el backdrop del propio contenido (el mismo que usa la ficha).
/// Contenido: título + sinopsis completa, país y reparto
/// ([ContentDetailsPanel], compartido con el overlay de episodios).
///
/// Versión base: la parte visual se ajusta después.
class ContentDetailsScreen extends StatelessWidget {
  final String title;
  /// Detalle resuelto (AnimeDetail/MovieDetail) o null.
  final dynamic detailData;
  /// Backdrop ya resuelto/proxeado; si es null, fondo negro liso.
  final String? backgroundUrl;

  const ContentDetailsScreen({
    super.key,
    required this.title,
    this.detailData,
    this.backgroundUrl,
  });

  @override
  Widget build(BuildContext context) {
    final dynamic logo = detailData?.logo;
    final String? logoUrl =
        (logo is String && logo.isNotEmpty) ? logo : null;
    final String overview = (detailData is AnimeDetail)
        ? (detailData.overview ?? '')
        : (detailData is MovieDetail ? (detailData.overview ?? '') : '');

    final List<String> genres = (detailData?.genres as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final int? runtime = (detailData is AnimeDetail)
        ? detailData.duration
        : (detailData is MovieDetail ? detailData.runtime : null);

    final String runtimeStr = runtime != null && runtime > 0
        ? '${runtime} min'
        : '';

    final String cert = (detailData is MovieDetail
            ? detailData.certification
            : (detailData is AnimeDetail ? detailData.certification : null)) ??
        '13+';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Fondo: backdrop del contenido.
          //
          // Igual que en la ficha (content_screen): caja = pantalla completa
          // + cover + fondo base oscuro. NO extender la caja (un -48 arriba/
          // abajo obligaba a `cover` a agrandar la imagen ~9%, el "zoom" que
          // se veía respecto a content). La base evita el negro puro mientras
          // carga la imagen o si esta falla.
          if (backgroundUrl != null && backgroundUrl!.isNotEmpty)
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0xFF101014),
                child: CachedNetworkImage(
                  imageUrl: backgroundUrl!,
                  fit: BoxFit.cover,
                  alignment: Alignment.centerRight,
                  fadeInDuration: const Duration(milliseconds: 300),
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            )
          else
            const Positioned.fill(child: ColoredBox(color: Color(0xFF101014))),

          // 2. Scrim: oscurece para legibilidad sin llegar a negro sólido.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.black.withValues(alpha: 0.65),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // 3. Contenido en dos columnas (Izquierda: Info, Derecha: ContentDetailsPanel)
          // stretch: ambas columnas ocupan TODO el alto disponible, así el
          // hueco bajo la columna más corta nunca queda sin pintar.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(60, 40, 60, 40),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Columna Izquierda
                  Expanded(
                    flex: 5,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          HeroTitle(
                            title: title,
                            logo: logoUrl,
                            logoReady: true,
                            maxWidth: MediaQuery.sizeOf(context).width * 0.4,
                            maxHeight: 80,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Runtime (el año se muestra en "Ficha técnica")
                          if (runtimeStr.isNotEmpty)
                            Text(
                              runtimeStr,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          const SizedBox(height: 12),
                          // Badges (13+, AD, icons, Dolby Atmos)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  cert,
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Text('AD', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    SizedBox(width: 2),
                                    Icon(Icons.spatial_audio, color: Colors.white, size: 14),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(Icons.closed_caption_outlined, color: Colors.white, size: 16),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(Icons.hdr_on_rounded, color: Colors.white, size: 16),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Dolby Atmos',
                                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Overview
                          Text(
                            overview.isNotEmpty ? overview : 'No hay descripción disponible.',
                            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
                          ),
                          const SizedBox(height: 16),
                          // Genres
                          if (genres.isNotEmpty)
                            Text(
                              genres.join(' • '),
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          const SizedBox(height: 32),
                          // Aceptar Button
                          const _AceptarButton(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                  // Columna Derecha (ContentDetailsPanel) — bajada un poco
                  Expanded(
                    flex: 5,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: ContentDetailsPanel(detailData: detailData),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AceptarButton extends StatefulWidget {
  const _AceptarButton();

  @override
  State<_AceptarButton> createState() => _AceptarButtonState();
}

class _AceptarButtonState extends State<_AceptarButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          decoration: BoxDecoration(
            color: _focused ? Colors.white : Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Aceptar',
            style: GoogleFonts.poppins(
              color: Colors.black,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

