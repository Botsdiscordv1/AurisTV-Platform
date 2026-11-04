import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:auris_core/auris_core.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Netflix TV "Edit Profile" Screen — 100% Pixel-Perfect Clone (Netflix Ninja TV)
//
// Key Specifications:
//  • Canvas: Pitch Black (#000000)
//  • Header: "EDITAR PERFIL" in NetflixSans Bold 34sp, white, -0.4 letterSpacing
//  • Avatar Tile: 118×118dp, 6.0dp corner radius, 3dp white border on focus,
//    with subtle circular dark pencil overlay. Enter navigates to /settings/avatar
//  • Name Field: 46dp height, dark #222222, 2.5dp white border on focus,
//    NetflixSans 16sp Bold white text
//  • Section Headers: "NOMBRE", "IDIOMA", "CONTROLES DE REPRODUCCIÓN AUTOMÁTICA"
//    in NetflixSans 12sp Bold, #808080, 1.2 letterSpacing
//  • TV Checkboxes: Square 20×20dp (3dp radius), solid white fill with black
//    check when checked; 2dp white focus border around row
//  • Action Buttons: [ GUARDAR ], [ CANCELAR ], [ ELIMINAR PERFIL ]
//    Outlined pills that turn solid white (or red) on focus with black bold text
//  • D-pad Traversal: Gapless remote navigation (Left/Right, Up/Down)
// ─────────────────────────────────────────────────────────────────────────────

class ProfileEditScreen extends ConsumerStatefulWidget {
  final String profileId;
  const ProfileEditScreen({super.key, required this.profileId});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late TextEditingController _nameController;
  final ScrollController _scrollController = ScrollController();

  // Focus nodes for D-pad navigation
  final FocusNode _avatarFocusNode = FocusNode();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _languageFocusNode = FocusNode();
  final FocusNode _autoplayNextFocusNode = FocusNode();
  final FocusNode _autoplayPreviewsFocusNode = FocusNode();
  final FocusNode _saveFocusNode = FocusNode();
  final FocusNode _cancelFocusNode = FocusNode();
  final FocusNode _deleteFocusNode = FocusNode();

  bool _autoplayNextEpisode = true;
  bool _autoplayPreviews = true;
  String _selectedLanguage = 'Español (Latinoamérica)';
  final List<String> _languages = const [
    'Español (Latinoamérica)',
    'Español (España)',
    'English',
    'Português (Brasil)',
    'Français',
    'Italiano',
    'Deutsch',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();

    // Auto-scroll helper when focus changes
    _avatarFocusNode.addListener(() {
      if (_avatarFocusNode.hasFocus && mounted) {
        _scrollController.animateTo(0.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic);
      }
    });

    _nameFocusNode.addListener(() {
      if (_nameFocusNode.hasFocus && mounted) {
        _scrollController.animateTo(0.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic);
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
      });
      _avatarFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _scrollController.dispose();
    _avatarFocusNode.dispose();
    _nameFocusNode.dispose();
    _languageFocusNode.dispose();
    _autoplayNextFocusNode.dispose();
    _autoplayPreviewsFocusNode.dispose();
    _saveFocusNode.dispose();
    _cancelFocusNode.dispose();
    _deleteFocusNode.dispose();
    super.dispose();
  }

  void _save(UserProfile? profile) {
    final newName = _nameController.text.trim();
    if (newName.isNotEmpty && profile != null) {
      ref.read(authProvider.notifier).updateProfileName(newName);
    }
    ref
        .read(settingsProvider.notifier)
        .setAutoPlayNextEpisode(_autoplayNextEpisode);

    if (Navigator.canPop(context)) {
      context.pop();
    } else {
      context.go('/select-profile');
    }
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        title: const Text(
          'Idioma de visualización',
          style: TextStyle(
            fontFamily: 'NetflixSans',
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _languages.map((lang) {
                final isSelected = lang == _selectedLanguage;
                return _LanguageOptionTile(
                  label: lang,
                  isSelected: isSelected,
                  onSelected: () {
                    setState(() => _selectedLanguage = lang);
                    Navigator.pop(ctx);
                    _languageFocusNode.requestFocus();
                  },
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _languageFocusNode.requestFocus();
            },
            child: const Text(
              'CANCELAR',
              style: TextStyle(
                fontFamily: 'NetflixSans',
                color: Colors.white70,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        title: const Text(
          '¿Eliminar perfil?',
          style: TextStyle(
            fontFamily: 'NetflixSans',
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Se perderá todo el historial y las preferencias de $name para siempre.',
          style: const TextStyle(
            fontFamily: 'NetflixSans',
            color: Colors.white70,
            fontSize: 15,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'CANCELAR',
              style: TextStyle(
                fontFamily: 'NetflixSans',
                color: Colors.white60,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(authProvider.notifier).deleteProfile(id);
              Navigator.pop(ctx);
              context.go('/select-profile');
            },
            child: const Text(
              'ELIMINAR PERFIL',
              style: TextStyle(
                fontFamily: 'NetflixSans',
                color: Color(0xFFE50914),
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF000000);

    final user = ref.watch(authProvider);
    final profile = user?.profiles.firstWhere(
      (p) => p.id == widget.profileId,
      orElse: () => user.profiles.first,
    );

    final bool canDelete = profile != null && !profile.isMain;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.canPop(context)) {
          context.pop();
        } else {
          context.go('/select-profile');
        }
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Screen Title: "EDITAR PERFIL" ────────────────────────
                    const Text(
                      'EDITAR PERFIL',
                      style: TextStyle(
                        fontFamily: 'NetflixSans',
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),

                    const SizedBox(height: 36),

                    // ── Two-Column Layout (Avatar Card + Details) ─────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Avatar Card (132×132dp with inside edit pencil)
                        _AvatarEditTile(
                          focusNode: _avatarFocusNode,
                          photoUrl: profile?.photoUrl,
                          onRightPressed: () => _nameFocusNode.requestFocus(),
                          onDownPressed: () => _saveFocusNode.requestFocus(),
                          onTap: () => context.push('/settings/avatar?profileId=${profile?.id}'),
                        ),

                        const SizedBox(width: 36),

                        // Right: Form Controls & Settings
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Section 1: Name Input (Direct, no header) ──
                              _NetflixNameInput(
                                focusNode: _nameFocusNode,
                                controller: _nameController,
                                onLeftPressed: () =>
                                    _avatarFocusNode.requestFocus(),
                                onDownPressed: () =>
                                    _languageFocusNode.requestFocus(),
                              ),

                              _buildSectionDivider(height: 16),

                              // ── Section 2: IDIOMA ─────────────────────────
                              const Text(
                                'IDIOMA',
                                style: TextStyle(
                                  fontFamily: 'NetflixSans',
                                  color: Color(0xFF808080),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _NetflixSelectorButton(
                                focusNode: _languageFocusNode,
                                value: _selectedLanguage,
                                onLeftPressed: () =>
                                    _avatarFocusNode.requestFocus(),
                                onUpPressed: () =>
                                    _nameFocusNode.requestFocus(),
                                onDownPressed: () =>
                                    _autoplayNextFocusNode.requestFocus(),
                                onTap: _showLanguageDialog,
                              ),

                              _buildSectionDivider(height: 16),

                              // ── Section 3: CONTROLES DE REPRODUCCIÓN AUTOMÁTICA
                              const Text(
                                'CONTROLES DE REPRODUCCION AUTOMATICA',
                                style: TextStyle(
                                  fontFamily: 'NetflixSans',
                                  color: Color(0xFF808080),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _NetflixTvCheckbox(
                                focusNode: _autoplayNextFocusNode,
                                title:
                                    'Reproducir automáticamente el siguiente episodio en una serie en todos los dispositivos',
                                value: _autoplayNextEpisode,
                                onLeftPressed: () =>
                                    _avatarFocusNode.requestFocus(),
                                onUpPressed: () =>
                                    _languageFocusNode.requestFocus(),
                                onDownPressed: () =>
                                    _autoplayPreviewsFocusNode.requestFocus(),
                                onChanged: (val) {
                                  setState(() => _autoplayNextEpisode = val);
                                },
                              ),
                              const SizedBox(height: 6),
                              _NetflixTvCheckbox(
                                focusNode: _autoplayPreviewsFocusNode,
                                title:
                                    'Reproducir automáticamente los avances mientras navegas en todos los dispositivos',
                                value: _autoplayPreviews,
                                onLeftPressed: () =>
                                    _avatarFocusNode.requestFocus(),
                                onUpPressed: () =>
                                    _autoplayNextFocusNode.requestFocus(),
                                onDownPressed: () =>
                                    _saveFocusNode.requestFocus(),
                                onChanged: (val) {
                                  setState(() => _autoplayPreviews = val);
                                },
                              ),

                              const SizedBox(height: 24),

                              // ── Bottom Action Buttons ─────────────────────
                              Row(
                                children: [
                                  // GUARDAR
                                  _NetflixActionButton(
                                    focusNode: _saveFocusNode,
                                    label: 'GUARDAR',
                                    isPrimary: true,
                                    onUpPressed: () =>
                                        _autoplayPreviewsFocusNode
                                            .requestFocus(),
                                    onRightPressed: () =>
                                        _cancelFocusNode.requestFocus(),
                                    onPressed: () => _save(profile),
                                  ),
                                  const SizedBox(width: 14),

                                  // CANCELAR
                                  _NetflixActionButton(
                                    focusNode: _cancelFocusNode,
                                    label: 'CANCELAR',
                                    isPrimary: false,
                                    onUpPressed: () =>
                                        _autoplayPreviewsFocusNode
                                            .requestFocus(),
                                    onLeftPressed: () =>
                                        _saveFocusNode.requestFocus(),
                                    onRightPressed: canDelete
                                        ? () =>
                                            _deleteFocusNode.requestFocus()
                                        : null,
                                    onPressed: () => context.pop(),
                                  ),

                                  if (canDelete) ...[
                                    const SizedBox(width: 14),
                                    // ELIMINAR PERFIL
                                    _NetflixActionButton(
                                      focusNode: _deleteFocusNode,
                                      label: 'ELIMINAR PERFIL',
                                      isPrimary: false,
                                      isDestructive: true,
                                      onUpPressed: () =>
                                          _autoplayPreviewsFocusNode
                                              .requestFocus(),
                                      onLeftPressed: () =>
                                          _cancelFocusNode.requestFocus(),
                                      onPressed: () =>
                                          _showDeleteConfirmation(
                                              profile.id, profile.name),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionDivider({double height = 22}) {
    return Container(
      height: 1,
      margin: EdgeInsets.symmetric(vertical: height),
      color: Colors.white.withValues(alpha: 0.12),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar Edit Tile (Exact Netflix Ninja 118×118dp + Pencil Overlay)
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarEditTile extends StatefulWidget {
  final FocusNode focusNode;
  final String? photoUrl;
  final VoidCallback onRightPressed;
  final VoidCallback onDownPressed;
  final VoidCallback onTap;

  const _AvatarEditTile({
    required this.focusNode,
    this.photoUrl,
    required this.onRightPressed,
    required this.onDownPressed,
    required this.onTap,
  });

  @override
  State<_AvatarEditTile> createState() => _AvatarEditTileState();
}

class _AvatarEditTileState extends State<_AvatarEditTile> {
  bool _hasFocus = false;

  static const double kSize = 132.0;
  static const double kRadius = 14.0;
  static const double kBorder = 3.0;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (f) => setState(() => _hasFocus = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            widget.onRightPressed();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            widget.onDownPressed();
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
        child: AnimatedScale(
          scale: _hasFocus ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Container(
            width: kSize,
            height: kSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kRadius),
              border: Border.all(
                color: Colors.white,
                width: kBorder,
              ),
              boxShadow: _hasFocus
                  ? [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.35),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.8),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(kRadius - kBorder),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Avatar image ─────────────────────────────────────────
                  _AvatarDisplay(photoUrl: widget.photoUrl),

                  // ── Pencil badge inside avatar at bottom right ───────────
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1E2833).withValues(alpha: 0.95),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 17,
                      ),
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


// ─────────────────────────────────────────────────────────────────────────────
// Avatar Display Widget
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarDisplay extends StatelessWidget {
  final String? photoUrl;
  const _AvatarDisplay({this.photoUrl});

  @override
  Widget build(BuildContext context) {
    if (photoUrl == null || photoUrl!.isEmpty) {
      return Container(
        color: const Color(0xFF1C1C1C),
        alignment: Alignment.center,
        child: const Icon(
          Icons.person_rounded,
          color: Color(0xFF808080),
          size: 52,
        ),
      );
    }
    if (photoUrl!.startsWith('assets/')) {
      return Image.asset(photoUrl!, fit: BoxFit.cover);
    }
    return CachedNetworkImage(
      imageUrl: photoUrl!,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: const Color(0xFF1C1C1C)),
      errorWidget: (_, __, ___) => Container(
        color: const Color(0xFF1C1C1C),
        alignment: Alignment.center,
        child: const Icon(
          Icons.person_rounded,
          color: Color(0xFF808080),
          size: 52,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Netflix Name Input Box
// ─────────────────────────────────────────────────────────────────────────────

class _NetflixNameInput extends StatefulWidget {
  final FocusNode focusNode;
  final TextEditingController controller;
  final VoidCallback onLeftPressed;
  final VoidCallback onDownPressed;

  const _NetflixNameInput({
    required this.focusNode,
    required this.controller,
    required this.onLeftPressed,
    required this.onDownPressed,
  });

  @override
  State<_NetflixNameInput> createState() => _NetflixNameInputState();
}

class _NetflixNameInputState extends State<_NetflixNameInput> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = _hasFocus
        ? Colors.white
        : Colors.white.withValues(alpha: 0.2);
    final borderWidth = _hasFocus ? 2.5 : 1.5;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: borderColor, width: borderWidth),
    );
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (f) => setState(() => _hasFocus = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
              widget.controller.selection.baseOffset <= 0) {
            widget.onLeftPressed();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            widget.onDownPressed();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: TextField(
          controller: widget.controller,
          cursorColor: Colors.white,
          style: const TextStyle(
            fontFamily: 'NetflixSans',
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          onSubmitted: (_) => widget.onDownPressed(),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF222222),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            hintText: 'Nombre del perfil',
            hintStyle: const TextStyle(
              fontFamily: 'NetflixSans',
              color: Color(0xFF666666),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            border: border,
            enabledBorder: border,
            focusedBorder: border,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Netflix Selector Button (Language)
// ─────────────────────────────────────────────────────────────────────────────

class _NetflixSelectorButton extends StatefulWidget {
  final FocusNode focusNode;
  final String value;
  final VoidCallback onLeftPressed;
  final VoidCallback onUpPressed;
  final VoidCallback onDownPressed;
  final VoidCallback onTap;

  const _NetflixSelectorButton({
    required this.focusNode,
    required this.value,
    required this.onLeftPressed,
    required this.onUpPressed,
    required this.onDownPressed,
    required this.onTap,
  });

  @override
  State<_NetflixSelectorButton> createState() => _NetflixSelectorButtonState();
}

class _NetflixSelectorButtonState extends State<_NetflixSelectorButton> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (f) => setState(() => _hasFocus = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            widget.onLeftPressed();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            widget.onUpPressed();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            widget.onDownPressed();
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
          width: 250,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF222222),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: _hasFocus
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.15),
              width: _hasFocus ? 2.0 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.value,
                style: const TextStyle(
                  fontFamily: 'NetflixSans',
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Icon(
                Icons.arrow_drop_down_rounded,
                color: Colors.white70,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Netflix TV Checkbox Tile
// ─────────────────────────────────────────────────────────────────────────────

class _NetflixTvCheckbox extends StatefulWidget {
  final FocusNode focusNode;
  final String title;
  final bool value;
  final VoidCallback onLeftPressed;
  final VoidCallback onUpPressed;
  final VoidCallback onDownPressed;
  final ValueChanged<bool> onChanged;

  const _NetflixTvCheckbox({
    required this.focusNode,
    required this.title,
    required this.value,
    required this.onLeftPressed,
    required this.onUpPressed,
    required this.onDownPressed,
    required this.onChanged,
  });

  @override
  State<_NetflixTvCheckbox> createState() => _NetflixTvCheckboxState();
}

class _NetflixTvCheckboxState extends State<_NetflixTvCheckbox> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (f) => setState(() => _hasFocus = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            widget.onLeftPressed();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            widget.onUpPressed();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            widget.onDownPressed();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space) {
            widget.onChanged(!widget.value);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () => widget.onChanged(!widget.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _hasFocus
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: _hasFocus ? Colors.white : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Square Checkbox (Dark box with white checkmark when true)
              Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF222222),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: widget.value
                        ? Colors.white70
                        : const Color(0xFF555555),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: widget.value
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontFamily: 'NetflixSans',
                    color: _hasFocus
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: _hasFocus ? FontWeight.w600 : FontWeight.w400,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Netflix TV Action Button (Save / Cancel / Delete)
// ─────────────────────────────────────────────────────────────────────────────

class _NetflixActionButton extends StatefulWidget {
  final FocusNode focusNode;
  final String label;
  final bool isPrimary;
  final bool isDestructive;
  final VoidCallback onUpPressed;
  final VoidCallback? onLeftPressed;
  final VoidCallback? onRightPressed;
  final VoidCallback onPressed;

  const _NetflixActionButton({
    required this.focusNode,
    required this.label,
    required this.isPrimary,
    this.isDestructive = false,
    required this.onUpPressed,
    this.onLeftPressed,
    this.onRightPressed,
    required this.onPressed,
  });

  @override
  State<_NetflixActionButton> createState() => _NetflixActionButtonState();
}

class _NetflixActionButtonState extends State<_NetflixActionButton> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    // Styling colors matching Netflix reference
    final Color backgroundColor;
    final Color textColor;
    final Color borderColor;

    if (widget.isDestructive) {
      if (_hasFocus) {
        backgroundColor = const Color(0xFFE50914);
        textColor = Colors.white;
        borderColor = const Color(0xFFE50914);
      } else {
        backgroundColor = const Color(0xFF2B2B2B);
        textColor = Colors.white70;
        borderColor = Colors.transparent;
      }
    } else {
      if (_hasFocus) {
        backgroundColor = Colors.white;
        textColor = Colors.black;
        borderColor = Colors.white;
      } else {
        backgroundColor = const Color(0xFF2B2B2B);
        textColor = Colors.white;
        borderColor = Colors.transparent;
      }
    }

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (f) => setState(() => _hasFocus = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            widget.onUpPressed();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
              widget.onLeftPressed != null) {
            widget.onLeftPressed!();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
              widget.onRightPressed != null) {
            widget.onRightPressed!();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space) {
            widget.onPressed();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: borderColor,
              width: _hasFocus ? 2.0 : 0.0,
            ),
            boxShadow: _hasFocus
                ? [
                    BoxShadow(
                      color: widget.isDestructive
                          ? const Color(0xFFE50914).withValues(alpha: 0.4)
                          : Colors.white.withValues(alpha: 0.3),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: 'NetflixSans',
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Language Option Tile in Dialog
// ─────────────────────────────────────────────────────────────────────────────

class _LanguageOptionTile extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onSelected;

  const _LanguageOptionTile({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  State<_LanguageOptionTile> createState() => _LanguageOptionTileState();
}

class _LanguageOptionTileState extends State<_LanguageOptionTile> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _hasFocus = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onSelected();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onSelected,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9.5),
          decoration: BoxDecoration(
            color: _hasFocus
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: _hasFocus ? Colors.white : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'NetflixSans',
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: widget.isSelected || _hasFocus
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
              if (widget.isSelected)
                const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
