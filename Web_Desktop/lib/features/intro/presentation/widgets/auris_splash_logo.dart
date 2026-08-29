// auris_splash_logo.dart
//
// Requiere el paquete flutter_svg:
//   flutter pub add flutter_svg
//
// Coloca estos dos archivos en tu carpeta de assets (ej. assets/branding/)
// y regístralos en pubspec.yaml:
//   flutter:
//     assets:
//       - assets/branding/logo_icon.svg
//       - assets/branding/logo_wordmark.svg
//
// Uso:
//   AurisSplashLogo(onFinished: () => Navigator.pushReplacement(...))

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AurisSplashLogo extends StatefulWidget {
  final VoidCallback? onFinished;
  final String iconAsset;
  final String wordmarkAsset;

  const AurisSplashLogo({
    super.key,
    this.onFinished,
    this.iconAsset = 'assets/branding/logo_icon.svg',
    this.wordmarkAsset = 'assets/branding/logo_wordmark.svg',
  });

  @override
  State<AurisSplashLogo> createState() => _AurisSplashLogoState();
}

class _AurisSplashLogoState extends State<AurisSplashLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Intervalos calcados de la referencia (~2.7s en total)
  late final Animation<double> _streaks = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.41, curve: Curves.easeOut),
  );
  late final Animation<double> _flash = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.31, 0.65, curve: Curves.easeOut),
  );
  late final Animation<double> _icon = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.33, 0.63, curve: Curves.elasticOut),
  );
  late final Animation<double> _wordmark = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.5, 0.72, curve: Curves.easeOutBack),
  );
  late final Animation<double> _shine = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.76, 1.0, curve: Curves.easeIn),
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2700),
    )..forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFinished?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return SizedBox(
          width: 320,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Trazos de energía naranja convergiendo hacia el ícono
              Positioned(
                left: -6,
                child: Opacity(
                  opacity: (1 - _streaks.value).clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: _streaks.value * 4.2,
                    child: Transform.scale(
                      scale: 1.6 - (1.45 * _streaks.value),
                      child: CustomPaint(
                        size: const Size(90, 90),
                        painter: _StreaksPainter(),
                      ),
                    ),
                  ),
                ),
              ),

              // Destello blanco en el momento del "impacto"
              Positioned(
                left: 28,
                child: Opacity(
                  opacity: (_flash.value < 0.35
                          ? (_flash.value / 0.35)
                          : (1 - _flash.value) / 0.65)
                      .clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 1 + _flash.value * 11,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),

              // Ícono + wordmark
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Transform.scale(
                    scale: _icon.value.clamp(0.0, 1.15),
                    child: Opacity(
                      opacity: _icon.value.clamp(0.0, 1.0),
                      child: SvgPicture.asset(
                        widget.iconAsset,
                        width: 70,
                        height: 70,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Transform.translate(
                    offset: Offset(
                      0,
                      -14 * (1 - _wordmark.value).clamp(0.0, 1.0),
                    ),
                    child: Transform.scale(
                      scale: 0.9 + 0.1 * _wordmark.value.clamp(0.0, 1.0),
                      child: Opacity(
                        opacity: _wordmark.value.clamp(0.0, 1.0),
                        child: ShaderMask(
                          blendMode: BlendMode.srcATop,
                          shaderCallback: (bounds) {
                            final t = _shine.value;
                            return LinearGradient(
                              begin: Alignment(-1.6 + t * 3.2, 0),
                              end: Alignment(-1.0 + t * 3.2, 0),
                              colors: const [
                                Colors.transparent,
                                Colors.white,
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ).createShader(bounds);
                          },
                          child: SvgPicture.asset(
                            widget.wordmarkAsset,
                            height: 46,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StreaksPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final colors = [
      const Color(0xFFEF7A1E),
      const Color(0xFFFFB066),
      const Color(0xFFEF7A1E),
      const Color(0xFFFFB066),
    ];

    for (var i = 0; i < 4; i++) {
      paint.color = colors[i].withOpacity(0.85);
      final startAngle = (math.pi / 2) * i - math.pi / 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        math.pi / 2,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
