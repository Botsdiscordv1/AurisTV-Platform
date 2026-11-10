import 'package:flutter/material.dart';

/// Sinopsis expandible para la WatchScreen.
///
/// Muestra las primeras 3 líneas de texto y ofrece el botón de interacción
/// `"VER MÁS"` / `"VER MENOS"` para desplegar la descripción completa.
class WatchSynopsis extends StatefulWidget {
  const WatchSynopsis({
    super.key,
    required this.synopsis,
    this.maxLines = 4,
  });

  final String synopsis;
  final int maxLines;

  @override
  State<WatchSynopsis> createState() => _WatchSynopsisState();
}

class _WatchSynopsisState extends State<WatchSynopsis> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.synopsis.isEmpty) return const SizedBox.shrink();

    final TextStyle style = TextStyle(
      color: Colors.white70,
      fontSize: 13.5,
      height: 1.5,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Medir si la sinopsis supera las 4 líneas
        final textSpan = TextSpan(text: widget.synopsis, style: style);
        final tp = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
          maxLines: widget.maxLines,
        );
        tp.layout(maxWidth: constraints.maxWidth);

        final bool hasOverflow = tp.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedCrossFade(
              firstChild: Text(
                widget.synopsis,
                maxLines: widget.maxLines,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
              secondChild: Text(
                widget.synopsis,
                style: style,
              ),
              crossFadeState: _isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
            if (hasOverflow) ...[
              const SizedBox(height: 6),
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    _isExpanded ? 'VER MENOS' : 'VER MÁS',
                    style: TextStyle(
                      color: const Color(0xFFEF7A1E), // Naranja AurisTV
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
