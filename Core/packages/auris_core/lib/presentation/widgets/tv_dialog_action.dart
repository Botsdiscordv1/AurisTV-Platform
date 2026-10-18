import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Botón de acción con foco visible para diálogos en TV: resalta con borde
/// blanco + glow y responde a ENTER/SELECT/ESPACIO del D-pad. Mantiene el
/// lenguaje visual de los botones de TV (ver `TVFocusWrapper` /
/// `_ExitConfirmationDialog`). No debe usarse en Móvil/Web.
class TvDialogAction extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final Color? background;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;

  /// Pide el foco al montarse (post-frame). Útil para el primer botón.
  final bool autofocus;

  /// Fuerza el texto en negrita (para el CTA sin fondo relleno).
  final bool bold;

  const TvDialogAction({
    super.key,
    required this.label,
    this.icon,
    required this.color,
    this.background,
    required this.onPressed,
    this.focusNode,
    this.autofocus = false,
    this.bold = false,
  });

  @override
  State<TvDialogAction> createState() => _TvDialogActionState();
}

class _TvDialogActionState extends State<TvDialogAction> {
  FocusNode? _owned;
  bool _focused = false;

  FocusNode get _node => widget.focusNode ?? (_owned ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocusChange);
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _node.canRequestFocus) _node.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _node.removeListener(_onFocusChange);
    _owned?.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (mounted) setState(() => _focused = _node.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;
    final bool primary = widget.background != null;
    final Color fg = enabled
        ? (_focused ? Colors.white : widget.color)
        : widget.color.withValues(alpha: 0.4);
    return Focus(
      focusNode: _node,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && enabled) {
          final LogicalKeyboardKey key = event.logicalKey;
          if (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.space) {
            widget.onPressed?.call();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: widget.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _focused ? Colors.white : Colors.transparent,
              width: 2,
            ),
            boxShadow: _focused
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.15),
                      blurRadius: 12,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: fg,
                  fontSize: 14,
                  fontWeight: (primary || widget.bold)
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
