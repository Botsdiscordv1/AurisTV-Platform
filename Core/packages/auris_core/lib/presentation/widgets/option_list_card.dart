import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final Object? icon;
  final VoidCallback onTap;
  final bool isCurrent;
  final bool isAvailable;
  final bool autofocus;

  /// Nodo de foco externo opcional. Permite a la plataforma pedir el foco de
  /// una tarjeta concreta (p. ej. la opción actual al abrir un submenú del
  /// two-panel de TV), en vez de depender solo de [autofocus].
  final FocusNode? focusNode;

  final double titleSize;
  final double subtitleSize;
  final double iconSize;
  final double borderRadius;

  const AurisOptionCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
    required this.onTap,
    this.isCurrent = false,
    this.isAvailable = true,
    this.autofocus = false,
    this.focusNode,
    this.titleSize = 14,
    this.subtitleSize = 11,
    this.iconSize = 20,
    this.borderRadius = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      autofocus: autofocus,
      // El OK/select del mando de TV no tiene binding por defecto y el foco
      // vive en este Focus (no en el InkWell interno), así que la activación
      // por teclado se resuelve aquí, igual que en las pills de TV.
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.numpadEnter ||
              key == LogicalKeyboardKey.space) {
            if (isAvailable) onTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final bool isFocused = Focus.of(context).hasFocus;
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
            decoration: BoxDecoration(
              color: isFocused ? Colors.white : const Color(0xFF272727),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isAvailable ? onTap : null,
                // Sin lavado del focusColor del tema: el foco se dibuja aquí.
                focusColor: Colors.transparent,
                borderRadius: BorderRadius.circular(borderRadius),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      if (icon != null) ...[
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
                      ],
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
          );
        },
      ),
    );
  }
}
