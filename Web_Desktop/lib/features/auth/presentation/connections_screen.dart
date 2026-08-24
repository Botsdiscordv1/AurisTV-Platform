import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auris_core/auris_core.dart';
import 'providers/integration_provider.dart';
import '../../../shared/widgets/responsive_page_wrapper.dart';

class ConnectionsScreen extends ConsumerWidget {
  const ConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conexiones Externas'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ResponsivePageWrapper(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _ConnectionTile(
              title: 'AniList',
              subtitle: 'Sincroniza tu progreso de Anime',
              isConnected: user?.isAnilistConnected ?? false,
              username: user?.anilistConnection?.username,
              icon: Icons.stars_rounded,
              onConnect: () => ref.read(integrationProvider.notifier).connectAnilist(),
            ),
            const SizedBox(height: 16),
            _ConnectionTile(
              title: 'Simkl',
              subtitle: 'Sincroniza Películas, Series y Anime',
              isConnected: user?.connections.containsKey(ConnectionType.simkl) ?? false,
              username: user?.connections[ConnectionType.simkl]?.username,
              icon: Icons.movie_filter_rounded,
              onConnect: () => ref.read(integrationProvider.notifier).connectSimkl(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isConnected;
  final String? username;
  final IconData icon;
  final VoidCallback onConnect;

  const _ConnectionTile({
    required this.title,
    required this.subtitle,
    required this.isConnected,
    this.username,
    required this.icon,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isConnected ? Colors.greenAccent : Colors.blueAccent).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isConnected ? Colors.greenAccent : Colors.blueAccent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(
                  isConnected ? 'Conectado como $username' : subtitle,
                  style: TextStyle(color: isConnected ? Colors.white70 : Colors.white54, fontSize: 14),
                ),
              ],
            ),
          ),
          if (!isConnected)
            ElevatedButton(
              onPressed: onConnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: const Text('Conectar'),
            )
          else
            const Icon(Icons.check_circle, color: Colors.greenAccent),
        ],
      ),
    );
  }
}
