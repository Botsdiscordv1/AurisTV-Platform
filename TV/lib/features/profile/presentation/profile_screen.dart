import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:auris_core/auris_core.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/focus/global_focus_nodes.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final FocusNode _heroFocusNode = FocusNode();
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
    _heroFocusNode.dispose();
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
    if (_heroFocusNode.canRequestFocus) {
      _heroFocusNode.requestFocus();
    }
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
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D24),
        title: const Text('Cerrar sesión', style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Estás seguro de que quieres cerrar tu sesión de AurisTV?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).signOut();
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _restoreFocusIfOutside(),
              );
            },
            child: const Text('Cerrar sesión', style: TextStyle(color: Colors.redAccent)),
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

    final List<Widget> badges = [
      if (user?.activeProfileId != null)
        const _Badge(label: 'PERFIL ACTIVO'),
      if (user?.isAnilistConnected ?? false)
        const _Badge(label: 'ANILIST'),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
        // BACK desde el perfil: el foco vuelve al icono de perfil de la
        // topbar de Home (el punto desde el que se abrió la pantalla).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (appRouter.routeInformationProvider.value.uri.path == '/' &&
              homeProfileIconFocusNode.context != null) {
            homeProfileIconFocusNode.requestFocus();
          }
        });
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0B0D),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(120, 48, 120, 60),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MI AURIS',
                    style: TextStyle(
                      color: Color(0xFFEF7A1E),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _ProfileHero(
                    focusNode: _heroFocusNode,
                    name: displayName,
                    email: emailLine,
                    photoUrl: user?.photoUrl,
                    badges: badges,
                    onTap: _navigateToEditProfile,
                  ),
                  const SizedBox(height: 48),
                  const _SectionLabel(title: 'Cuenta'),
                  _ProfileRow(
                    label: 'Añadir perfil',
                    icon: Icons.person_add_alt_1_outlined,
                    onTap: () => context.push('/add-profile'),
                  ),
                  _ProfileRow(
                    label: 'Cambiar de perfil',
                    icon: Icons.switch_account_outlined,
                    onTap: () => context.push('/select-profile'),
                  ),
                  _ProfileRow(
                    label: 'Administrar perfiles',
                    icon: Icons.manage_accounts_outlined,
                    onTap: () => context.push('/select-profile?edit=true'),
                  ),
                  const SizedBox(height: 32),
                  const _SectionLabel(title: 'Contenido'),
                  _ProfileRow(
                    label: 'Mi Lista',
                    icon: Icons.download_rounded,
                    onTap: () => context.push('/settings/library'),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  const SizedBox(height: 16),
                  if (isLoggedIn)
                    _ProfileRow(
                      label: 'Cerrar sesión',
                      icon: Icons.logout_rounded,
                      color: Colors.redAccent,
                      showChevron: false,
                      onTap: _showLogoutDialog,
                    )
                  else
                    _ProfileRow(
                      label: 'Iniciar sesión',
                      icon: Icons.login_rounded,
                      primary: true,
                      showChevron: false,
                      onTap: () => context.push('/login'),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHero extends StatefulWidget {
  final FocusNode focusNode;
  final String name;
  final String email;
  final String? photoUrl;
  final List<Widget> badges;
  final VoidCallback onTap;

  const _ProfileHero({
    required this.focusNode,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.badges,
    required this.onTap,
  });

  @override
  State<_ProfileHero> createState() => _ProfileHeroState();
}

class _ProfileHeroState extends State<_ProfileHero> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEF7A1E);
    final String? photo = widget.photoUrl;

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _focused
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              AnimatedScale(
                scale: _focused ? 1.06 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _focused ? primaryColor : Colors.white24,
                          width: _focused ? 3 : 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 72,
                        backgroundColor: Colors.white10,
                        backgroundImage: photo != null
                            ? (photo.startsWith('assets/')
                                ? AssetImage(photo) as ImageProvider
                                : CachedNetworkImageProvider(photo))
                            : null,
                        child: photo == null
                            ? const Icon(Icons.person_rounded,
                                color: Colors.white70, size: 64)
                            : null,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit_rounded,
                            color: Colors.black, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 28),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 18,
                      ),
                    ),
                    if (widget.badges.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Row(children: widget.badges),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileRow extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final bool primary;
  final bool showChevron;

  const _ProfileRow({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
    this.primary = false,
    this.showChevron = true,
  });

  @override
  State<_ProfileRow> createState() => _ProfileRowState();
}

class _ProfileRowState extends State<_ProfileRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEF7A1E);
    final Color accent = widget.color ?? primaryColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.select ||
               event.logicalKey == LogicalKeyboardKey.enter ||
               event.logicalKey == LogicalKeyboardKey.space)) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: widget.primary
                  ? primaryColor
                  : (_focused
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
              border: widget.primary
                  ? Border.all(
                      color: _focused ? Colors.white : Colors.transparent,
                      width: 2,
                    )
                  : Border(
                      left: BorderSide(
                        color: _focused ? accent : Colors.transparent,
                        width: 3,
                      ),
                    ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  color: widget.primary
                      ? Colors.black
                      : (_focused ? accent : Colors.white54),
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.primary
                          ? Colors.black
                          : (_focused
                              ? Colors.white
                              : (widget.color ?? Colors.white70)),
                      fontSize: 18,
                      fontWeight: _focused ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.showChevron)
                  Icon(
                    Icons.chevron_right_rounded,
                    color: _focused ? accent : Colors.white24,
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

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFFEF7A1E),
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
