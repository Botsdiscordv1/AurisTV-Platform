import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:auris_core/auris_core.dart';

/// Elemento multimedia para el collage de fondo.
class GridMediaItem {
  final String path;
  final bool isWide;

  const GridMediaItem({
    required this.path,
    this.isWide = false,
  });
}

/// Widget que muestra un collage de fondos animado detrás de la pantalla de login.
class CollageGridBackground extends StatefulWidget {
  final double scaleFactor;
  final List<GridMediaItem>? items;

  const CollageGridBackground({
    Key? key,
    this.scaleFactor = 1.0,
    this.items,
  }) : super(key: key);

  @override
  State<CollageGridBackground> createState() => _CollageGridBackgroundState();
}

class _CollageGridBackgroundState extends State<CollageGridBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 50),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Validar tamaño de pantalla para evitar NaN en el primer frame
    final size = MediaQuery.of(context).size;
    if (size.width <= 0 || size.height <= 0 || !size.width.isFinite || !size.height.isFinite) {
      return const SizedBox.shrink();
    }

    final double screenWidth = size.width;
    final double screenHeight = size.height;

    // --- Detección precisa de Plataforma (Web/Desktop vs TV vs Mobile) ---
    final bool isWebOrDesktop = kIsWeb || 
        (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || 
                     defaultTargetPlatform == TargetPlatform.macOS || 
                     defaultTargetPlatform == TargetPlatform.linux));
    final bool isMobile = !isWebOrDesktop && screenWidth < 768;
    final bool isTV = !isWebOrDesktop && !isMobile;

    // Tamaños base de las tarjetas adaptados a cada plataforma
    final double cardHeight = isMobile ? 140.0 : (isTV ? 210.0 : 175.0);
    final double gap = isMobile ? 8.0 : (isTV ? 14.0 : 12.0);
    final double posterWidth = isMobile ? 90.0 : (isTV ? 130.0 : 100.0);
    final double bannerWidth = isMobile ? 260.0 : (isTV ? 400.0 : 330.0);

    // Escala adaptativa específica por plataforma
    final double responsiveScale = isMobile
        ? 0.95
        : (isTV ? 1.75 : 1.0); // Web/Desktop usa 1.0 para verse proporcionado

    final double safeScaleFactor = (widget.scaleFactor.isFinite && widget.scaleFactor > 0)
        ? widget.scaleFactor
        : 1.0;

    final double collageScale = responsiveScale * safeScaleFactor;

    // Cobertura de filas
    int numRows = ((screenHeight * (isTV ? 3.0 : 2.2) / (cardHeight + gap)) + (isTV ? 6 : 4)).ceil();
    if (numRows <= 0 || !numRows.isFinite) numRows = 8;

    // --- Master Pool de ítems locales (Anime, Kdrama, Película, Serie) ---
    final defaultItems = <GridMediaItem>[
      for (int i = 1; i <= 20; i++) ...[
        if (i <= 10) ...[
          GridMediaItem(path: 'assets/collage/Kdrama/banner $i.webp', isWide: true),
          GridMediaItem(path: 'assets/collage/Kdrama/poster $i.webp', isWide: false),
          GridMediaItem(path: 'assets/collage/Serie/banner $i.webp', isWide: true),
          GridMediaItem(path: 'assets/collage/Serie/poster $i.webp', isWide: false),
        ],
        GridMediaItem(path: 'assets/collage/Anime/banner $i.webp', isWide: true),
        GridMediaItem(path: 'assets/collage/Anime/poster $i.webp', isWide: false),
        GridMediaItem(path: 'assets/collage/Pelicula/banner $i.webp', isWide: true),
        GridMediaItem(path: 'assets/collage/Pelicula/poster $i.webp', isWide: false),
      ]
    ];

    final List<GridMediaItem> _items = (widget.items != null && widget.items!.isNotEmpty)
        ? widget.items!
        : defaultItems;

    final List<int> rowSizes =
        List.generate(numRows, (i) => i == numRows - 1 ? 14 : 11);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ClipRect(
          child: OverflowBox(
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: Transform(
              alignment: Alignment.center,
              filterQuality: FilterQuality.low,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0006)
                ..rotateZ(isTV ? -0.05 : -0.03)
                ..rotateX(isTV ? 0.04 : 0.02)
                ..scale(collageScale),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(numRows, (rowIndex) {
                  final int count = rowSizes[rowIndex % rowSizes.length];

                  // --- Evitar repetición entre filas usando un offset primo y paso único ---
                  final int rowOffset = rowIndex * 7;
                  final List<GridMediaItem> rowItems = List.generate(
                    count,
                    (i) => _items[(rowOffset + i * 3) % _items.length],
                  );

                  final double rawSingleWidth = rowItems.fold(0.0, (sum, item) {
                    return sum +
                        (item.isWide ? bannerWidth : posterWidth) + gap;
                  });
                  final double singleWidth = (rawSingleWidth.isFinite && rawSingleWidth > 0)
                      ? rawSingleWidth
                      : 1000.0;

                  final bool goesLeft = rowIndex.isEven;
                  
                  final double progress = _controller.value.clamp(0.0, 1.0);
                  final double phase = (progress * singleWidth) % singleWidth;
                  final double safePhase = phase.isFinite ? phase : 0.0;

                  final double dx = goesLeft
                      ? (-phase).roundToDouble()
                      : (phase - singleWidth).roundToDouble();
                  final double safeDx = dx.isFinite ? dx : 0.0;

                  // Se repiten más veces los elementos para garantizar cobertura horizontal total
                  final List<GridMediaItem> repeated = [
                    ...rowItems,
                    ...rowItems,
                    ...rowItems,
                    ...rowItems,
                    ...rowItems,
                    ...rowItems,
                    ...rowItems,
                    ...rowItems,
                  ];

                  return Padding(
                    padding: EdgeInsets.only(bottom: gap),
                    child: Transform.translate(
                      offset: Offset(safeDx, 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: repeated.map((item) {
                          final double w =
                              item.isWide ? bannerWidth : posterWidth;
                          return Container(
                            width: w,
                            height: cardHeight,
                            margin: EdgeInsets.only(right: gap),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141418),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black87,
                                  blurRadius: 6,
                                  spreadRadius: 0,
                                  offset: Offset(0, 2),
                                ),
                                BoxShadow(
                                  color: Colors.black54,
                                  blurRadius: 16,
                                  spreadRadius: 2,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: item.path.startsWith('http')
                                ? Image.network(
                                    item.path,
                                    fit: BoxFit.cover,
                                    filterQuality: FilterQuality.low,
                                    gaplessPlayback: true,
                                    errorBuilder: (_, __, ___) =>
                                        _buildPlaceholder(),
                                  )
                                : Image.asset(
                                    item.path,
                                    package: 'auris_core',
                                    fit: BoxFit.cover,
                                    filterQuality: FilterQuality.low,
                                    gaplessPlayback: true,
                                    errorBuilder: (_, __, ___) =>
                                        _buildPlaceholder(),
                                  ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF1E1E24),
      child: const Center(
        child: Icon(Icons.movie_outlined, color: Colors.white24, size: 28),
      ),
    );
  }
}
