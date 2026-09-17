import 'package:flutter/material.dart';
import 'package:auris_core/auris_core.dart';
import '../../../core/utils/tv_responsive_utils.dart';
import 'focusable_poster_card.dart';

class TopItem extends StatelessWidget {
  final int index;
  final MediaItem item;
  final double height;
  final double textOffset;
  final VoidCallback onTap;

  const TopItem({
    super.key,
    required this.index,
    required this.item,
    required this.height,
    required this.textOffset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Senior Logic: En TV siempre usamos layout de pantalla grande, pero respetamos la lógica de ResponsiveUtils si aplica
    final bool isMobileDevice = false; 
    final int number = index + 1;
    final bool isDoubleDigit = number >= 10;
    final bool isNumberOne = number == 1;

    final double actualPosterHeight = height; 
    // El número mide el 90% para que el póster sea más alto
    final double dynamicNumberSize = isDoubleDigit ? actualPosterHeight * 0.8 : actualPosterHeight * 0.9;
    final double posterWidth = actualPosterHeight * 0.68;
    
    // NETFLIX PERFECT OVERLAP (Ajuste Fino al 22%)
    double numberVisiblePart;
    if (isNumberOne) {
      numberVisiblePart = posterWidth * 0.42; 
    } else if (isDoubleDigit) {
      // Senior Fix: Unificamos el solapamiento al 23% (factor 0.77) tanto en Web como en Móvil
      numberVisiblePart = posterWidth * 0.77; 
    } else {
      numberVisiblePart = posterWidth * 0.62; 
    }

    // Senior Fix: Letter spacing dinámico para evitar que los números se junten en pantallas pequeñas
    final double dynamicLetterSpacing = isDoubleDigit 
        ? -22.0 
        : -15.0;

    return Container(
      width: numberVisiblePart + posterWidth,
      margin: const EdgeInsets.only(right: 24), // Más aire entre tarjetas
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. NÚMERO GIGANTE (Capa Inferior)
          Positioned(
            left: isDoubleDigit ? 4 : 0,
            // BASE ALINEADA AL PÓSTER
            bottom: textOffset, 
            child: Stack(
              children: [
                // Borde gris vivo
                Text(
                  '$number',
                  style: TextStyle(
                    fontSize: dynamicNumberSize,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    letterSpacing: dynamicLetterSpacing,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = height * 0.045
                      ..strokeJoin = StrokeJoin.round
                      ..strokeCap = StrokeCap.round
                      ..color = const Color(0xFF9E9E9E),
                  ),
                ),
                // Triple capa de relleno
                Stack(
                  children: [
                    Text(
                      '$number',
                      style: TextStyle(
                        fontSize: dynamicNumberSize,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        letterSpacing: dynamicLetterSpacing,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = height * 0.02
                          ..strokeJoin = StrokeJoin.round
                          ..strokeCap = StrokeCap.round
                          ..color = const Color(0xFF050505),
                      ),
                    ),
                    Text(
                      '$number',
                      style: TextStyle(
                        fontSize: dynamicNumberSize,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        letterSpacing: dynamicLetterSpacing,
                        color: const Color(0xFF050505),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // 2. PÓSTER NORMAL (Foreground)
          Positioned(
            left: numberVisiblePart,
            top: 0,
            child: SizedBox(
              width: posterWidth,
              child: FocusablePosterCard(
                key: ValueKey(item.id),
                title: item.title,
                posterUrl: item.posterUrl,
                rating: formatRating(item.rating),
                subtitle: null, // Senior: Limpiamos overlay de año
                showInfo: false, // Senior: Ocultar título debajo en fila mítica
                onTap: onTap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
