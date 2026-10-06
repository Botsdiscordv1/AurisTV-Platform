import 'dart:math';
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

/// Fila individual de desplazamiento con controlador propio para un loop 100% fluido y sin saltos
class _ScrollingRow extends StatefulWidget {
  final int rowIndex;
  final List<GridMediaItem> rowItems;
  final double cardHeight;
  final double horizontalGap;
  final double posterWidth;
  final double bannerWidth;

  const _ScrollingRow({
    required this.rowIndex,
    required this.rowItems,
    required this.cardHeight,
    required this.horizontalGap,
    required this.posterWidth,
    required this.bannerWidth,
  });

  @override
  State<_ScrollingRow> createState() => _ScrollingRowState();
}

class _ScrollingRowState extends State<_ScrollingRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rowController;

  @override
  void initState() {
    super.initState();
    // Duración única por fila para dar variedad de velocidad de forma independiente y fluida
    final int durationSeconds = 45 + (widget.rowIndex * 6);
    _rowController = AnimationController(
      vsync: this,
      duration: Duration(seconds: durationSeconds),
    )..repeat();
  }

  @override
  void dispose() {
    _rowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double singleWidth = widget.rowItems.fold(0.0, (sum, item) {
      return sum + (item.isWide ? widget.bannerWidth : widget.posterWidth) + widget.horizontalGap;
    });

    final bool goesLeft = widget.rowIndex.isEven;

    // Construir los widgets hijos una sola vez (evita reconstrucciones en cada frame)
    final List<GridMediaItem> repeated = [
      ...widget.rowItems,
      ...widget.rowItems,
      ...widget.rowItems,
      ...widget.rowItems,
    ];

    final rowChildren = repeated.map((item) {
      final double w = item.isWide ? widget.bannerWidth : widget.posterWidth;
      return Container(
        width: w,
        height: widget.cardHeight,
        margin: EdgeInsets.only(right: widget.horizontalGap),
        decoration: BoxDecoration(
          color: const Color(0xFF141418),
          borderRadius: BorderRadius.circular(6),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          item.path,
          package: 'auris_core',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox(),
        ),
      );
    }).toList();

    // Aislar el renderizado y animar la traslación X asegurando un wrap exacto de 0 a singleWidth (sin saltos)
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _rowController,
        builder: (context, child) {
          final double progress = _rowController.value;
          final double distance = progress * singleWidth;
          final double phase = distance % singleWidth;

          final double dx = goesLeft
              ? (-phase).roundToDouble()
              : (phase - singleWidth).roundToDouble();

          return Transform.translate(
            offset: Offset(dx.isFinite ? dx : 0.0, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: rowChildren,
            ),
          );
        },
      ),
    );
  }
}

/// Widget que muestra un collage de fondos animado detrás de la pantalla de login.
class CollageGridBackground extends StatelessWidget {
  final double scaleFactor;
  final List<GridMediaItem>? items;

  const CollageGridBackground({
    Key? key,
    this.scaleFactor = 1.0,
    this.items,
  }) : super(key: key);

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

    // Factor de escala interno por dispositivo (TV usa 0.78 para tarjetas compactas)
    final bool isMobileDevice = isMobile;
    final double deviceScale = isMobileDevice ? 0.95 : (isTV ? 0.78 : 1.0);
    final double safeScaleFactor = (scaleFactor.isFinite && scaleFactor > 0)
        ? scaleFactor
        : 1.0;
    final double finalScale = deviceScale * safeScaleFactor;

    // Tamaños base de las tarjetas
    final double cardHeight = (isMobile ? 130.0 : 175.0) * finalScale;
    final double rowGap = (isMobile ? 8.0 : 12.0) * finalScale;
    final double horizontalGap = (isMobile ? 6.0 : 10.0) * finalScale;
    final double posterWidth = (isMobile ? 100.0 : 125.0) * finalScale;
    final double bannerWidth = (isMobile ? 240.0 : 330.0) * finalScale;

    // En móviles, limitamos el número de filas a 5 para garantizar rendimiento de 60 FPS sin lag
    int numRows = isMobile ? 5 : ((screenHeight * 2.2 / (cardHeight + rowGap)) + 4).ceil();
    if (numRows <= 0 || !numRows.isFinite) numRows = isMobile ? 5 : 12;

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

    final List<GridMediaItem> _items = (items != null && items!.isNotEmpty)
        ? items!
        : defaultItems;

    // --- Distribución Global Sin Repetición Entre Filas ---
    final List<GridMediaItem> masterPool = List<GridMediaItem>.from(_items);
    masterPool.shuffle(Random(42)); // Barajar el master pool globalmente una vez

    final List<List<GridMediaItem>> rowSpecificItems = [];
    int itemIndex = 0;
    for (int r = 0; r < numRows; r++) {
      final List<GridMediaItem> rowList = [];
      while (rowList.length < 11) {
        if (itemIndex >= masterPool.length) {
          masterPool.shuffle(Random(r + 99)); // Re-barajar si se agotan los 80 ítems
          itemIndex = 0;
        }
        rowList.add(masterPool[itemIndex]);
        itemIndex++;
      }
      rowSpecificItems.add(rowList);
    }

    return ClipRect(
      child: OverflowBox(
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: Transform(
          alignment: Alignment.center,
          filterQuality: FilterQuality.low,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0006)
            ..rotateZ(-0.03)
            ..rotateX(0.02)
            ..scale(1.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(numRows, (rowIndex) {
              return Padding(
                padding: EdgeInsets.only(bottom: rowGap),
                child: _ScrollingRow(
                  rowIndex: rowIndex,
                  rowItems: rowSpecificItems[rowIndex],
                  cardHeight: cardHeight,
                  horizontalGap: horizontalGap,
                  posterWidth: posterWidth,
                  bannerWidth: bannerWidth,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
