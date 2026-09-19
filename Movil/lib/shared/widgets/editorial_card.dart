import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:auris_core/auris_core.dart';
import '../../core/theme/editorial_themes.dart';
import '../../core/utils/responsive_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';

const String _mythicCornerSvg = r'''
<svg width="74" height="74" viewBox="0 0 74 74" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M443.85.1h418.2c.95 0 2.07-.35 2.82.2.83.61.31 1.8.44 2.72 1.21 8.17 5.47 14.08 13 17.57 2.43 1.13 5.03 1.56 7.67 1.82 1.3.12 1.3.13 1.36 1.37.02.48 0 .96 0 1.44V381.8q-.02 1.77-1.71 1.94c-5.57.57-10.45 2.59-14.36 6.72-3.48 3.67-5.46 8-5.98 13.01-.16 1.48-.14 1.49-1.58 1.53-.48.01-.96 0-1.44 0-278.98 0-557.97 0-836.95-.01-.88 0-1.91.34-2.62-.25-.68-.56-.36-1.59-.5-2.39-1.18-6.95-4.78-12.21-10.85-15.77-3.01-1.77-6.34-2.53-9.78-2.84-1.45-.13-1.46-.11-1.5-1.6-.01-.48 0-.96 0-1.44 0-118.44 0-236.88.01-355.32 0-.88-.34-1.91.25-2.63.57-.7 1.59-.3 2.4-.41 4.19-.56 8.06-1.91 11.38-4.6 5.04-4.07 7.8-9.34 8.26-15.8.13-1.81.08-1.81 1.81-1.83h419.64Zm.02 402.85h417.3c2.03 0 2.03-.01 2.45-2 2.02-9.75 9.89-17.43 19.68-18.87 2.5-.37 2.2-.72 2.22-2.7V27.31c0-.48.01-.96 0-1.44-.05-1.44-.08-1.48-1.51-1.66-10.36-1.32-18.57-9.18-20.48-19.51-.49-2.64.15-2.51-3.02-2.51H27.17c-2.65 0-2.53-.41-3.06 2.51-1.83 10.05-9.51 17.65-19.56 19.41q-2.38.42-2.38 2.81V379c0 .48-.01.96 0 1.44.05 1.36.05 1.36 1.41 1.51 9.52 1.1 17.76 8.36 20.14 17.71.26 1.03.05 2.35.94 3.01.93.68 2.22.28 3.35.28 138.62.01 277.24.01 415.86.01Z" fill="white"/>
<path d="M3.31 9.25c0-1.68.02-3.36 0-5.03-.01-.82.31-1.21 1.16-1.21 3.48.02 6.95 0 10.43.01.81 0 1.04.42.87 1.17-1.37 6.13-5.46 10.08-11.24 11.25-.98.2-1.18.05-1.2-.98-.04-1.74-.01-3.48-.01-5.21ZM6.64 44.79V31.28c0-2.32.17-2.51 2.36-3.11 4.09-1.11 7.94-2.73 11.27-5.43 4.21-3.41 6.63-7.83 7.54-13.11.33-1.88.64-2.26 2.55-2.26 8.65-.01 17.3 0 25.95 0h.36c.61.04 1.35.04 1.31.86-.04.8-.79.76-1.39.79-.42.02-.84 0-1.26 0H41.27c-2.46 0-2.4.01-2.77 2.41-.94 6.03-3.48 11.34-7.56 15.86-4.93 5.47-11.2 8.76-18.14 10.91-.8.25-1.61.5-2.43.68-2.55.56-2.07.8-2.07 2.77-.02 5.59 0 11.17 0 16.76 0 .42 0 .84-.01 1.26-.02.49-.08 1.03-.73 1.04-.59 0-.8-.48-.86-.98-.06-.47-.05-.96-.05-1.44V44.78ZM33.42 9.03c-.78 0-1.56-.02-2.34 0-1.57.03-1.59.07-1.86 1.55-1.02 5.63-3.91 10.14-8.36 13.65-3.29 2.6-7.07 4.27-11.12 5.33-1.42.37-1.43.4-1.45 1.8-.02 1.5-.02 3 0 4.5.02 1.83.1 1.9 1.83 1.46 4.15-1.05 8.12-2.57 11.82-4.74 5.47-3.2 9.76-7.51 12.51-13.28 1.36-2.84 2.18-5.83 2.6-8.94.15-1.07-.02-1.27-1.11-1.32-.84-.04-1.68 0-2.52 0Z" fill="white"/>
</svg>
''';

class EditorialCard extends StatefulWidget {
  final MediaItem media;
  final EditorialBadge badge;
  final VoidCallback onTap;
  final double width;
  final double height;
  final bool showInfo;

  const EditorialCard({
    super.key,
    required this.media,
    required this.badge,
    required this.onTap,
    this.width = 220,
    this.height = 330,
    this.showInfo = true,
  });

  @override
  State<EditorialCard> createState() => _EditorialCardState();
}

class _EditorialCardState extends State<EditorialCard> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _mythicController;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();

    _mythicController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    _mythicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = EditorialBadgeTheme.getTheme(widget.badge);
    const darkBg = Color(0xFF0A0A0F);
    final isMobile = ResponsiveUtils.isMobile(context);
    final isMythical = widget.badge == EditorialBadge.mythical;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: widget.width,
                height: widget.height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: theme.primary.withOpacity(_isHovered ? 0.35 : 0.15),
                      blurRadius: _isHovered ? 30 : 15,
                      spreadRadius: _isHovered ? 2 : 0,
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Fondo Negro Base
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: darkBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.primary.withOpacity(0.3),
                            width: 1.0,
                          ),
                        ),
                      ),
                    ),

                    // 2. Marco de Contorno Interno (Sutil)
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(3.0),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withOpacity(0.05),
                              width: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),

                    // 3. Imagen del Poster
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: widget.media.posterUrl,
                                fit: BoxFit.cover,
                                memCacheWidth: (widget.width * 2).toInt(),
                                placeholder: (context, url) => Container(color: Colors.white10),
                              ),
                              
                              // Efectos de rareza diferenciados (Estilo Netflix/Crunchyroll Premium)
                              Positioned.fill(
                                child: AnimatedBuilder(
                                  animation: Listenable.merge([_shimmerController, _pulseController]),
                                  builder: (context, _) {
                                    // 1. Efecto MÍTICO ("Títulos inolvidables"): Barrido de luz dorado lento
                                    if (widget.badge == EditorialBadge.mythical) {
                                      return IgnorePointer(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: theme.shimmerColors,
                                              stops: [
                                                (_shimmerController.value - 0.1).clamp(0.0, 1.0),
                                                _shimmerController.value.clamp(0.0, 1.0),
                                                (_shimmerController.value + 0.1).clamp(0.0, 1.0),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    
                                    // 2. Efecto OBRA MAESTRA: Brillo respiratorio (Aura) sutil y estático
                                    if (widget.badge == EditorialBadge.masterpiece) {
                                      return IgnorePointer(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: RadialGradient(
                                              center: const Alignment(0.7, -0.8), // Luz desde la esquina superior derecha
                                              radius: 1.2,
                                              colors: [
                                                theme.primary.withOpacity(0.08 * (1.0 + _pulseController.value * 0.5)),
                                                Colors.transparent,
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    // 3. Hover para otras categorías (Barrido sutil al interactuar)
                                    if (_isHovered) {
                                      return IgnorePointer(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Colors.white.withOpacity(0.0),
                                                Colors.white.withOpacity(0.1),
                                                Colors.white.withOpacity(0.0),
                                              ],
                                              stops: [
                                                (_shimmerController.value - 0.1).clamp(0.0, 1.0),
                                                _shimmerController.value.clamp(0.0, 1.0),
                                                (_shimmerController.value + 0.1).clamp(0.0, 1.0),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    return const SizedBox.shrink();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 4. BORDE Y ESQUINAS MÍTICAS (Estilo Aniyae) o ARCOS TRIPLES
                    if (isMythical) ...[
                      // Borde Animado que conecta las esquinas
                      Positioned.fill(
                        child: _MythicBorder(animation: _mythicController, primaryColor: theme.primary),
                      ),
                      _MythicCorner(alignment: Alignment.topLeft, animation: _mythicController, primaryColor: theme.primary),
                      _MythicCorner(alignment: Alignment.topRight, animation: _mythicController, primaryColor: theme.primary),
                      _MythicCorner(alignment: Alignment.bottomLeft, animation: _mythicController, primaryColor: theme.primary),
                      _MythicCorner(alignment: Alignment.bottomRight, animation: _mythicController, primaryColor: theme.primary),
                    ] else
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: TripleArcCornerPainter(color: theme.primary),
                          ),
                        ),
                      ),

                    // 5. BRILLO DE PULSAR (Efecto luz, no punto sólido)
                    if (!isMythical) ...[
                      _CornerPulsar(alignment: Alignment.topLeft, animation: _pulseController, color: theme.primary),
                      _CornerPulsar(alignment: Alignment.topRight, animation: _pulseController, color: theme.primary),
                      _CornerPulsar(alignment: Alignment.bottomLeft, animation: _pulseController, color: theme.primary),
                      _CornerPulsar(alignment: Alignment.bottomRight, animation: _pulseController, color: theme.primary),
                    ],
                  ],
                ),
              ),
              if (widget.showInfo) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: MarqueeText(
                    text: widget.media.title,
                    animate: isMobile ? true : _isHovered,
                    style: TextStyle(
                      color: _isHovered ? Colors.white : Colors.white.withOpacity(0.9),
                      fontSize: isMobile ? 12 : 15,
                      fontWeight: _isHovered ? FontWeight.w900 : FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                ),
                // Metadatos (Puntuación)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 1, 4, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 9),
                      const SizedBox(width: 4),
                      Text(
                        formatRating(widget.media.rating) ?? '0.0',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: isMobile ? 10 : 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MythicCorner extends StatelessWidget {
  final Alignment alignment;
  final Animation<double> animation;
  final Color primaryColor;

  const _MythicCorner({
    required this.alignment,
    required this.animation,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    int quarterTurns = 0;
    if (alignment == Alignment.topRight) quarterTurns = 1;
    else if (alignment == Alignment.bottomRight) quarterTurns = 2;
    else if (alignment == Alignment.bottomLeft) quarterTurns = 3;

    return Align(
      alignment: alignment,
      child: RotatedBox(
        quarterTurns: quarterTurns,
        child: SizedBox(
          width: 54, 
          height: 54,
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              return ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF6C32FF), // Púrpura
                      const Color(0xFF00FFC3), // Cian
                      const Color(0xFF6C32FF), // Púrpura
                      const Color(0xFF00FFC3), // Cian
                      const Color(0xFF6C32FF), // Púrpura (loop)
                    ],
                    stops: [
                      0.0,
                      (animation.value - 0.2).clamp(0.0, 1.0),
                      animation.value,
                      (animation.value + 0.2).clamp(0.0, 1.0),
                      1.0,
                    ],
                  ).createShader(bounds);
                },
                child: SvgPicture.string(
                  _mythicCornerSvg,
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MythicBorder extends StatelessWidget {
  final Animation<double> animation;
  final Color primaryColor;

  const _MythicBorder({required this.animation, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF6C32FF), // Púrpura
                const Color(0xFF00FFC3), // Cian
                const Color(0xFF6C32FF), // Púrpura
                const Color(0xFF00FFC3), // Cian
                const Color(0xFF6C32FF), // Púrpura
              ],
              stops: [
                0.0,
                (animation.value - 0.2).clamp(0.0, 1.0),
                animation.value,
                (animation.value + 0.2).clamp(0.0, 1.0),
                1.0,
              ],
            ).createShader(bounds);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white, width: 1.2),
            ),
          ),
        );
      },
    );
  }
}

class TripleArcCornerPainter extends CustomPainter {
  final Color color;
  TripleArcCornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    void drawTripleArc(Offset corner, double startAngle) {
      final Rect rect1 = Rect.fromCircle(center: corner, radius: 6);
      final Rect rect2 = Rect.fromCircle(center: corner, radius: 12);
      final Rect rect3 = Rect.fromCircle(center: corner, radius: 18);

      canvas.drawArc(rect1, startAngle, 1.57, false, paint);
      canvas.drawArc(rect2, startAngle, 1.57, false, paint);
      canvas.drawArc(rect3, startAngle, 1.57, false, paint);
    }

    drawTripleArc(Offset.zero, 0);
    drawTripleArc(Offset(size.width, 0), 1.57);
    drawTripleArc(Offset(0, size.height), 4.71);
    drawTripleArc(Offset(size.width, size.height), 3.14);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CornerPulsar extends StatelessWidget {
  final Alignment alignment;
  final Animation<double> animation;
  final Color color;
  const _CornerPulsar({required this.alignment, required this.animation, required this.color});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final double size = 12 + (animation.value * 12);
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withOpacity(0.8 * (1 - animation.value)),
                  color.withOpacity(0.4 * (1 - animation.value)),
                  Colors.transparent,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
