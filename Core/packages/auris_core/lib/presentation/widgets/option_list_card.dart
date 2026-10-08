import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auris_icon.dart';

/// Fila de opción para los menús del panel lateral (TV / Móvil / Web).
///
/// Diseño unificado: icono directo SIN caja envolvente, título + subtítulo y
/// check/chevron a la derecha. Foco D-pad / mouse con el lenguaje Auris
/// (fondo blanco + texto negro).
///
/// [icon] acepta el nombre del icono Auris ([String]) o un [IconData].
class AurisOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Object icon;
  final VoidCallback onTap;
  final bool isCurrent;
  final bool isAvailable;
  final bool autofocus;

  final double titleSize;
  final double subtitleSize;
  final double iconSize;
  final double borderRadius;

  const AurisOptionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.isCurrent = false,
    this.isAvailable = true,
    this.autofocus = false,
    this.titleSize = 15,
    this.subtitleSize = 12,
    this.iconSize = 22,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: autofocus,
      child: Builder(
        builder: (context) {
          final bool isFocused = Focus.of(context).hasFocus;
          return AnimatedScale(
            scale: isFocused ? 1.02 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                color: isFocused ? Colors.white : const Color(0xFF272727),
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isAvailable ? onTap : null,
                  borderRadius: BorderRadius.circular(borderRadius),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        icon is String
                            ? AurisIcon(
                                icon as String,
                                color: isFocused
                                    ? Colors.black
                                    : (isAvailable ? Colors.white : Colors.white38),
                                size: iconSize,
                              )
                            : Icon(
                                icon as IconData?,
                                color: isFocused
                                    ? Colors.black
                                    : (isAvailable ? Colors.white : Colors.white38),
                                size: iconSize,
                              ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.poppins(
                                  color: isFocused
                                      ? Colors.black
                                      : (isAvailable ? Colors.white : Colors.white38),
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (subtitle.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  style: GoogleFonts.poppins(
                                    color: isFocused
                                        ? Colors.black54
                                        : (isAvailable ? Colors.white60 : Colors.white24),
                                    fontSize: subtitleSize,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (isCurrent)
                          Icon(
                            Icons.check_rounded,
                            color: isFocused ? Colors.black : Colors.white,
                            size: 22,
                          )
                        else
                          Icon(
                            Icons.chevron_right_rounded,
                            color: isFocused ? Colors.black54 : Colors.white30,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
