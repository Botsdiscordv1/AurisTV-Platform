import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Frame del modo ambiente generado desde el video. `null` = todavía no hay
/// muestra y se usa el arte del contenido como respaldo.
final ambientVideoProvider = StateProvider<AmbientFrame?>((ref) => null);

/// Una imagen de ambiente con un número de secuencia, para que el crossfade sepa
/// cuándo cambió el frame aunque los bytes midan lo mismo.
class AmbientFrame {
  const AmbientFrame({required this.bytes, required this.sequence});

  final Uint8List bytes;
  final int sequence;
}

/// Escala del fondo de ambiente. En el APK (`kjv.f` → `kjw(2.0f, 2.0f)`) la
/// imagen de fondo se dibuja al doble del tamaño del vídeo en ambos ejes.
const double _kBackgroundScale = 2.0;

/// Pinta la imagen de ambiente del video.
///
/// Equivale al fondo cinemático de YouTube, con los valores medidos en el APK:
///  * el PNG viene del buffer diminuto (110×75), así que estirarlo ya da el
///    degradado suave de color, sin blur de píxeles;
///  * se escala 2,0× 2,0 sobre el recuadro del vídeo (`kjw(2.0f, 2.0f)`);
///  * el degradado es radial y geométrico: radio = mitad del lado menor del
///    vídeo, en dp (`rkd.b` + `afya.b`, que pasa px→dp y lo aplica con
///    `setGradientRadius`), en lugar del desenfoque fijo;
///  * cada frame nuevo entra con un crossfade de 2500 ms: `kjv.d` = 0,5 × el
///    intervalo de refresco, que es 5000 ms (`kjv.c`).
class AmbientVideoLayer extends StatelessWidget {
  const AmbientVideoLayer({
    super.key,
    required this.frame,
    this.radius,
    this.fadeDuration = const Duration(milliseconds: 2500),
  });

  final AmbientFrame frame;

  /// Radio del degradado radial en píxeles lógicos (dp): la mitad del lado menor
  /// del vídeo. `null` = sin máscara (se estira a toda la caja).
  final double? radius;

  final Duration fadeDuration;

  @override
  Widget build(BuildContext context) {
    Widget image = Image.memory(
      frame.bytes,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.fill,
      gaplessPlayback: true,
      filterQuality: FilterQuality.low,
      isAntiAlias: false,
    );

    // YouTube dibuja el fondo al doble de tamaño del vídeo, recortado a la caja.
    image = ClipRect(
      child: Transform.scale(scale: _kBackgroundScale, child: image),
    );

    final double? r = radius;
    if (r != null && r > 0) {
      image = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (Rect bounds) {
          final double shortest = bounds.shortestSide;
          // El radio del gradiente se mide como fracción del lado menor.
          final double fraction =
              shortest <= 0 ? 1.0 : (r / shortest).clamp(0.0, 1.0);
          return RadialGradient(
            radius: fraction,
            colors: const <Color>[
              Color(0xFFFFFFFF),
              Color(0xFFFFFFFF),
              Color(0x00FFFFFF),
            ],
            stops: const <double>[0.0, 0.45, 1.0],
          ).createShader(bounds);
        },
        child: image,
      );
    }

    return AnimatedSwitcher(
      duration: fadeDuration,
      switchInCurve: Curves.linear,
      switchOutCurve: Curves.linear,
      child: KeyedSubtree(
        key: ValueKey<int>(frame.sequence),
        child: image,
      ),
    );
  }
}
