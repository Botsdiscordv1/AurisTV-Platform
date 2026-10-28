import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auris_core.dart';
import 'focusable_wide_card.dart';

/// Tarjeta Top 10 panorámica (Wide) estilo Netflix TV.
/// Combina un número de ranking gigante con contorno (stroke) situado a la izquierda
/// y una tarjeta `FocusableWideCard` superpuesta parcialmente sobre su lado derecho.
class FocusableTop10WideCard extends ConsumerWidget {
  final int rank;
  final String title;
  final String imageUrl;
  final VoidCallback onTap;
  final String? subtitle;
  final String? rating;
  final double? progress;
  final MediaItem? mediaItem;
  final ContentSports? sportsEvent;
  final double width;
  final double height;

  const FocusableTop10WideCard({
    super.key,
    required this.rank,
    required this.title,
    required this.imageUrl,
    required this.onTap,
    this.subtitle,
    this.rating,
    this.progress,
    this.mediaItem,
    this.sportsEvent,
    this.width = 340,
    this.height = 191.25,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double numberFontSize = height * 0.90; // Proporcional y contenido dentro de la altura
    final double numberWidth = rank == 10 ? 130 : 95; // Ancho reservado para el número
    final double overlapOffset = 40; // Solapamiento exacto donde la tarjeta cubre parte del número

    return SizedBox(
      width: width + numberWidth - overlapOffset,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerLeft,
        children: [
          // 1. Número gigante con contorno (Background) situado a la izquierda
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: SizedBox(
              width: numberWidth,
              height: height,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  '$rank',
                  style: GoogleFonts.poppins(
                    fontSize: numberFontSize,
                    fontWeight: FontWeight.w900,
                    height: 0.95,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 4.0
                      ..color = Colors.white.withOpacity(0.95),
                  ),
                ),
              ),
            ),
          ),
          // 2. Tarjeta panorámica (Foreground) superpuesta sobre la derecha del número
          Positioned(
            left: numberWidth - overlapOffset,
            top: 0,
            bottom: 0,
            child: SizedBox(
              width: width,
              height: height,
              child: FocusableWideCard(
                title: title,
                imageUrl: imageUrl,
                onTap: onTap,
                subtitle: subtitle,
                rating: rating,
                progress: progress,
                mediaItem: mediaItem,
                sportsEvent: sportsEvent,
                width: width,
                height: height,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
