import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:auris_core/auris_core.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final favorites = ref.watch(favoritesProvider);
    const primaryColor = Color(0xFFEF7A1E);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF0B0B0D),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Mi Auris',
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: AurisIcon(AurisIcons.cast, color: Colors.white, size: 22),
            onPressed: () {
              // Conexión / Cast si está disponible
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Buscando dispositivos de emisión...'), duration: Duration(seconds: 1)),
              );
            },
          ),
          IconButton(
            icon: AurisIcon(AurisIcons.search, color: Colors.white, size: 24),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 24),
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              // PERFIL PRINCIPAL / AVATAR
              Column(
                children: [
                  GestureDetector(
                    onTap: () => context.push('/select-profile?edit=true'),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white24, width: 2),
                            image: (user?.photoUrl != null)
                                ? DecorationImage(
                                    image: user!.photoUrl!.startsWith('assets/')
                                        ? AssetImage(user.photoUrl!) as ImageProvider
                                        : CachedNetworkImageProvider(user.photoUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            color: Colors.white10,
                          ),
                          child: (user?.photoUrl == null)
                              ? const Icon(Icons.person_rounded, color: Colors.white70, size: 48)
                              : null,
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit, size: 12, color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => context.push('/select-profile'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          user?.displayName?.toUpperCase() ?? user?.email?.toUpperCase() ?? 'INVITADO',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 22),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ACCESOS RÁPIDOS: NOTIFICACIONES Y DESCARGAS
              Column(
                children: [
                  _QuickActionTile(
                    icon: Icons.notifications_rounded,
                    iconBgColor: Colors.redAccent,
                    title: 'Notificaciones',
                    subtitle: 'Novedades y próximos estrenos',
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: const Color(0xFF16181D),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        builder: (context) => Container(
                          padding: const EdgeInsets.all(24),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Notificaciones', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              SizedBox(height: 16),
                              Text('No tienes notificaciones pendientes. ¡Te avisaremos cuando haya nuevos episodios!', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _QuickActionTile(
                    icon: Icons.download_rounded,
                    iconBgColor: Colors.blueAccent,
                    title: 'Descargas y Mi Espacio',
                    subtitle: 'Favoritos e historial guardado',
                    onTap: () => context.push('/settings/library'),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // SECCIÓN: CONTENIDO QUE TE GUSTÓ / FAVORITOS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Series y películas que te gustan',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () => context.push('/settings/library'),
                      child: const Text('Ver todo', style: TextStyle(color: primaryColor, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 240,
                child: favorites.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'Agrega contenido a tus favoritos para verlo aquí.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                          ),
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: favorites.length,
                        itemBuilder: (context, index) {
                          final item = favorites[index];
                          final cardWidth = ResponsiveUtils.posterWidth(context);
                          return SizedBox(
                            width: cardWidth,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: GestureDetector(
                                // Long-press: menú (ver detalles / quitar con Deshacer).
                                onLongPress: () => _showFavoriteMenu(context, ref, item),
                                child: FocusablePosterCard(
                                  key: ValueKey(item.url),
                                  title: item.title,
                                  posterUrl: item.posterUrl,
                                  showInfo: true,
                                  onTap: () => _openFavoriteDetail(context, item),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _openFavoriteDetail(
    BuildContext context, FavoriteItem item) {
  // URI completa (kind/year/type/season) + seed: sin esto el detalle abría
  // sin fuentes.
  final uri = '/content/${Uri.encodeComponent(item.title)}'
      '?source=${Uri.encodeComponent(item.source)}'
      '&category=${Uri.encodeComponent(item.category)}'
      '&url=${Uri.encodeComponent(item.url)}'
      '${item.season != null ? '&season=${item.season}' : ''}'
      '${item.year != null ? '&year=${item.year}' : ''}'
      '${item.kind != null && item.kind!.isNotEmpty ? '&kind=${Uri.encodeComponent(item.kind!)}' : ''}'
      '${item.type != null && item.type!.isNotEmpty ? '&type=${Uri.encodeComponent(item.type!)}' : ''}'
      '&metadataTitle=${Uri.encodeComponent(item.title)}&banner=${Uri.encodeComponent(item.bannerUrl)}';
  context.push(uri, extra: seedFromFavorite(item));
}

/// Menú long-press: ver detalles / quitar (con Deshacer).
void _showFavoriteMenu(
    BuildContext context, WidgetRef ref, FavoriteItem item) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF2D2D2D),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.white70),
            title: const Text('Ver detalles',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.pop(ctx);
              _openFavoriteDetail(context, item);
            },
          ),
          ListTile(
            leading:
                const Icon(Icons.close_rounded, color: Colors.redAccent),
            title: const Text('Quitar de Mi lista',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(ctx);
              ref.read(favoritesProvider.notifier).toggleFavorite(item);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Quitado de Mi lista'),
                  action: SnackBarAction(
                    label: 'Deshacer',
                    onPressed: () {
                      ref
                          .read(favoritesProvider.notifier)
                          .toggleFavorite(item);
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}

}

class _QuickActionTile extends StatelessWidget {

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
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white24),
            ],
          ),
        ),
      ),
    );
  }
}
