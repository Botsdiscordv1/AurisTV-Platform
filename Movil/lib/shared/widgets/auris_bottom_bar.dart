import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:auris_core/auris_core.dart';

class AurisBottomBar extends ConsumerWidget {
  final int currentIndex;
  final Function(int) onTap;

  const AurisBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 54 + MediaQuery.of(context).padding.bottom,
      decoration: const BoxDecoration(
        color: Color(0xFF0B0B0D),
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Row(
        children: [
          _buildNavItem(context, ref, 0, Icons.home_outlined, Icons.home, 'Inicio'),
          _buildNavItem(context, ref, 1, Icons.search_rounded, Icons.search_rounded, 'Buscar'),
          _buildNavItem(context, ref, 2, Icons.explore_outlined, Icons.explore, 'Explorar'),
          _buildNavItem(context, ref, 3, null, null, 'Perfil', isProfile: true),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    WidgetRef ref,
    int index,
    IconData? icon,
    IconData? activeIcon,
    String label,
    {bool isProfile = false}
  ) {
    final bool isActive = currentIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            if (isProfile)
              _buildProfileIcon(ref, isActive)
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

  Widget _buildProfileIcon(WidgetRef ref, bool isActive) {
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
