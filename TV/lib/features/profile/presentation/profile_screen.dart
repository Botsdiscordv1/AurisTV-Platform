import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:auris_core/auris_core.dart';
import '../../../../core/utils/tv_responsive_utils.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final GlobalKey<_FocusableNameSelectorState> _nameMenuKey =
      GlobalKey<_FocusableNameSelectorState>();

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final favorites = ref.watch(favoritesProvider);
    const primaryColor = Color(0xFFEF7A1E);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Si el menú flotante está abierto, BACK solo lo cierra y devuelve
        // el foco al nombre (en lugar de salir de la pantalla).
        final menu = _nameMenuKey.currentState;
        if (menu != null && menu.isMenuOpen) {
          menu.closeMenu();
          return;
        }
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0B0D),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0B0B0D),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/');
              }
            },
          ),
          title: const Text(
            'Mi Auris',
            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search_rounded, color: Colors.white, size: 28),
              onPressed: () => context.push('/search'),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 28),
              onPressed: () => context.push('/settings'),
            ),
            const SizedBox(width: 24),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 140, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Two separate focusable targets (Avatar -> ProfileEditScreen, Name Selector -> Integrated Dropdown)
                    Column(
                      children: [
                        _FocusableAvatarWidget(user: user, primaryColor: primaryColor),
                        const SizedBox(height: 16),
                        _FocusableNameSelector(
                          key: _nameMenuKey,
                          user: user,
                          primaryColor: primaryColor,
                        ),
                      ],
                    ),
                    const SizedBox(width: 60),

                    // Right Column: Quick actions & Favorites
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('MENÚ PRINCIPAL', style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          const SizedBox(height: 12),
                          _QuickActionTile(
                            icon: Icons.download_rounded,
                            iconBgColor: Colors.blueAccent,
                            title: 'Descargas y Mi Espacio',
                            subtitle: 'Favoritos e historial guardado',
                            onTap: () => context.push('/settings/library'),
                          ),
                          const Divider(color: Colors.white24, height: 40),

                          const Text('Series y películas que te gustan', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 260,
                            child: favorites.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 24),
                                      child: Text(
                                        'Agrega contenido a tus favoritos para verlo aquí.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 16),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: favorites.length,
                                    itemBuilder: (context, index) {
                                      final item = favorites[index];
                                      return SizedBox(
                                        width: 160,
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: 16),
                                          child: FocusablePosterCard(
                                            key: ValueKey(item.url),
                                            title: item.title,
                                            posterUrl: item.posterUrl,
                                            showInfo: true,
                                            onTap: () {
                                              final uri = Uri(
                                                path: '/content/${Uri.encodeComponent(item.title)}',
                                                queryParameters: {
                                                  'url': item.url,
                                                  'source': item.source,
                                                  'category': item.category,
                                                  'banner': item.bannerUrl ?? '',
                                                  'metadataTitle': item.title,
                                                },
                                              );
                                              context.push(uri.toString());
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
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
}

class _FocusableAvatarWidget extends StatefulWidget {
  final dynamic user;
  final Color primaryColor;

  const _FocusableAvatarWidget({required this.user, required this.primaryColor});

  @override
  State<_FocusableAvatarWidget> createState() => _FocusableAvatarWidgetState();
}

class _FocusableAvatarWidgetState extends State<_FocusableAvatarWidget> {
  bool _hasFocus = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_focusNode.canRequestFocus) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _navigateToEditProfile(BuildContext context) {
    final profiles = widget.user?.profiles;
    final activeId = widget.user?.activeProfileId;

    String? profileId;
    if (activeId != null && activeId.isNotEmpty) {
      profileId = activeId;
    } else if (profiles != null && profiles.isNotEmpty) {
      profileId = profiles.first.id;
    }

    if (profileId != null && profileId.isNotEmpty) {
      context.push('/edit-profile/$profileId');
    } else {
      context.push('/select-profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onFocusChange: (hasFocus) => setState(() => _hasFocus = hasFocus),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.space)) {
          _navigateToEditProfile(context);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          return GestureDetector(
            onTap: () => _navigateToEditProfile(context),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.zero,
                border: Border.all(
                  color: _hasFocus ? widget.primaryColor : Colors.transparent,
                  width: _hasFocus ? 2.5 : 1.5,
                ),
              ),
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24, width: 2),
                      image: (widget.user?.photoUrl != null)
                          ? DecorationImage(
                              image: widget.user!.photoUrl!.startsWith('assets/')
                                  ? AssetImage(widget.user!.photoUrl!) as ImageProvider
                                  : CachedNetworkImageProvider(widget.user!.photoUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color: Colors.white10,
                    ),
                    child: (widget.user?.photoUrl == null)
                        ? const Icon(Icons.person_rounded, color: Colors.white70, size: 75)
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: widget.primaryColor,
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
    );
  }
}

class _FocusableNameSelector extends StatefulWidget {
  final dynamic user;
  final Color primaryColor;

  const _FocusableNameSelector({super.key, required this.user, required this.primaryColor});

  @override
  State<_FocusableNameSelector> createState() => _FocusableNameSelectorState();
}

class _FocusableNameSelectorState extends State<_FocusableNameSelector> {
  bool _hasFocus = false;
  OverlayEntry? _overlayEntry;
  late FocusNode _nameButtonFocusNode;
  late FocusNode _firstOptionFocusNode;

  @override
  void initState() {
    super.initState();
    _nameButtonFocusNode = FocusNode();
    _firstOptionFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _closeMenu();
    _nameButtonFocusNode.dispose();
    _firstOptionFocusNode.dispose();
    super.dispose();
  }

  /// true si el menú flotante está visible (usado por el PopScope de la pantalla).
  bool get isMenuOpen => _overlayEntry != null;

  /// Cierra el menú y devuelve el foco al nombre.
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
        if (mounted && _nameButtonFocusNode.canRequestFocus) {
          _nameButtonFocusNode.requestFocus();
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
            width: size.width > 240 ? size.width : 240,
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
                    children: [
                      _MenuOption(
                        focusNode: _firstOptionFocusNode,
                        icon: Icons.manage_accounts_rounded,
                        label: 'Administrar perfiles',
                        onArrowUp: _closeMenu,
                        onBack: _closeMenu,
                        onTap: () {
                          _closeMenu();
                          context.push('/select-profile?edit=true');
                        },
                      ),
                      _MenuOption(
                        icon: Icons.person_add_rounded,
                        label: 'Añadir perfil',
                        onBack: _closeMenu,
                        onTap: () {
                          _closeMenu();
                          context.push('/add-profile');
                        },
                      ),
                      _MenuOption(
                        icon: Icons.switch_account_rounded,
                        label: 'Cambiar de perfil',
                        onBack: _closeMenu,
                        onTap: () {
                          _closeMenu();
                          context.push('/select-profile');
                        },
                      ),
                    ],
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
    return Focus(
      focusNode: _nameButtonFocusNode,
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.zero,
                border: Border.all(
                  color: _hasFocus ? widget.primaryColor : Colors.transparent,
                  width: _hasFocus ? 2.5 : 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.user?.displayName?.toUpperCase() ?? widget.user?.email?.toUpperCase() ?? 'INVITADO',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MenuOption extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onArrowUp;
  final VoidCallback? onBack;
  final FocusNode? focusNode;

  const _MenuOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.onArrowUp,
    this.onBack,
    this.focusNode,
  });

  @override
  State<_MenuOption> createState() => _MenuOptionState();
}

class _MenuOptionState extends State<_MenuOption> {
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
              Icon(widget.icon, color: _hasFocus ? primaryColor : Colors.white70, size: 22),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: TextStyle(
                  color: _hasFocus ? Colors.white : Colors.white70,
                  fontSize: 15,
                  fontWeight: _hasFocus ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatefulWidget {
  final IconData icon;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEF7A1E);
    return Focus(
      onFocusChange: (hasFocus) => setState(() => _hasFocus = hasFocus),
      child: Builder(
        builder: (context) {
          return GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.zero,
                border: Border.all(
                  color: _hasFocus ? primaryColor : Colors.transparent,
                  width: _hasFocus ? 2.5 : 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: widget.iconBgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(widget.subtitle, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 28),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
