import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:auris_core/auris_core.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Netflix TV "Who's watching?" Profile Selection — Pixel-Perfect Clone
//
// Key Netflix Ninja (TV) specifications:
//  • Canvas: Deep cinematic pure black (#000000)
//  • Header: AurisTV official flat logo ("auris-logo-web-flat.svg")
//  • Title: "¿Quién está viendo?" in NetflixSans Bold 44sp, white, centered
//  • Avatars: Square tiles (160×160dp) with rounded corners (BorderRadius 10dp)
//  • Focus state: 4dp solid pure white border + 1.08x smooth scale + white text
//  • Unfocused state: transparent border, 1.0x scale, Netflix #808080 grey text
//  • Add Profile tile: matching 160×160dp square with centered plus icon
//  • Action button: "ADMINISTRAR PERFILES" / "LISTO" outlined pill (4dp radius);
//    turns solid white fill with black text on focus (signature Netflix TV UI)
//  • Edit mode: translucent dark veil + centered pencil icon
//  • D-Pad traversal: seamless Left/Right navigation, Down to admin button,
//    Up returns to the last focused profile card, Back cancels edit mode
// ─────────────────────────────────────────────────────────────────────────────

class ProfileSelectionScreen extends ConsumerStatefulWidget {
  const ProfileSelectionScreen({super.key});

  @override
  ConsumerState<ProfileSelectionScreen> createState() =>
      _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState
    extends ConsumerState<ProfileSelectionScreen> {
  bool? _isEditModeOverride;
  int _lastFocusedProfileIndex = 0;

  final List<FocusNode> _profileFocusNodes = [];
  final FocusNode _addProfileFocusNode = FocusNode();
  final FocusNode _adminButtonFocusNode = FocusNode();

  void _syncFocusNodes(int count) {
    while (_profileFocusNodes.length < count) {
      _profileFocusNodes.add(FocusNode());
    }
    while (_profileFocusNodes.length > count) {
      _profileFocusNodes.removeLast().dispose();
    }
  }

  @override
  void dispose() {
    for (final n in _profileFocusNodes) {
      n.dispose();
    }
    _addProfileFocusNode.dispose();
    _adminButtonFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    const backgroundColor = Color(0xFF000000);

    final bool initialEdit =
        GoRouterState.of(context).uri.queryParameters['edit'] == 'true';
    final bool isEditMode = _isEditModeOverride ?? initialEdit;

    if (user == null) {
      return const Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFEF7A1E),
            strokeWidth: 2,
          ),
        ),
      );
    }

    final profiles = user.profiles;
    final bool showAdd = profiles.length < 5 && !isEditMode;
    _syncFocusNodes(profiles.length);

    // Initial autofocus to active profile or first profile
    final activeId = user.activeProfileId;
    int initialFocusIndex = 0;
    if (activeId != null) {
      final idx = profiles.indexWhere((p) => p.id == activeId);
      if (idx >= 0) initialFocusIndex = idx;
    }

    return PopScope(
      canPop: !isEditMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (isEditMode) {
          // Pressing back in edit mode exits edit mode first
          setState(() => _isEditModeOverride = false);
        }
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Column(
            children: [
              // ── Top Header: Auris Flat Logo (Icon + Wordmark) ───────────────
              Padding(
                padding: const EdgeInsets.only(top: 32, bottom: 8),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/icons/auris-logo-web-flat.svg',
                    height: 32,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // ── Title: "¿Quién está viendo?" (Netflix Sans 36sp Bold) ───────
              Text(
                isEditMode ? 'Administrar perfiles' : '¿Quién está viendo?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'NetflixSans',
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  height: 1.1,
                ),
              ),

              const SizedBox(height: 38),

              // ── Horizontal Profiles Row (Netflix TV 160×160dp Tiles) ────────
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...profiles.asMap().entries.map((entry) {
                      final index = entry.key;
                      final profile = entry.value;
                      final isLast = index == profiles.length - 1 && !showAdd;

                      return Padding(
                        padding: EdgeInsets.only(right: isLast ? 0 : 24),
                        child: _ProfileCard(
                          key: ValueKey('profile_${profile.id}'),
                          focusNode: _profileFocusNodes[index],
                          name: profile.name,
                          photoUrl: profile.photoUrl,
                          isEditMode: isEditMode,
                          isMain: profile.isMain,
                          autofocus: index == initialFocusIndex,
                          onFocused: () {
                            _lastFocusedProfileIndex = index;
                          },
                          onDownPressed: () {
                            _adminButtonFocusNode.requestFocus();
                          },
                          onTap: () {
                            if (isEditMode) {
                              ref
                                  .read(authProvider.notifier)
                                  .switchProfile(profile.id);
                              context.push('/edit-profile/${profile.id}');
                            } else {
                              ref
                                  .read(authProvider.notifier)
                                  .switchProfile(profile.id);
                              context.go('/');
                            }
                          },
                          onDelete: () => _showDeleteConfirmation(
                            context,
                            ref,
                            profile.id,
                            profile.name,
                          ),
                        ),
                      );
                    }),

                    // ── Add Profile Tile (If < 5 profiles and not editing) ──
                    if (showAdd)
                      _AddProfileCard(
                        focusNode: _addProfileFocusNode,
                        onFocused: () {
                          _lastFocusedProfileIndex = profiles.length;
                        },
                        onDownPressed: () {
                          _adminButtonFocusNode.requestFocus();
                        },
                        onTap: () => context.push('/add-profile'),
                      ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // ── Action Button: "ADMINISTRAR PERFILES" / "LISTO" ────────────
              _AdminButton(
                focusNode: _adminButtonFocusNode,
                isEditMode: isEditMode,
                onUpPressed: () {
                  if (_lastFocusedProfileIndex < _profileFocusNodes.length) {
                    _profileFocusNodes[_lastFocusedProfileIndex].requestFocus();
                  } else if (showAdd) {
                    _addProfileFocusNode.requestFocus();
                  } else if (_profileFocusNodes.isNotEmpty) {
                    _profileFocusNodes.first.requestFocus();
                  }
                },
                onPressed: () {
                  setState(() => _isEditModeOverride = !isEditMode);
                },
              ),

              const SizedBox(height: 42),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    String id,
    String name,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text(
          '¿Eliminar perfil?',
          style: TextStyle(
            fontFamily: 'NetflixSans',
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Se perderá todo el historial y las preferencias de $name.',
          style: const TextStyle(
            fontFamily: 'NetflixSans',
            color: Colors.white70,
            fontSize: 16,
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
                letterSpacing: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(authProvider.notifier).deleteProfile(id);
              Navigator.pop(ctx);
            },
            child: const Text(
              'ELIMINAR',
              style: TextStyle(
                fontFamily: 'NetflixSans',
                color: Colors.redAccent,
                letterSpacing: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile Card — Chunky Square Rounded Avatar (Exact Netflix Ninja TV Style)
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileCard extends StatefulWidget {
  final FocusNode focusNode;
  final String name;
  final String? photoUrl;
  final bool isEditMode;
  final bool isMain;
  final bool autofocus;
  final VoidCallback onFocused;
  final VoidCallback onDownPressed;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ProfileCard({
    super.key,
    required this.focusNode,
    required this.name,
    this.photoUrl,
    required this.isEditMode,
    required this.isMain,
    this.autofocus = false,
    required this.onFocused,
    required this.onDownPressed,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  bool _hasFocus = false;

  // Netflix TV Avatar Specifications (Calibrated 10-foot UI)
  static const double kSize = 118.0;
  static const double kRadius = 6.0;
  static const double kBorder = 3.0;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (f) {
        setState(() => _hasFocus = f);
        if (f) widget.onFocused();
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
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
          scale: _hasFocus ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: kSize + kBorder * 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Avatar Image Container ──────────────────────────────────
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: kSize,
                      height: kSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(kRadius),
                        border: Border.all(
                          color: _hasFocus ? Colors.white : Colors.transparent,
                          width: kBorder,
                        ),
                        boxShadow: _hasFocus
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(kRadius - kBorder / 2),
                        child: _AvatarImage(photoUrl: widget.photoUrl),
                      ),
                    ),

                    // ── Edit Mode Veil & Pencil ──────────────────────────────
                    if (widget.isEditMode)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(kRadius),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.6),
                            alignment: Alignment.center,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.4),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.0,
                                ),
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                color: Colors.white,
                                size: 19,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // ── Delete Badge (Non-main profiles only) ────────────────
                    if (widget.isEditMode && !widget.isMain)
                      Positioned(
                        top: -6,
                        right: -6,
                        child: GestureDetector(
                          onTap: widget.onDelete,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Profile Name Label ──────────────────────────────────────
                Text(
                  widget.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'NetflixSans',
                    color: _hasFocus || widget.isEditMode
                        ? Colors.white
                        : const Color(0xFF808080),
                    fontSize: 15,
                    fontWeight: _hasFocus || widget.isEditMode
                        ? FontWeight.w700
                        : FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Profile Card — Square Rounded Match with Plus Icon
// ─────────────────────────────────────────────────────────────────────────────

class _AddProfileCard extends StatefulWidget {
  final FocusNode focusNode;
  final VoidCallback onFocused;
  final VoidCallback onDownPressed;
  final VoidCallback onTap;

  const _AddProfileCard({
    required this.focusNode,
    required this.onFocused,
    required this.onDownPressed,
    required this.onTap,
  });

  @override
  State<_AddProfileCard> createState() => _AddProfileCardState();
}

class _AddProfileCardState extends State<_AddProfileCard> {
  bool _hasFocus = false;

  static const double kSize = 118.0;
  static const double kRadius = 6.0;
  static const double kBorder = 3.0;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (f) {
        setState(() => _hasFocus = f);
        if (f) widget.onFocused();
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
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
          scale: _hasFocus ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: SizedBox(
            width: kSize + kBorder * 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: kSize,
                  height: kSize,
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(kRadius),
                    border: Border.all(
                      color: _hasFocus
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.12),
                      width: kBorder,
                    ),
                    boxShadow: _hasFocus
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.add_rounded,
                    color: _hasFocus ? Colors.white : const Color(0xFF808080),
                    size: 44,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Añadir perfil',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'NetflixSans',
                    color: _hasFocus ? Colors.white : const Color(0xFF808080),
                    fontSize: 15,
                    fontWeight: _hasFocus ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar Image Widget Loader (Asset or Cached Network)
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarImage extends StatelessWidget {
  final String? photoUrl;
  const _AvatarImage({this.photoUrl});

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
// Admin / Done Button — Exact Netflix TV Outlined Pill (Turns White on Focus)
// ─────────────────────────────────────────────────────────────────────────────

class _AdminButton extends StatefulWidget {
  final FocusNode focusNode;
  final bool isEditMode;
  final VoidCallback onUpPressed;
  final VoidCallback onPressed;

  const _AdminButton({
    required this.focusNode,
    required this.isEditMode,
    required this.onUpPressed,
    required this.onPressed,
  });

  @override
  State<_AdminButton> createState() => _AdminButtonState();
}

class _AdminButtonState extends State<_AdminButton> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final label = widget.isEditMode ? 'LISTO' : 'ADMINISTRAR PERFILES';

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (f) => setState(() => _hasFocus = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            widget.onUpPressed();
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
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
          decoration: BoxDecoration(
            color: _hasFocus ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: _hasFocus
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.4),
              width: _hasFocus ? 2.0 : 1.5,
            ),
            boxShadow: _hasFocus
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.25),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'NetflixSans',
              color: _hasFocus ? Colors.black : Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
        ),
      ),
    );
  }
}
