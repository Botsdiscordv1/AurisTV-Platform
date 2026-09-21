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
      height: 60 + MediaQuery.of(context).padding.bottom,
      decoration: const BoxDecoration(
        color: Color(0xFF0B0B0D),
        border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Row(
        children: [
          _buildNavItem(context, ref, 0, Icons.home_outlined, Icons.home),
          _buildNavItem(context, ref, 1, Icons.search, Icons.search),
          _buildNavItem(context, ref, 2, Icons.explore_outlined, Icons.explore),
          _buildNavItem(context, ref, 3, null, null, isProfile: true),
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
    {bool isProfile = false}
  ) {
    final bool isActive = currentIndex == index;
    const primaryColor = Color(0xFFEF7A1E);

    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
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
              _buildProfileIcon(ref, isActive)
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

  Widget _buildProfileIcon(WidgetRef ref, bool isActive) {
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
