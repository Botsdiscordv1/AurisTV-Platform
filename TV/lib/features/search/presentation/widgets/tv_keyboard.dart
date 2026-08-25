import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TVKeyboard extends StatelessWidget {
  final Function(String) onKeyTap;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final String currentQuery;

  const TVKeyboard({
    super.key,
    required this.onKeyTap,
    required this.onBackspace,
    required this.onClear,
    required this.currentQuery,
  });

  static const List<List<String>> keys = [
    ['a', 'b', 'c', 'd', 'e', 'f'],
    ['g', 'h', 'i', 'j', 'k', 'l'],
    ['m', 'n', 'o', 'p', 'q', 'r'],
    ['s', 't', 'u', 'v', 'w', 'x'],
    ['y', 'z', '1', '2', '3', '4'],
    ['5', '6', '7', '8', '9', '0'],
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        color: Colors.black,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // FILA SUPERIOR: ESPACIO Y BORRAR
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _KeyboardKey(
                  icon: Icons.space_bar_rounded, // Usamos icono oficial de espacio
                  onTap: () => onKeyTap(' '),
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
                  onTap: onBackspace,
                  isAction: true,
                  border: const Border(
                    bottom: BorderSide(color: Colors.black, width: 4),
                  ),
                ),
              ),
            ],
          ),
          
          // CUADRÍCULA 6x6
          ...keys.asMap().entries.map((entry) {
            int rowIndex = entry.key;
            List<String> row = entry.value;
            bool isLastRow = rowIndex == keys.length - 1;

            return Row(
              children: row.asMap().entries.map((keyEntry) {
                int colIndex = keyEntry.key;
                String key = keyEntry.value;
                bool isLastCol = colIndex == row.length - 1;

                return Expanded(
                  child: _KeyboardKey(
                    label: key,
                    onTap: () => onKeyTap(key),
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

  const _KeyboardKey({
    this.label,
    this.icon,
    required this.onTap,
    this.isAction = false,
    required this.border,
  });

  @override
  State<_KeyboardKey> createState() => _KeyboardKeyState();
}

class _KeyboardKeyState extends State<_KeyboardKey> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
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
            color: _isFocused 
                ? const Color(0xFFD9D9D9)
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
                        left: BorderSide(color: _isFocused ? const Color(0xFF1A1A1A) : const Color(0xFF9A9A9A), width: 2),
                        bottom: BorderSide(color: _isFocused ? const Color(0xFF1A1A1A) : const Color(0xFF9A9A9A), width: 2),
                        right: BorderSide(color: _isFocused ? const Color(0xFF1A1A1A) : const Color(0xFF9A9A9A), width: 2),
                      ),
                    ),
                  )
                : Icon(
                    widget.icon,
                    size: 22,
                    color: _isFocused ? const Color(0xFF1A1A1A) : const Color(0xFF9A9A9A),
                  ))
            : Text(
                widget.label ?? '',
                style: TextStyle(
                  color: _isFocused ? const Color(0xFF1A1A1A) : const Color(0xFF9A9A9A),
                  fontSize: 16,
                  fontWeight: _isFocused ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
        ),
      ),
    );
  }
}
