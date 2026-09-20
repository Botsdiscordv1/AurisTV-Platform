import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auris_core.dart';

/// Header adaptativo para la pantalla de detalles.
/// Maneja el backdrop (imagen/video) y el título/logo con una jerarquía cinemática.
class AurisDetailHeader extends StatelessWidget {
  final String? title;
  final String? logoUrl;
  final String? bannerUrl;
  final bool revealed;
  final YoutubePlayerController? ytController;
  final bool showTrailer;
  final List<Widget> metadata; // Los badges y rating
  final Widget? actions; // Los botones de Reproducir, Lista, etc.
  final double maxHeight;

  const AurisDetailHeader({
    super.key,
    this.title,
    this.logoUrl,
    this.bannerUrl,
    this.revealed = true,
    this.ytController,
    this.showTrailer = false,
    this.metadata = const [],
    this.actions,
    this.maxHeight = 420,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width > 600;
    
    // Altura adaptativa: En móvil vertical es proporcional, en horizontal es fija contenida.
    final double effectiveHeight = isWide ? maxHeight : (width * 0.85);

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // 1. EL BACKDROP (Capa Base)
            SizedBox(
              width: double.infinity,
              height: effectiveHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: const Color(0xFF0B0B0D)),
                  
                  // Imagen de fondo con gradiente inmersivo
                  if (bannerUrl != null)
                    ShaderMask(
                      shaderCallback: (rect) => LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: const [Colors.black, Colors.black, Colors.black54, Colors.transparent],
                        stops: isWide ? const [0.0, 0.5, 0.8, 1.0] : const [0.4, 0.6, 0.8, 1.0],
                      ).createShader(rect),
                      blendMode: BlendMode.dstIn,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 1200),
                        curve: Curves.easeInOut,
                        opacity: revealed ? 1.0 : 0.0,
                        child: CachedNetworkImage(
                          imageUrl: bannerUrl!,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          fadeInDuration: const Duration(milliseconds: 300),
                          errorWidget: (_, __, ___) => Container(color: Colors.black12),
                        ),
                      ),
                    ),

                  // Máscaras de diseño unificadas
                  Container(color: Colors.black.withOpacity(0.2)), // Dimming
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                          stops: const [0.0, 0.3],
                        ),
                      ),
                    ),
                  ),

                  // Capa de Tráiler (YouTube)
                  // Solo se monta si showTrailer es true: el PointerInterceptor y
                  // el iframe crean elementos HTML que siguen bloqueando el mouse
                  // aunque esten en opacity 0 o bajo un IgnorePointer.
                  if (ytController != null && showTrailer)
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 800),
                      opacity: 1.0,
                      child: PointerInterceptor(
                        intercepting: true,
                        child: YoutubePlayer(controller: ytController!),
                      ),
                    ),

                  // LOGO / TÍTULO (Sincronizado al fondo del backdrop)
                  Positioned(
                    left: 20, bottom: 16, right: 20,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeInOut,
                      opacity: revealed ? 1.0 : 0.0,
                      child: HeroTitle(
                        title: title ?? '',
                        logo: logoUrl,
                        logoReady: revealed,
                        maxWidth: double.infinity,
                        maxHeight: 80,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                          letterSpacing: 4,
                          shadows: [
                            Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 4),
                            Shadow(color: Colors.black54, offset: Offset(2, 2), blurRadius: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        // --- SECCIÓN DE METADATA Y ACCIONES (Solo para móvil vertical) ---
        if (!isWide)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: metadata,
                ),
                if (actions != null) ...[
                  const SizedBox(height: 20),
                  actions!,
                ],
              ],
            ),
          ),
      ],
    );
  }
}
