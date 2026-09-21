import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import '../../../core/utils/responsive_utils.dart';
import 'package:auris_core/auris_core.dart';
import '../../core/utils/url_utils.dart';
import '../../features/player/presentation/player_screen.dart';
import '../../features/remote_control/presentation/providers/remote_control_provider.dart';
import '../../features/remote_control/data/models/remote_device.dart';
import 'auris_bottom_bar.dart';

class MainNavigationWrapper extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainNavigationWrapper({
    super.key,
    required this.navigationShell,
  });

  @override
  ConsumerState<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends ConsumerState<MainNavigationWrapper> {
  DateTime? _lastPopTime;

  void _onTap(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  void _handleBackGesture() {
    final now = DateTime.now();
    if (_lastPopTime != null && now.difference(_lastPopTime!) < const Duration(milliseconds: 600)) {
      return;
    }
    _lastPopTime = now;

    final router = GoRouter.of(context);
    final String location = GoRouterState.of(context).uri.path;
    
    // Rutas que consideramos "Raíz" de cada pestaña
    final bool isRootPath = location == '/inicio' || 
                            location == '/catalogo' || 
                            location == '/explore' || 
                            location == '/settings';

    // 1. Si estamos en una sub-ruta (Anime, Biblioteca, etc), cerramos esa pantalla
    if (!isRootPath && router.canPop()) {
      router.pop();
      return;
    }

    // 2. Si estamos en una raíz secundaria, volvemos a Inicio
    if (widget.navigationShell.currentIndex != 0) {
      _onTap(0);
      return;
    }

    // 3. Si estamos en Inicio, salimos de la app
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isTactic = ResponsiveUtils.isTactic(context);
    final remoteState = ref.watch(remoteControlProvider);
    final targetId = remoteState.activeTargetDeviceId;
    final target = remoteState.availableDevices.firstWhereOrNull((d) => d.id == targetId);

    // Senior Web Fix: Usamos GoRouterState para una detección reactiva y segura de la ruta.
    final state = GoRouterState.of(context);
    final String location = state.uri.path;
    final bool isFullScreen = location.startsWith('/detalles') || location.startsWith('/reproductor');

    if (!isTactic) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0B0D),
        body: Stack(
          children: [
            widget.navigationShell,
            if (target != null && target.isOnline)
              Positioned(
                left: 24, bottom: 24,
                child: _RemoteMiniPlayer(target: target),
              ),
          ],
        ),
      );
    }

    return PopScope(
      canPop: false, 
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackGesture();
      },
      child: Scaffold(
        body: Stack(
          children: [
            widget.navigationShell,
            if (target != null && target.isOnline)
              Positioned(
                left: 12, right: 12, bottom: 12,
                child: _RemoteMiniPlayer(target: target),
              ),
          ],
        ),
        bottomNavigationBar: isFullScreen ? null : AurisBottomBar(
          currentIndex: widget.navigationShell.currentIndex,
          onTap: _onTap,
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index, 
    IconData? icon, 
    IconData? activeIcon, 
    {bool isProfile = false}
  ) {
    final bool isActive = widget.navigationShell.currentIndex == index;
    const primaryColor = Color(0xFFEF7A1E);

    return Expanded(
      child: InkWell(
        onTap: () => _onTap(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: isActive ? 32 : 0,
              height: 3,
              decoration: const BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(3)),
              ),
            ),
            const Spacer(),
            if (isProfile)
              _buildProfileIcon(isActive)
            else
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? Colors.white : Colors.white54,
                size: 26,
              ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileIcon(bool isActive) {
    final user = ref.watch(authProvider);
    final String? photoUrl = user?.photoUrl;

    if (photoUrl == null) {
      return Icon(
        isActive ? Icons.person : Icons.person_outline,
        color: isActive ? Colors.white : Colors.white54,
        size: 26,
      );
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? Colors.white : Colors.white38,
          width: 1.5,
        ),
        image: DecorationImage(
          image: photoUrl.startsWith('assets/')
              ? AssetImage(photoUrl) as ImageProvider
              : CachedNetworkImageProvider(photoUrl),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _RemoteMiniPlayer extends ConsumerWidget {
  final RemoteDevice target;
  const _RemoteMiniPlayer({required this.target});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTactic = ResponsiveUtils.isTactic(context);
    final String? title = target.mediaTitle;
    final String? poster = target.bannerUrl ?? target.posterUrl;

    if (title == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        final player = PlayerScreen(
          contentId: target.id,
          sourceUrl: target.mediaUrl ?? '',
          source: target.mediaSource ?? '',
          episode: target.mediaEpisode ?? '1',
          category: target.category,
          title: target.mediaTitle,
          posterUrl: target.posterUrl,
          bannerUrl: target.bannerUrl,
          startPosition: target.positionMs,
        );
        
        UrlUtils.openPlayer(context, player);
      },
      child: Container(
        height: 64,
        width: isTactic ? null : 360,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEF7A1E).withOpacity(0.3)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 4))
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            if (poster != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: ApiEndpoints.proxyImage(poster),
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.cast_connected_rounded, color: Color(0xFFEF7A1E), size: 10),
                      const SizedBox(width: 4),
                      Text(
                        'EN ${target.name.toUpperCase()}',
                        style: const TextStyle(color: Color(0xFFEF7A1E), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(target.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
              color: Colors.white,
              onPressed: () {
                ref.read(remoteControlProvider.notifier).sendCommand(
                  target.id, 
                  target.isPlaying ? RemoteAction.pause : RemoteAction.play
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              color: Colors.white24,
              onPressed: () => ref.read(remoteControlProvider.notifier).setActiveTarget(null),
            ),
          ],
        ),
      ),
    );
  }
}
