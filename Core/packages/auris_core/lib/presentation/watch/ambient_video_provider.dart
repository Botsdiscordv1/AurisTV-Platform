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

/// Pinta la imagen de ambiente del video. El PNG ya viene con la máscara radial
/// horneada y con la resolución diminuta del buffer de YouTube (110×75), así que
/// basta estirarlo: el propio escalado da el degradado suave.
///
/// Cada frame nuevo entra con un crossfade encima del anterior, que es el
/// movimiento que se percibe en el modo ambiente de YouTube (allí son dos
/// `<canvas>` alternándose con la opacidad animada por JS).
class AmbientVideoLayer extends StatelessWidget {
  const AmbientVideoLayer({
    super.key,
    required this.frame,
    // YouTube sube la opacidad del canvas nuevo de 0 a 1 en ~2,7 s (lineal). Acá
    // se acorta para que acompañe el refresco de 2 s sin quedar atrasado.
    this.fadeDuration = const Duration(milliseconds: 1200),
  });

  final AmbientFrame frame;
  final Duration fadeDuration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: fadeDuration,
      switchInCurve: Curves.linear,
      switchOutCurve: Curves.linear,
      // `width`/`height` infinitos para que el PNG se estire a toda la caja: sin
      // eso el widget toma el tamaño intrínseco del buffer (110×75).
      child: Image.memory(
        frame.bytes,
        key: ValueKey<int>(frame.sequence),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.fill,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
        isAntiAlias: false,
      ),
    );
  }
}
