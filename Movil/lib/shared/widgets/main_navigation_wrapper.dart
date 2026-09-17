import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import '../../../core/utils/responsive_utils.dart';
import 'package:auris_core/auris_core.dart';
import '../../features/remote_control/presentation/providers/remote_control_provider.dart';
import '../../features/remote_control/data/models/remote_device.dart';

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
    
    final bool isRootPath = location == '/' || 
                            location == '/search' || 
                            location == '/explore' || 
                            location == '/settings';

    if (!isRootPath && router.canPop()) {
      router.pop();
      return;
    }

    if (widget.navigationShell.currentIndex != 0) {
      _onTap(0);
      return;
    }

    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final remoteState = ref.watch(remoteControlProvider);
    final targetId = remoteState.activeTargetDeviceId;
    final target = remoteState.availableDevices.firstWhereOrNull((d) => d.id == targetId);

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
        bottomNavigationBar: Container(
          height: 54 + MediaQuery.of(context).padding.bottom, // Senior: Altura más compacta estilo YouTube
          decoration: const BoxDecoration(
            color: Color(0xFF0B0B0D),
            border: Border(top: BorderSide(color: Colors.white10, width: 0.5)), // Línea divisoria sutil
          ),
          child: Row(
            children: [
              _buildNavItem(0, Icons.home_outlined, Icons.home, 'Inicio'),
              _buildNavItem(1, Icons.search_rounded, Icons.search_rounded, 'Buscar'),
              _buildNavItem(2, Icons.explore_outlined, Icons.explore, 'Explorar'),
              _buildNavItem(3, null, null, 'Perfil', isProfile: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index, 
    IconData? icon, 
    IconData? activeIcon, 
    String label,
    {bool isProfile = false}
  ) {
    final bool isActive = widget.navigationShell.currentIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => _onTap(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start, // Senior: Alineación al inicio para dejar aire inferior
          children: [
            const SizedBox(height: 8), // Senior: Aire superior respecto a la línea divisoria
            if (isProfile)
              _buildProfileIcon(isActive)
            else
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? Colors.white : Colors.white70,
                size: 24,
              ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
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
        color: isActive ? Colors.white : Colors.white70,
        size: 24,
      );
    }

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? Colors.white : Colors.transparent,
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
    final String? title = target.mediaTitle;
    final String? poster = target.bannerUrl ?? target.posterUrl;

    if (title == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        final uri = Uri(
          path: '/player/${Uri.encodeComponent(target.mediaTitle ?? "Remote")}',
          queryParameters: {
            'url': target.mediaUrl ?? '',
            'source': target.mediaSource ?? '',
            'metadataTitle': target.metadataTitle ?? '',
            'banner': target.bannerUrl ?? '',
            'category': target.category ?? 'anime',
            'title': target.mediaTitle ?? '',
            'posterUrl': target.posterUrl ?? '',
          },
        );
        context.push(uri.toString());
      },
      child: Container(
        height: 64,
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
