import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:auris_core/auris_core.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/focus/global_focus_nodes.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Netflix TV Profile & Account Hub — Pixel-Perfect Netflix Ninja TV Clone
//
// Refined TV Navigation & Zero-Clipping Scroll Architecture:
//  • Canvas: Deep OLED black (#000000)
//  • Top Header: AurisTV official flat logo ("auris-logo-web-flat.svg")
//  • 0-Clipping Scroll: Whenever focus is in the top section (profiles or hero),
//    scroll strictly animates to 0.0 so the header/logo is NEVER cut off!
//  • Gap-Free D-pad Traversal: Explicit focus linking ensures seamless navigation
//    from Profile Switcher ↕ Active Profile Card ↕ Menu Action Rows. No dead ends.
//  • Focusable Active Profile Card: Entire card is interactively focusable with
//    white highlight, preventing horizontal focus traps on the "EDITAR" button.
//  • Typography: 100% NetflixSans across all titles, metadata, buttons, labels.
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final FocusNode _firstProfileFocusNode = FocusNode();
  final FocusNode _heroFocusNode = FocusNode();
  final FocusNode _firstRowFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  FocusScopeNode? _routeScope;

  @override
  void initState() {
    super.initState();
    appRouter.routeInformationProvider.addListener(_handleRouteInformation);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _restoreFocusIfOutside());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeScope = FocusScope.of(context);
  }

  @override
  void dispose() {
    appRouter.routeInformationProvider
        .removeListener(_handleRouteInformation);
    _firstProfileFocusNode.dispose();
    _heroFocusNode.dispose();
    _firstRowFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleRouteInformation() {
    final String path = appRouter.routeInformationProvider.value.uri.path;
    if (path != '/profile') return;
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _restoreFocusIfOutside());
  }

  void _restoreFocusIfOutside() {
    if (!mounted) return;
    if (_routeScope?.hasFocus ?? false) return;
    if (_firstProfileFocusNode.canRequestFocus) {
      _firstProfileFocusNode.requestFocus();
    }
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    final double travel = _scrollController.offset.abs();
    if (travel < 1.0) return;
    final int ms = (150 + travel * 0.32).round().clamp(200, 450);
    _scrollController.animateTo(
      0.0,
      duration: Duration(milliseconds: ms),
      curve: Curves.easeOutCubic,
    );
  }

  void _navigateToEditProfile() {
    final user = ref.read(authProvider);
    final profiles = user?.profiles;
    final activeId = user?.activeProfileId;

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

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text(
          'Cerrar sesión',
          style: TextStyle(
            fontFamily: 'NetflixSans',
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          '¿Estás seguro de que quieres cerrar tu sesión en AurisTV?',
          style: TextStyle(
            fontFamily: 'NetflixSans',
            color: Color(0xFFA0A0A0),
            fontSize: 16,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        actions: [
          _DialogButton(
            label: 'CANCELAR',
            isPrimary: false,
            onPressed: () => Navigator.pop(ctx),
          ),
          const SizedBox(width: 12),
          _DialogButton(
            label: 'CERRAR SESIÓN',
            isPrimary: true,
            isDestructive: true,
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).signOut();
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _restoreFocusIfOutside(),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final bool isLoggedIn = user != null && user.email != null;

    final String displayName = isLoggedIn
        ? (user.displayName ?? user.email ?? 'INVITADO')
        : 'Modo Invitado';
    final String emailLine = isLoggedIn
        ? (user.email ?? '')
        : 'Inicia sesión para sincronizar favoritos e historial';

    final profiles = user?.profiles ?? [];
    final activeId = user?.activeProfileId;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
        // Retornar foco al ícono del TopBar al volver a Home
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (appRouter.routeInformationProvider.value.uri.path == '/' &&
              homeProfileIconFocusNode.context != null) {
            homeProfileIconFocusNode.requestFocus();
          }
        });
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: SafeArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(100, 36, 100, 60),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header Bar: Logo + Sección ────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/icons/auris-logo-web-flat.svg',
                          height: 34,
                          fit: BoxFit.contain,
                        ),
                        const Text(
                          'CUENTA',
                          style: TextStyle(
                            fontFamily: 'NetflixSans',
                            color: Color(0xFF808080),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 36),

                    // ── Quick Profile Switcher (Row horizontal continuo) ───
                    if (profiles.isNotEmpty) ...[
                      const _SectionHeader(title: 'CAMBIAR DE PERFIL'),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...profiles.asMap().entries.map((entry) {
                              final index = entry.key;
                              final p = entry.value;
                              final isActive = p.id == activeId;
                              return Padding(
                                padding: const EdgeInsets.only(right: 24),
                                child: _QuickProfileTile(
                                  key: ValueKey('quick_${p.id}'),
                                  focusNode: index == 0 ? _firstProfileFocusNode : null,
                                  name: p.name,
                                  photoUrl: p.photoUrl,
                                  isActive: isActive,
                                  onFocused: _scrollToTop,
                                  onDownPressed: () {
                                    _heroFocusNode.requestFocus();
                                  },
                                  onTap: () {
                                    if (!isActive) {
                                      ref.read(authProvider.notifier).switchProfile(p.id);
                                    }
                                    context.go('/');
                                  },
                                ),
                              );
                            }),
                            if (profiles.length < 5)
                              _QuickAddProfileTile(
                                onFocused: _scrollToTop,
                                onDownPressed: () {
                                  _heroFocusNode.requestFocus();
                                },
                                onTap: () => context.push('/add-profile'),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        width: double.infinity,
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      const SizedBox(height: 32),
                    ],

                    // ── Current Active Profile (Clean, negro puro, sin bordes) ─────
                    _ActiveProfileHero(
                      focusNode: _heroFocusNode,
                      name: displayName,
                      email: emailLine,
                      photoUrl: user?.photoUrl,
                      isLoggedIn: isLoggedIn,
                      isAnilistConnected: user?.isAnilistConnected ?? false,
                      onFocused: _scrollToTop,
                      onUpPressed: () {
                        _firstProfileFocusNode.requestFocus();
                      },
                      onDownPressed: () {
                        _firstRowFocusNode.requestFocus();
                      },
                      onEdit: _navigateToEditProfile,
                    ),

                    const SizedBox(height: 40),

                    // ── Account & Management Rows (Netflix TV Rows) ────────
                    const _SectionHeader(title: 'GESTIÓN DE CUENTA'),
                    const SizedBox(height: 14),

                    _NetflixTVRow(
                      focusNode: _firstRowFocusNode,
                      label: 'Administrar perfiles',
                      subtitle: 'Cambiar nombre, avatar o eliminar perfiles',
                      icon: Icons.edit_note_rounded,
                      onUpPressed: () {
                        _heroFocusNode.requestFocus();
                      },
                      onTap: () => context.push('/select-profile?edit=true'),
                    ),
                    _NetflixTVRow(
                      label: 'Pantalla de selección de perfiles',
                      subtitle: '¿Quién está viendo? (Selector principal)',
                      icon: Icons.switch_account_rounded,
                      onTap: () => context.push('/select-profile'),
                    ),
                    if (profiles.length < 5)
                      _NetflixTVRow(
                        label: 'Añadir nuevo perfil',
                        subtitle: 'Crear perfil adicional para otro miembro',
                        icon: Icons.person_add_alt_1_rounded,
                        onTap: () => context.push('/add-profile'),
                      ),

                    const SizedBox(height: 32),

                    // ── Contenido & Biblioteca ─────────────────────────────
                    const _SectionHeader(title: 'CONTENIDO'),
                    const SizedBox(height: 14),

                    _NetflixTVRow(
                      label: 'Mi Lista',
                      subtitle: 'Tus series, películas y animes guardados',
                      icon: Icons.bookmark_border_rounded,
                      onTap: () => context.push('/settings/library'),
                    ),

                    const SizedBox(height: 32),

                    // ── Sesión ─────────────────────────────────────────────
                    const _SectionHeader(title: 'SESIÓN'),
                    const SizedBox(height: 14),

                    if (isLoggedIn)
                      _NetflixTVRow(
                        label: 'Cerrar sesión',
                        subtitle: 'Desconectar esta cuenta de AurisTV',
                        icon: Icons.logout_rounded,
                        isDestructive: true,
                        onTap: _showLogoutDialog,
                      )
                    else
                      _NetflixTVRow(
                        label: 'Iniciar sesión',
                        subtitle: 'Conecta tu cuenta para sincronizar historial y favoritos',
                        icon: Icons.login_rounded,
                        isPrimaryAction: true,
                        onTap: () => context.push('/login'),
                      ),

                    const SizedBox(height: 48),
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

// ─────────────────────────────────────────────────────────────────────────────
// Section Header Label (Netflix TV Style)
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'NetflixSans',
        color: Color(0xFF808080),
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Profile Switcher Tile (Netflix TV Horizontal Profile Bar)
// ─────────────────────────────────────────────────────────────────────────────

class _QuickProfileTile extends StatefulWidget {
  final FocusNode? focusNode;
  final String name;
  final String? photoUrl;
  final bool isActive;
  final VoidCallback onFocused;
  final VoidCallback onDownPressed;
  final VoidCallback onTap;

  const _QuickProfileTile({
    super.key,
    this.focusNode,
    required this.name,
    this.photoUrl,
    required this.isActive,
    required this.onFocused,
    required this.onDownPressed,
    required this.onTap,
  });

  @override
  State<_QuickProfileTile> createState() => _QuickProfileTileState();
}

class _QuickProfileTileState extends State<_QuickProfileTile> {
  bool _hasFocus = false;

  static const double kSize = 110.0;
  static const double kRadius = 8.0;

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
            width: kSize,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                          color: _hasFocus
                              ? Colors.white
                              : (widget.isActive
                                  ? const Color(0xFFEF7A1E)
                                  : Colors.transparent),
                          width: _hasFocus ? 3.5 : (widget.isActive ? 2.5 : 0),
                        ),
                        boxShadow: _hasFocus
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(kRadius - 2),
                        child: _AvatarImage(photoUrl: widget.photoUrl, size: kSize),
                      ),
                    ),
                    if (widget.isActive)
                      Positioned(
                        bottom: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF7A1E),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'ACTIVO',
                            style: TextStyle(
                              fontFamily: 'NetflixSans',
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'NetflixSans',
                    color: _hasFocus
                        ? Colors.white
                        : (widget.isActive ? Colors.white : const Color(0xFF808080)),
                    fontSize: 14,
                    fontWeight: _hasFocus || widget.isActive
                        ? FontWeight.w700
                        : FontWeight.w500,
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
// Quick Add Profile Tile
// ─────────────────────────────────────────────────────────────────────────────

class _QuickAddProfileTile extends StatefulWidget {
  final VoidCallback onFocused;
  final VoidCallback onDownPressed;
  final VoidCallback onTap;

  const _QuickAddProfileTile({
    required this.onFocused,
    required this.onDownPressed,
    required this.onTap,
  });

  @override
  State<_QuickAddProfileTile> createState() => _QuickAddProfileTileState();
}

class _QuickAddProfileTileState extends State<_QuickAddProfileTile> {
  bool _hasFocus = false;

  static const double kSize = 110.0;
  static const double kRadius = 8.0;

  @override
  Widget build(BuildContext context) {
    return Focus(
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
            width: kSize,
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
                      width: _hasFocus ? 3.5 : 1.5,
                    ),
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
                  'Añadir',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'NetflixSans',
                    color: _hasFocus ? Colors.white : const Color(0xFF808080),
                    fontSize: 14,
                    fontWeight: _hasFocus ? FontWeight.w700 : FontWeight.w500,
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
// Active Profile Hero Card (Interactive TV Focusable Card — No Navigation Gaps)
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveProfileHero extends StatefulWidget {
  final FocusNode focusNode;
  final String name;
  final String email;
  final String? photoUrl;
  final bool isLoggedIn;
  final bool isAnilistConnected;
  final VoidCallback onFocused;
  final VoidCallback onUpPressed;
  final VoidCallback onDownPressed;
  final VoidCallback onEdit;

  const _ActiveProfileHero({
    required this.focusNode,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.isLoggedIn,
    required this.isAnilistConnected,
    required this.onFocused,
    required this.onUpPressed,
    required this.onDownPressed,
    required this.onEdit,
  });

  @override
  State<_ActiveProfileHero> createState() => _ActiveProfileHeroState();
}

class _ActiveProfileHeroState extends State<_ActiveProfileHero> {
  bool _hasFocus = false;

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
            widget.onEdit();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onEdit,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Square avatar
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _hasFocus ? Colors.white : Colors.transparent,
                    width: _hasFocus ? 3.0 : 0.0,
                  ),
                  boxShadow: _hasFocus
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _AvatarImage(photoUrl: widget.photoUrl, size: 84),
                ),
              ),
              const SizedBox(width: 24),

              // User details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'NetflixSans',
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'NetflixSans',
                        color: Color(0xFF808080),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (widget.isAnilistConnected) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2638),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF3860A8), width: 1),
                        ),
                        child: const Text(
                          'ANILIST CONECTADO',
                          style: TextStyle(
                            fontFamily: 'NetflixSans',
                            color: Color(0xFF6B9BFF),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 20),

              // Visual Edit Profile indicator button (Matches exact mockup)
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: _hasFocus ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _hasFocus ? Colors.white : Colors.white.withValues(alpha: 0.4),
                    width: _hasFocus ? 2 : 1.5,
                  ),
                ),
                child: Text(
                  'EDITAR',
                  style: TextStyle(
                    fontFamily: 'NetflixSans',
                    color: _hasFocus ? Colors.black : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
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
// Netflix TV Menu Action Row (Lights Up Solid White on Focus & Auto Scrolls)
// ─────────────────────────────────────────────────────────────────────────────

class _NetflixTVRow extends StatefulWidget {
  final FocusNode? focusNode;
  final String label;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onUpPressed;
  final bool isDestructive;
  final bool isPrimaryAction;

  const _NetflixTVRow({
    this.focusNode,
    required this.label,
    this.subtitle,
    required this.icon,
    required this.onTap,
    this.onUpPressed,
    this.isDestructive = false,
    this.isPrimaryAction = false,
  });

  @override
  State<_NetflixTVRow> createState() => _NetflixTVRowState();
}

class _NetflixTVRowState extends State<_NetflixTVRow> {
  bool _hasFocus = false;

  void _scrollRowIntoView(BuildContext context) {
    final RenderObject? object = context.findRenderObject();
    if (object is! RenderBox || !object.attached) return;
    final RenderAbstractViewport? viewport =
        RenderAbstractViewport.maybeOf(object);
    final ScrollableState? scrollable = Scrollable.maybeOf(context);
    if (viewport == null || scrollable == null) return;
    final ScrollPosition position = scrollable.position;
    if (!position.hasContentDimensions) return;

    final double contentTop = viewport.getOffsetToReveal(object, 0.45).offset;
    final double target = contentTop.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    final double travel = (target - position.pixels).abs();
    if (travel < 1.0) return;

    final int ms = (150 + travel * 0.32).round().clamp(200, 450);
    position.animateTo(
      target,
      duration: Duration(milliseconds: ms),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDestructive = widget.isDestructive;

    // Normal colors
    const Color normalBg = Color(0xFF101010);
    final Color normalBorder = Colors.white.withValues(alpha: 0.06);
    final Color normalText = isDestructive
        ? const Color(0xFFFF5252)
        : (widget.isPrimaryAction ? const Color(0xFFEF7A1E) : Colors.white.withValues(alpha: 0.88));
    final Color normalIcon = isDestructive
        ? const Color(0xFFFF5252)
        : (widget.isPrimaryAction ? const Color(0xFFEF7A1E) : const Color(0xFF808080));
    const Color normalSub = Color(0xFF666666);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: (f) {
          setState(() => _hasFocus = f);
          if (f) _scrollRowIntoView(context);
        },
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowUp && widget.onUpPressed != null) {
              widget.onUpPressed!();
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
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: _hasFocus ? Colors.white : normalBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _hasFocus ? Colors.white : normalBorder,
                width: _hasFocus ? 2.0 : 1.0,
              ),
              boxShadow: _hasFocus
                  ? [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.2),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  color: _hasFocus ? Colors.black : normalIcon,
                  size: 24,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'NetflixSans',
                          color: _hasFocus ? Colors.black : normalText,
                          fontSize: 17,
                          fontWeight: _hasFocus ? FontWeight.w700 : FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'NetflixSans',
                            color: _hasFocus
                                ? Colors.black.withValues(alpha: 0.65)
                                : normalSub,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: _hasFocus
                      ? Colors.black
                      : Colors.white.withValues(alpha: 0.2),
                  size: 26,
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
// Dialog Action Button
// ─────────────────────────────────────────────────────────────────────────────

class _DialogButton extends StatefulWidget {
  final String label;
  final bool isPrimary;
  final bool isDestructive;
  final VoidCallback onPressed;

  const _DialogButton({
    required this.label,
    required this.isPrimary,
    this.isDestructive = false,
    required this.onPressed,
  });

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final bool isDestructive = widget.isDestructive;
    final Color activeColor = isDestructive ? Colors.redAccent : Colors.white;

    return Focus(
      onFocusChange: (f) => setState(() => _hasFocus = f),
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
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: _hasFocus
                ? (isDestructive ? Colors.redAccent : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: _hasFocus
                  ? Colors.transparent
                  : (widget.isPrimary ? activeColor : Colors.white24),
              width: 1.5,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: 'NetflixSans',
              color: _hasFocus
                  ? (isDestructive ? Colors.white : Colors.black)
                  : (widget.isPrimary ? activeColor : Colors.white60),
              fontSize: 14,
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
// Avatar Image Loader Helper
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarImage extends StatelessWidget {
  final String? photoUrl;
  final double size;
  const _AvatarImage({this.photoUrl, this.size = 100});

  @override
  Widget build(BuildContext context) {
    if (photoUrl == null || photoUrl!.isEmpty) {
      return Container(
        color: const Color(0xFF1C1C1C),
        alignment: Alignment.center,
        child: Icon(
          Icons.person_rounded,
          color: const Color(0xFF808080),
          size: size * 0.55,
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
        child: Icon(
          Icons.person_rounded,
          color: const Color(0xFF808080),
          size: size * 0.55,
        ),
      ),
    );
  }
}
