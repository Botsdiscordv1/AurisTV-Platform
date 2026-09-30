import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:auris_core/auris_core.dart';
import '../../settings/presentation/providers/settings_provider.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  final String profileId;
  const ProfileEditScreen({super.key, required this.profileId});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late TextEditingController _nameController;
  late FocusNode _avatarFocusNode;
  late FocusNode _nameFocusNode;
  late FocusNode _languageFocusNode;
  late FocusNode _qualityFocusNode;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<_TVMenuSelectorState> _languageMenuKey =
      GlobalKey<_TVMenuSelectorState>();
  final GlobalKey<_TVMenuSelectorState> _qualityMenuKey =
      GlobalKey<_TVMenuSelectorState>();
  bool _autoplayNextEpisode = true;
  bool _autoplayPreviews = true;
  bool _notificationsEnabled = true;
  String _selectedAudioLanguage = 'Español (Latinoamérica)';
  String _selectedQuality = 'auto';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _avatarFocusNode = FocusNode();
    _nameFocusNode = FocusNode();
    _languageFocusNode = FocusNode();
    _qualityFocusNode = FocusNode();

    _avatarFocusNode.addListener(() {
      if (_avatarFocusNode.hasFocus && mounted) {
        _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
      }
    });
    _nameFocusNode.addListener(() {
      if (_nameFocusNode.hasFocus && mounted) {
        _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
      }
    });
    _languageFocusNode.addListener(() {
      if (_languageFocusNode.hasFocus && mounted) {
        Scrollable.ensureVisible(context, alignment: 0.15, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
      }
    });
    _qualityFocusNode.addListener(() {
      if (_qualityFocusNode.hasFocus && mounted) {
        Scrollable.ensureVisible(context, alignment: 0.15, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider);
      final settings = ref.read(settingsProvider);
      if (user != null) {
        final profile = user.profiles.firstWhere(
          (p) => p.id == widget.profileId,
          orElse: () => user.profiles.first,
        );
        _nameController.text = profile.name;
      }
      setState(() {
        _autoplayNextEpisode = settings.autoPlayNextEpisode;
        _selectedQuality = settings.preferredQuality;
      });
      _avatarFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _avatarFocusNode.dispose();
    _nameFocusNode.dispose();
    _languageFocusNode.dispose();
    _qualityFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D24),
        title: const Text('¿Eliminar perfil?', style: TextStyle(color: Colors.white)),
        content: Text('Se perderá todo el historial y preferencias de $name.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () {
              ref.read(authProvider.notifier).deleteProfile(id);
              Navigator.pop(context);
              context.go('/select-profile');
            },
            child: const Text('ELIMINAR', style: TextStyle(color: Colors.redAccent))
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEF7A1E);
    const backgroundColor = Color(0xFF0B0B0D);
    const cardColor = Color(0xFF1A1D24);

    final user = ref.watch(authProvider);
    final profile = user?.profiles.firstWhere(
      (p) => p.id == widget.profileId,
      orElse: () => user.profiles.first,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Si un menú desplegable está abierto, BACK solo lo cierra y devuelve
        // el foco a su selector (en lugar de salir de la pantalla).
        final languageMenu = _languageMenuKey.currentState;
        if (languageMenu != null && languageMenu.isMenuOpen) {
          languageMenu.closeMenu();
          return;
        }
        final qualityMenu = _qualityMenuKey.currentState;
        if (qualityMenu != null && qualityMenu.isMenuOpen) {
          qualityMenu.closeMenu();
          return;
        }
        if (Navigator.canPop(context)) {
          context.pop();
        } else {
          context.go('/select-profile');
        }
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          title: const Text('Editar perfil', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          centerTitle: false,
        ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 140, vertical: 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Focus(
                        focusNode: _avatarFocusNode,
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent) {
                            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                              _nameFocusNode.requestFocus();
                              return KeyEventResult.handled;
                            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                              _languageFocusNode.requestFocus();
                              return KeyEventResult.handled;
                            } else if (event.logicalKey == LogicalKeyboardKey.select ||
                                       event.logicalKey == LogicalKeyboardKey.enter ||
                                       event.logicalKey == LogicalKeyboardKey.space) {
                              context.push('/settings/avatar');
                              return KeyEventResult.handled;
                            }
                          }
                          return KeyEventResult.ignored;
                        },
                        child: Builder(
                          builder: (context) {
                            final hasFocus = Focus.of(context).hasFocus;
                            return GestureDetector(
                              onTap: () => context.push('/settings/avatar'),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: hasFocus ? primaryColor : Colors.white24,
                                    width: hasFocus ? 3 : 2,
                                  ),
                                  boxShadow: hasFocus
                                      ? [BoxShadow(color: primaryColor.withValues(alpha: 0.4), blurRadius: 16, spreadRadius: 2)]
                                      : [],
                                ),
                                child: Stack(
                                  alignment: Alignment.bottomRight,
                                  children: [
                                    Container(
                                      width: 140,
                                      height: 140,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        image: (profile?.photoUrl != null)
                                            ? DecorationImage(
                                                image: profile!.photoUrl!.startsWith('assets/')
                                                    ? AssetImage(profile.photoUrl!) as ImageProvider
                                                    : CachedNetworkImageProvider(profile.photoUrl!),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                        color: cardColor,
                                      ),
                                      child: (profile?.photoUrl == null)
                                          ? const Icon(Icons.person_rounded, color: Colors.white70, size: 70)
                                          : null,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: primaryColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.edit, size: 16, color: Colors.black),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 50),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('NOMBRE', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 320,
                          child: Focus(
                            focusNode: _nameFocusNode,
                            onKeyEvent: (node, event) {
                              if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                FocusScope.of(context).focusInDirection(TraversalDirection.down);
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            },
                            child: Builder(
                              builder: (context) {
                                final hasFocus = Focus.of(context).hasFocus;
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.zero,
                                    border: Border.all(
                                      color: hasFocus ? primaryColor : Colors.white38,
                                      width: hasFocus ? 2.5 : 1.5,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _nameController,
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    onSubmitted: (_) {
                                      FocusScope.of(context).focusInDirection(TraversalDirection.down);
                                    },
                                    decoration: const InputDecoration(
                                      filled: true,
                                      fillColor: Color(0xFF22252A),
                                      hintText: 'Nombre del perfil',
                                      hintStyle: TextStyle(color: Colors.white38),
                                      contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.zero,
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.zero,
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.zero,
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const Divider(color: Colors.white24, height: 36),
                        const Text('PREFERENCIAS DE REPRODUCCIÓN', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        _SettingsShortcutButton(
                          focusNode: _languageFocusNode,
                          label: 'Configurar Calidad e Idioma en Ajustes',
                          onPressed: () => context.push('/settings'),
                        ),
                        const Divider(color: Colors.white24, height: 36),
                        const Text('CONTROLES DE REPRODUCCIÓN AUTOMÁTICA', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        const SizedBox(height: 12),
                        _TVCheckboxTile(
                          title: 'Reproducir siguiente episodio en una serie en todos los dispositivos.',
                          value: _autoplayNextEpisode,
                          onChanged: (v) => setState(() => _autoplayNextEpisode = v),
                        ),
                        const SizedBox(height: 8),
                        _TVCheckboxTile(
                          title: 'Reproducir avances automáticamente al navegar en todos los dispositivos.',
                          value: _autoplayPreviews,
                          onChanged: (v) => setState(() => _autoplayPreviews = v),
                        ),
                        const Divider(color: Colors.white24, height: 36),
                        const Text('NOTIFICACIONES', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        const SizedBox(height: 12),
                        _TVCheckboxTile(
                          title: 'Recibir noticias y notificaciones de próximos estrenos.',
                          value: _notificationsEnabled,
                          onChanged: (v) => setState(() => _notificationsEnabled = v),
                        ),
                        const SizedBox(height: 40),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            _FocusableButton(
                              label: 'GUARDAR',
                              isPrimary: true,
                              onPressed: () {
                                final newName = _nameController.text.trim();
                                if (newName.isNotEmpty && profile != null) {
                                  ref.read(authProvider.notifier).updateProfileName(newName);
                                }
                                ref.read(settingsProvider.notifier).setAutoPlayNextEpisode(_autoplayNextEpisode);
                                ref.read(settingsProvider.notifier).setPreferredQuality(_selectedQuality);
                                if (Navigator.canPop(context)) {
                                  context.pop();
                                } else {
                                  context.go('/select-profile');
                                }
                              },
                            ),
                            _FocusableButton(
                              label: 'CANCELAR',
                              isPrimary: false,
                              onPressed: () => context.pop(),
                            ),
                            if (profile != null)
                              _FocusableButton(
                                label: 'ELIMINAR',
                                isPrimary: false,
                                onPressed: () => _showDeleteConfirmation(context, ref, profile.id, profile.name),
                              ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TVMenuSelector extends StatefulWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;

  const _TVMenuSelector({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.focusNode,
  });

  @override
  State<_TVMenuSelector> createState() => _TVMenuSelectorState();
}

class _TVMenuSelectorState extends State<_TVMenuSelector> {
  bool _hasFocus = false;
  OverlayEntry? _overlayEntry;
  late FocusNode _buttonFocusNode;
  late FocusNode _firstOptionFocusNode;

  @override
  void initState() {
    super.initState();
    _buttonFocusNode = widget.focusNode ?? FocusNode();
    _firstOptionFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _closeMenu();
    if (widget.focusNode == null) {
      _buttonFocusNode.dispose();
    }
    _firstOptionFocusNode.dispose();
    super.dispose();
  }

  /// true si el menú desplegable está visible (usado por el PopScope de la pantalla).
  bool get isMenuOpen => _overlayEntry != null;

  /// Cierra el menú y devuelve el foco al botón del selector.
  void closeMenu() => _closeMenu();

  void _toggleMenu(BuildContext context) {
    if (_overlayEntry != null) {
      _closeMenu();
    } else {
      _openMenu(context);
    }
  }

  void _closeMenu() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _buttonFocusNode.canRequestFocus) {
          _buttonFocusNode.requestFocus();
        }
      });
    }
  }

  void _openMenu(BuildContext context) {
    if (_overlayEntry != null) return;
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          ModalBarrier(
            color: Colors.transparent,
            dismissible: true,
            onDismiss: _closeMenu,
          ),
          Positioned(
            left: offset.dx,
            top: offset.dy + size.height + 4,
            width: size.width > 250 ? size.width : 250,
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    (event.logicalKey == LogicalKeyboardKey.escape ||
                     event.logicalKey == LogicalKeyboardKey.goBack)) {
                  _closeMenu();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B0B0D),
                    borderRadius: BorderRadius.zero,
                    border: Border.all(color: Colors.white38, width: 1.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: widget.options.map((opt) {
                      final isFirst = opt == widget.options.first;
                      final isSelected = opt == widget.value;
                      return _TVSubMenuOption(
                        focusNode: isFirst ? _firstOptionFocusNode : null,
                        label: opt,
                        isSelected: isSelected,
                        onArrowUp: isFirst ? _closeMenu : null,
                        onBack: _closeMenu,
                        onTap: () {
                          _closeMenu();
                          widget.onChanged(opt);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_firstOptionFocusNode.canRequestFocus) {
        _firstOptionFocusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEF7A1E);
    return Focus(
      focusNode: _buttonFocusNode,
      onFocusChange: (hasFocus) => setState(() => _hasFocus = hasFocus),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space ||
              event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _toggleMenu(context);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          return GestureDetector(
            onTap: () => _toggleMenu(context),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 250,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF22252A),
                borderRadius: BorderRadius.zero,
                border: Border.all(
                  color: _hasFocus ? primaryColor : Colors.white38,
                  width: _hasFocus ? 2.5 : 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.value,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 22),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TVSubMenuOption extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onArrowUp;
  final VoidCallback? onBack;
  final FocusNode? focusNode;

  const _TVSubMenuOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.onArrowUp,
    this.onBack,
    this.focusNode,
  });

  @override
  State<_TVSubMenuOption> createState() => _TVSubMenuOptionState();
}

class _TVSubMenuOptionState extends State<_TVSubMenuOption> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEF7A1E);
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (hasFocus) => setState(() => _hasFocus = hasFocus),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (widget.onArrowUp != null && event.logicalKey == LogicalKeyboardKey.arrowUp) {
            widget.onArrowUp!();
            return KeyEventResult.handled;
          }
          if (widget.onBack != null &&
              (event.logicalKey == LogicalKeyboardKey.escape ||
               event.logicalKey == LogicalKeyboardKey.goBack)) {
            widget.onBack!();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space) {
            widget.onTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _hasFocus ? primaryColor.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: _hasFocus ? primaryColor : Colors.transparent,
              width: _hasFocus ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                widget.isSelected ? Icons.check_rounded : Icons.circle_outlined,
                color: _hasFocus ? primaryColor : (widget.isSelected ? Colors.white70 : Colors.transparent),
                size: 18,
              ),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: TextStyle(
                  color: _hasFocus ? Colors.white : Colors.white70,
                  fontSize: 15,
                  fontWeight: widget.isSelected || _hasFocus ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TVCheckboxTile extends StatefulWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _TVCheckboxTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_TVCheckboxTile> createState() => _TVCheckboxTileState();
}

class _TVCheckboxTileState extends State<_TVCheckboxTile> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEF7A1E);
    return Focus(
      onFocusChange: (hasFocus) {
        setState(() => _hasFocus = hasFocus);
        if (hasFocus && mounted) {
          Scrollable.ensureVisible(context, alignment: 0.15, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
        }
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onChanged(!widget.value);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () => widget.onChanged(!widget.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: _hasFocus ? primaryColor : Colors.transparent,
              width: 2.0,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: widget.value ? primaryColor : Colors.white60, width: 2),
                  color: widget.value ? primaryColor : Colors.transparent,
                ),
                child: widget.value
                    ? const Icon(Icons.check, size: 16, color: Colors.black)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w400),
                ),
              ),
            ],
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
      onFocusChange: (hasFocus) {
        setState(() => _hasFocus = hasFocus);
        if (hasFocus && mounted) {
          Scrollable.ensureVisible(context, alignment: 0.15, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
        }
      },
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
          width: 140,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: widget.isPrimary
                ? (_hasFocus ? Colors.white : primaryColor)
                : Colors.transparent,
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: _hasFocus ? (widget.isPrimary ? Colors.white : primaryColor) : Colors.white38,
              width: 2.0,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.isPrimary ? Colors.black : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsShortcutButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final FocusNode? focusNode;

  const _SettingsShortcutButton({
    required this.label,
    required this.onPressed,
    this.focusNode,
  });

  @override
  State<_SettingsShortcutButton> createState() => _SettingsShortcutButtonState();
}

class _SettingsShortcutButtonState extends State<_SettingsShortcutButton> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEF7A1E);

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (hasFocus) {
        setState(() => _hasFocus = hasFocus);
        if (hasFocus && mounted) {
          Scrollable.ensureVisible(context, alignment: 0.15, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
        }
      },
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
          width: 380,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: _hasFocus ? primaryColor : Colors.white38,
              width: 2.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
