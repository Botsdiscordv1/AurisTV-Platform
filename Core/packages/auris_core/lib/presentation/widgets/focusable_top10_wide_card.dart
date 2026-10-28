import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auris_core.dart';
import 'focusable_wide_card.dart';

/// Tarjeta Top 10 panorámica (Wide) estilo Netflix TV.
/// Replicada fielmente desde TopItem (Top 10):
/// 1. Número gigante 3D en capa inferior con contorno gris vivo y relleno oscuro.
/// 2. Tarjeta panorámica (Wide) en capa superior con solapamiento milimétrico.
class FocusableTop10WideCard extends ConsumerWidget {
  final int rank;
  final String title;
  final String imageUrl;
  final VoidCallback onTap;
  final String? logoUrl;
  final String? subtitle;
  final String? subtitle2;
  final String? rating;
  final double? progress;
  final MediaItem? mediaItem;
  final ContentSports? sportsEvent;
  final double width;
  final double height;
  final double textOffset;
  final EdgeInsetsGeometry? margin;
  final bool isBannerFallback;

  const FocusableTop10WideCard({
    super.key,
    required this.rank,
    required this.title,
    required this.imageUrl,
    required this.onTap,
    this.logoUrl,
    this.subtitle,
    this.subtitle2,
    this.rating,
    this.progress,
    this.mediaItem,
    this.sportsEvent,
    this.width = 384.0,
    this.height = 216.0,
    this.textOffset = 0.0,
    this.margin,
    this.isBannerFallback = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int number = rank;
    final bool isDoubleDigit = number >= 10;
    final bool isNumberOne = number == 1;

    final double actualCardHeight = height;
    // El número mide entre el 85% y 95% para tener presencia imponente pero proporcionada
    final double dynamicNumberSize =
        isDoubleDigit ? actualCardHeight * 0.85 : actualCardHeight * 0.95;

    // Solapamiento perfecto estilo Netflix para tarjetas panorámicas (Wide)
    double numberVisiblePart;
    if (isNumberOne) {
      numberVisiblePart = width * 0.18;
    } else if (isDoubleDigit) {
      numberVisiblePart = width * 0.36;
    } else {
      numberVisiblePart = width * 0.28;
    }

    final double dynamicLetterSpacing = isDoubleDigit
        ? -18.0 * (height / 216.0)
        : -12.0 * (height / 216.0);

    return Container(
      width: numberVisiblePart + width,
      height: height,
      margin: margin,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          // 1. NÚMERO GIGANTE ESTILO NETFLIX (Centrado verticalmente con la tarjeta)
          Positioned(
            left: isDoubleDigit ? 4 : 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: Stack(
              children: [
                // Borde gris vivo
                Text(
                  '$number',
                  style: TextStyle(
                    fontFamily: 'NetflixSans',
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
                // Capa interior de relleno oscuro y borde
                Stack(
                  children: [
                    Text(
                      '$number',
                      style: TextStyle(
                        fontFamily: 'NetflixSans',
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
                        fontFamily: 'NetflixSans',
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
          ),

          // 2. TARJETA WIDE DEL MISMO TAMAÑO QUE EL HOME (Foreground)
          Positioned(
            left: numberVisiblePart,
            top: 0,
            child: SizedBox(
              width: width,
              height: height,
              child: FocusableWideCard(
                title: title,
                imageUrl: imageUrl,
                logoUrl: logoUrl,
                onTap: onTap,
                subtitle: subtitle,
                subtitle2: subtitle2,
                rating: rating,
                progress: progress,
                mediaItem: mediaItem,
                sportsEvent: sportsEvent,
                width: width,
                height: height,
                isBannerFallback: isBannerFallback,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
