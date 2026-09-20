import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../../auris_core.dart';

/// Widget unificado para el fondo (Backdrop) de la pantalla de detalles.
/// Gestiona la imagen de fondo, el tráiler de YouTube y las máscaras de gradiente.
class DetailBackdrop extends StatelessWidget {
  final String? imageUrl;
  final String? trailerKey;
  final bool showTrailer;
  final bool revealed;
  final YoutubePlayerController? ytController;
  final Widget? logo;
  final double aspectRatio;

  const DetailBackdrop({
    super.key,
    this.imageUrl,
    this.trailerKey,
    this.showTrailer = false,
    this.revealed = false,
    this.ytController,
    this.logo,
    this.aspectRatio = 16 / 9,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width > 600;

    return AspectRatio(
      aspectRatio: isWide ? 21 / 9 : aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. IMAGEN DE FONDO
          Container(color: const Color(0xFF0B0B0D)),
          if (imageUrl != null)
            ShaderMask(
              shaderCallback: (rect) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black,
                  Colors.black.withOpacity(0.8),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeInOut,
                opacity: revealed ? 1.0 : 0.0,
                child: CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  fadeInDuration: const Duration(milliseconds: 300),
                  errorWidget: (_, __, ___) => Container(color: Colors.black12),
                ),
              ),
            ),

          // 2. CAPA DE TRÁILER
          // Solo se monta si showTrailer es true: el PointerInterceptor y
          // el iframe crean elementos HTML que siguen bloqueando el mouse
          // aunque esten en opacity 0 o bajo un IgnorePointer.
          if (ytController != null && showTrailer)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 800),
              opacity: 1.0,
              child: PointerInterceptor(
                intercepting: true,
                child: YoutubePlayer(
                  controller: ytController!,
                ),
              ),
            ),

          // 3. MÁSCARAS DE DISEÑO (Protección)
          Container(color: Colors.black.withOpacity(0.2)), // Dimming
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.35],
                ),
              ),
            ),
          ),

          // 4. LOGO / TÍTULO (Si se proporciona)
          if (logo != null)
            Positioned(
              left: 20, bottom: 16, right: 20,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeInOut,
                opacity: revealed ? 1.0 : 0.0,
                child: logo!,
              ),
            ),
        ],
      ),
    );
  }
}
