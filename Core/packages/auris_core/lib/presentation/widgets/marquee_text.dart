import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Reloj global que sincroniza las animaciones de marquee.
///
/// El ticker solo corre mientras haya al menos un [MarqueeText] activo
/// animando: cada marquee llama a [acquire] al montarse y [release] al
/// desmontarse. Cuando nadie anima, el ticker se detiene (cero coste en
/// reposo, sin consumo de CPU/batería).
class MarqueeSyncController extends ChangeNotifier {
  static final MarqueeSyncController instance = MarqueeSyncController._();
  MarqueeSyncController._();

  Ticker? _ticker;
  Duration _elapsed = Duration.zero;
  int _active = 0;

  Duration get elapsed => _elapsed;

  void acquire() {
    _active++;
    _ticker ??= Ticker((elapsed) {
      _elapsed = elapsed;
      // Si nadie está escuchando (p.ej. el texto ahora cabe y no se dibuja
      // un AnimatedBuilder), evitamos notificar sin destinatarios.
      if (hasListeners) notifyListeners();
    });
    if (!_ticker!.isActive) {
      _elapsed = Duration.zero;
      _ticker!.start();
    }
  }

  void release() {
    if (_active > 0) _active--;
    if (_active == 0 && _ticker != null && _ticker!.isActive) {
      _ticker!.stop();
      _elapsed = Duration.zero;
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }
}

/// Texto con autoscroll horizontal (marquee).
///
/// - Si [animate] es false o el texto cabe en el ancho disponible, se muestra
///   como texto plano con elipsis (sin animación ni trabajo por frame).
/// - Si el texto desborda y [animate] es true, se desliza en bucle infinito,
///   sincronizado globalmente por [MarqueeSyncController].
class MarqueeText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final double blankSpace;
  final double velocity;
  final bool animate;

  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    this.blankSpace = 50.0,
    this.velocity = 35.0,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();

        final textWidth = textPainter.width;
        final maxWidth = constraints.maxWidth;

        if (!animate || textWidth <= maxWidth) {
          return SizedBox(
            height: textPainter.height,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          );
        }

        return _AnimatedMarquee(
          text: text,
          style: style,
          blankSpace: blankSpace,
          velocity: velocity,
          maxWidth: maxWidth,
          textWidth: textWidth,
          height: textPainter.height,
        );
      },
    );
  }
}

class _AnimatedMarquee extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double blankSpace;
  final double velocity;
  final double maxWidth;
  final double textWidth;
  final double height;

  const _AnimatedMarquee({
    required this.text,
    required this.style,
    required this.blankSpace,
    required this.velocity,
    required this.maxWidth,
    required this.textWidth,
    required this.height,
  });

  @override
  State<_AnimatedMarquee> createState() => _AnimatedMarqueeState();
}

class _AnimatedMarqueeState extends State<_AnimatedMarquee> {
  @override
  void initState() {
    super.initState();
    MarqueeSyncController.instance.acquire();
  }

  @override
  void dispose() {
    MarqueeSyncController.instance.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loopDistance = widget.textWidth + widget.blankSpace;

    return AnimatedBuilder(
      animation: MarqueeSyncController.instance,
      builder: (context, _) {
        final elapsedMs = MarqueeSyncController.instance.elapsed.inMilliseconds;
        // Cálculo matemático del offset para un bucle infinito perfecto
        final double offset = (elapsedMs / 1000.0 * widget.velocity) % loopDistance;

        return ClipRect(
          child: SizedBox(
            width: widget.maxWidth,
            height: widget.height,
            child: OverflowBox(
              maxWidth: double.infinity,
              alignment: Alignment.centerLeft,
              child: Transform.translate(
                offset: Offset(-offset, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(widget.text, style: widget.style),
                    SizedBox(width: widget.blankSpace),
                    Text(widget.text, style: widget.style),
                    SizedBox(width: widget.blankSpace),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
