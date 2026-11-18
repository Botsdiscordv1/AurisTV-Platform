import 'dart:ui' show ImageFilter;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ambient_video_provider.dart';

/// Arte del contenido (banner/póster) difuminado y ampliado, a baja resolución
/// para no gastar GPU. Es la base común del modo ambiente: la usan tanto el
/// halo del watch ([AmbientGlow]) como las capas del reproductor (embebido,
/// teatro y fullscreen), así no se duplica el pipeline de blur.
class AmbientArtImage extends StatelessWidget {
  const AmbientArtImage({
    super.key,
    required this.imageUrl,
    this.sigma = 48,
    this.scale = 1.0,
  });

  final String imageUrl;
  final double sigma;

  /// Ampliación para dar margen al desenfoque (evita que los bordes se aclaren).
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: TileMode.clamp,
        ),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          memCacheWidth: 480,
          filterQuality: FilterQuality.low,
          fadeInDuration: const Duration(milliseconds: 300),
          placeholder: (_, __) => const SizedBox.shrink(),
          errorWidget: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// Halo ambiental que rodea al reproductor en el watch, equivalente al
/// "modo ambiente" de YouTube: una copia difuminada del arte del contenido que
/// se desvanece hacia el fondo de la página.
///
/// Debe colocarse **detrás** de la tarjeta del video y sin recortar (un `Stack`
/// con `ClipBehavior.none`), separado de ella por [bleed] en los cuatro lados.
///
/// Va **sin máscara**: en CanvasKit cualquier `ShaderMask` compuesto sobre un
/// `ImageFiltered` (dos anidados no dibujan nada; uno solo dejaba el rectángulo
/// del halo en negro) así que el arte se pinta atenuado y listo. El precio es
/// que el corte exterior es recto en vez de degradado.
class AmbientGlow extends ConsumerWidget {
  const AmbientGlow({
    super.key,
    required this.imageUrl,
    this.opacity = 0.45,
    this.blurSigma = 48,
  });

  /// Cuánto se derrama el halo fuera de la tarjeta. Es el **único** valor de
  /// sangrado: el layout lo usa para posicionar la capa (`-AmbientGlow.bleed`) y
  /// aquí se usa para calcular el desvanecido, así ambos no se desincronizan.
  ///
  /// Coincide con el padding horizontal del watch (24 px) para que el degradado
  /// termine justo donde empieza el recorte del `SingleChildScrollView`.
  /// Cuánto sobresale el ambiente de la tarjeta. YouTube lo estira a
  /// `scale(1.5, 2)` (0,25× horizontal y 0,5× vertical del reproductor); con una
  /// tarjeta de ~823×458 eso son ~205 px a los lados y ~230 px arriba/abajo, así
  /// que 120 px es el primer paso para acercarse sin desbordar la columna.
  static const double bleed = 120;

  /// Arte del contenido (banner o póster).
  final String imageUrl;

  /// Intensidad final del halo.
  final double opacity;

  /// Radio del desenfoque aplicado al arte.
  final double blurSigma;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sin ShaderMask: en CanvasKit la máscara compuesta sobre un `ImageFiltered`
    // dejaba el rectángulo del halo en negro. Aquí solo se atenúa el arte.
    // Con frame del video disponible se usan sus colores en vez del arte.
    final AmbientFrame? frame = ref.watch(ambientVideoProvider);
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: frame != null
            ? LayoutBuilder(
                builder: (context, constraints) => AmbientVideoLayer(
                  frame: frame,
                  // Radio radial geométrico del APK (`rkd.b`): mitad del lado
                  // menor del vídeo, en dp.
                  radius: constraints.biggest.shortestSide / 2,
                ),
              )
            : AmbientArtImage(
                imageUrl: imageUrl,
                sigma: blurSigma,
                scale: 1.12,
              ),
      ),
    );
  }
}
