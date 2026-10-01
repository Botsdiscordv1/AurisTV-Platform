import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:auris_core/auris_core.dart';

class ProfileAddScreen extends ConsumerStatefulWidget {
  const ProfileAddScreen({super.key});

  @override
  ConsumerState<ProfileAddScreen> createState() => _ProfileAddScreenState();
}

class _ProfileAddScreenState extends ConsumerState<ProfileAddScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEF7A1E);
    const backgroundColor = Color(0xFF0B0B0D);
    const cardColor = Color(0xFF1A1D24);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: AurisIcon(AurisIcons.chevronLeft, color: Colors.white, size: 24),
          onPressed: () => context.pop(),
        ),
        title: const Text('Editar perfil', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Circular avatar (más compacto, igual que la referencia)
                Container(
                  width: 95,
                  height: 95,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 2.5),
                    color: cardColor,
                  ),
                  child: AurisIcon(AurisIcons.user, color: Colors.white70, size: 50),
                ),
                const SizedBox(height: 32),

                // Name input field con soporte D-pad Down envuelto en Focus
                Focus(
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      FocusScope.of(context).focusInDirection(TraversalDirection.down);
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF16181D),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white38, width: 1.5),
                    ),
                    child: TextField(
                      controller: _nameController,
                      textAlign: TextAlign.center,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      onSubmitted: (_) {
                        FocusScope.of(context).focusInDirection(TraversalDirection.down);
                      },
                      decoration: const InputDecoration(
                        hintText: 'Nombre del perfil',
                        hintStyle: TextStyle(color: Colors.white38),
                        contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // Action buttons: Cancelar & Guardar cambios más compactos
                Row(
                  children: [
                    Expanded(
                      child: _FocusableButton(
                        label: 'Cancelar',
                        isPrimary: false,
                        onPressed: () => context.pop(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _FocusableButton(
                        label: 'Guardar cambios',
                        isPrimary: true,
                        onPressed: () {
                          final name = _nameController.text.trim();
                          if (name.isNotEmpty) {
                            ref.read(authProvider.notifier).addProfile(name, null);
                            context.pop();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FocusableButton extends StatefulWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onPressed;

  const _FocusableButton({
    required this.label,
    required this.isPrimary,
    required this.onPressed,
  });

  @override
  State<_FocusableButton> createState() => _FocusableButtonState();
}

class _FocusableButtonState extends State<_FocusableButton> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEF7A1E);
    return Focus(
      onFocusChange: (hasFocus) => setState(() => _hasFocus = hasFocus),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: widget.isPrimary
                ? (_hasFocus ? Colors.white : primaryColor)
                : (_hasFocus ? Colors.white24 : const Color(0xFF22252A)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hasFocus ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.isPrimary ? Colors.black : Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
