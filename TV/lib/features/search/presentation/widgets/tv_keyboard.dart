import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modo de teclado: `text` (búsqueda, comportamiento histórico) o `url`
/// (ingreso de URLs de listas M3U: añade las filas de símbolos :/ etc.).
enum TVKeyboardMode { text, url }

class TVKeyboard extends StatefulWidget {
  final Function(String) onKeyTap;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final String currentQuery;

  /// Filas de símbolos extra que se muestran solo en modo [TVKeyboardMode.url].
  final TVKeyboardMode mode;

  const TVKeyboard({
    super.key,
    required this.onKeyTap,
    required this.onBackspace,
    required this.onClear,
    required this.currentQuery,
    this.mode = TVKeyboardMode.text,
  });

  static const List<List<String>> keys = [
    ['a', 'b', 'c', 'd', 'e', 'f'],
    ['g', 'h', 'i', 'j', 'k', 'l'],
    ['m', 'n', 'o', 'p', 'q', 'r'],
    ['s', 't', 'u', 'v', 'w', 'x'],
    ['y', 'z', '1', '2', '3', '4'],
    ['5', '6', '7', '8', '9', '0'],
  ];

  /// Filas de símbolos de URL (solo modo url), misma rejilla de 6 columnas.
  static const List<List<String>> urlSymbolRows = [
    [':', '/', '.', '-', '_', '?'],
    ['&', '=', '%', '+', '#', '~'],
  ];

  @override
  State<TVKeyboard> createState() => _TVKeyboardState();
}

class _TVKeyboardState extends State<TVKeyboard> {
  /// Mayúsculas activas (toggle "Shift"). Arranca en minúsculas: el modo
  /// `text` conserva exactamente el comportamiento histórico.
  bool _shift = false;

  List<List<String>> get _rows {
    if (widget.mode == TVKeyboardMode.url) {
      return [...TVKeyboard.keys, ...TVKeyboard.urlSymbolRows];
    }
    return TVKeyboard.keys;
  }

  bool _isLetter(String key) {
    final code = key.codeUnitAt(0);
    return (code >= 97 && code <= 122) || (code >= 65 && code <= 90);
  }

  String _emit(String key) =>
      _shift && _isLetter(key) ? key.toUpperCase() : key;

  @override
  Widget build(BuildContext context) {
    final rows = _rows;

    return Container(
      width: 220,
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        color: Colors.black,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // FILA SUPERIOR: SHIFT, ESPACIO Y BORRAR
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _KeyboardKey(
                  label: '⇧',
                  onTap: () => setState(() => _shift = !_shift),
                  isAction: true,
                  isActive: _shift,
                  border: const Border(
                    right: BorderSide(color: Colors.black, width: 4),
                    bottom: BorderSide(color: Colors.black, width: 4),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: _KeyboardKey(
                  icon: Icons.space_bar_rounded, // Usamos icono oficial de espacio
                  onTap: () => widget.onKeyTap(' '),
                  isAction: true,
                  border: const Border(
                    right: BorderSide(color: Colors.black, width: 4),
                    bottom: BorderSide(color: Colors.black, width: 4),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: _KeyboardKey(
                  icon: Icons.backspace_outlined, // Usamos icono oficial de borrar
                  onTap: widget.onBackspace,
                  isAction: true,
                  border: const Border(
                    bottom: BorderSide(color: Colors.black, width: 4),
                  ),
                ),
              ),
            ],
          ),

          // CUADRÍCULA 6 columnas (6 filas en texto, 8 en URL)
          ...rows.asMap().entries.map((entry) {
            int rowIndex = entry.key;
            List<String> row = entry.value;
            bool isLastRow = rowIndex == rows.length - 1;

            return Row(
              children: row.asMap().entries.map((keyEntry) {
                int colIndex = keyEntry.key;
                String key = keyEntry.value;
                bool isLastCol = colIndex == row.length - 1;

                return Expanded(
                  child: _KeyboardKey(
                    label: _emit(key),
                    onTap: () => widget.onKeyTap(_emit(key)),
                    border: Border(
                      right: isLastCol ? BorderSide.none : const BorderSide(color: Colors.black, width: 4),
                      bottom: isLastRow ? BorderSide.none : const BorderSide(color: Colors.black, width: 4),
                    ),
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }
}

class _KeyboardKey extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final bool isAction;
  final Border border;

  /// Resaltado permanente (p. ej. Shift activo).
  final bool isActive;

  const _KeyboardKey({
    this.label,
    this.icon,
    required this.onTap,
    this.isAction = false,
    required this.border,
    this.isActive = false,
  });

  @override
  State<_KeyboardKey> createState() => _KeyboardKeyState();
}

class _KeyboardKeyState extends State<_KeyboardKey> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final bool highlighted = _isFocused || widget.isActive;

    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select) {
            widget.onTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: highlighted
                ? (widget.isActive && !_isFocused
                    ? const Color(0xFFEF7A1E)
                    : const Color(0xFFD9D9D9))
                : const Color(0xFF1E1E1E),
            border: widget.border,
          ),
          child: widget.icon != null
            ? (widget.icon == Icons.space_bar_rounded
                ? Container(
                    width: 36,
                    height: 8, // Reducido de 12 a 8 para que las líneas laterales sean más cortas
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: highlighted ? const Color(0xFF1A1A1A) : const Color(0xFF9A9A9A), width: 2),
                        bottom: BorderSide(color: highlighted ? const Color(0xFF1A1A1A) : const Color(0xFF9A9A9A), width: 2),
                        right: BorderSide(color: highlighted ? const Color(0xFF1A1A1A) : const Color(0xFF9A9A9A), width: 2),
                      ),
                    ),
                  )
                : Icon(
                    widget.icon,
                    size: 22,
                    color: highlighted ? const Color(0xFF1A1A1A) : const Color(0xFF9A9A9A),
                  ))
            : Text(
                widget.label ?? '',
                style: TextStyle(
                  color: highlighted ? const Color(0xFF1A1A1A) : const Color(0xFF9A9A9A),
                  fontSize: 16,
                  fontWeight: highlighted ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
        ),
      ),
    );
  }
}
