import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class StorageScreen extends ConsumerStatefulWidget {
  const StorageScreen({super.key});

  @override
  ConsumerState<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends ConsumerState<StorageScreen> {
  bool _isLoading = true;
  int _imageCacheSize = 0;
  int _playbackHistoryCount = 0;
  int _searchHistoryCount = 0;
  int _homeCacheCount = 0;
  int _totalAppSize = 0;

  @override
  void initState() {
    super.initState();
    _calculateStorage();
  }

  Future<void> _calculateStorage() async {
    setState(() => _isLoading = true);
    try {
      if (Hive.isBoxOpen('playback_history')) {
        _playbackHistoryCount = Hive.box('playback_history').length;
      }
      if (Hive.isBoxOpen('search_history')) {
        _searchHistoryCount = Hive.box('search_history').length;
      }
      if (Hive.isBoxOpen('home_cache')) {
        _homeCacheCount = Hive.box('home_cache').length;
      }

      final tempDir = await getTemporaryDirectory();
      _imageCacheSize = await _getDirSize(tempDir);

      final appDocDir = await getApplicationDocumentsDirectory();
      final hiveSize = await _getDirSize(appDocDir);

      _totalAppSize = _imageCacheSize + hiveSize;
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<int> _getDirSize(Directory dir) async {
    int size = 0;
    try {
      if (await dir.exists()) {
        await for (var entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            size += await entity.length();
          }
        }
      }
    } catch (_) {}
    return size;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<void> _clearImageCache() async {
    await DefaultCacheManager().emptyCache();
    await _calculateStorage();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Caché de imágenes eliminada correctamente')),
      );
    }
  }

  Future<void> _clearHistories() async {
    if (Hive.isBoxOpen('playback_history')) {
      await Hive.box('playback_history').clear();
    }
    if (Hive.isBoxOpen('search_history')) {
      await Hive.box('search_history').clear();
    }
    if (Hive.isBoxOpen('home_cache')) {
      await Hive.box('home_cache').clear();
    }
    await _calculateStorage();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Historiales y caché local eliminados')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEF7A1E);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Almacenamiento y caché'),
        backgroundColor: const Color(0xFF0B0B0D),
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Desglose del almacenamiento',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                
                // Barra de progreso segmentada estilo Spotify
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 10,
                    color: Colors.white12,
                    child: Row(
                      children: [
                        Expanded(
                          flex: (_imageCacheSize > 0 ? _imageCacheSize : 1),
                          child: Container(color: primaryColor),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          flex: ((_playbackHistoryCount + _searchHistoryCount + _homeCacheCount) > 0 ? 30 : 1),
                          child: Container(color: Colors.blueAccent),
                        ),
                        const SizedBox(width: 2),
                        const Expanded(
                          flex: 100,
                          child: ColoredBox(color: Colors.white24),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Leyenda
                _LegendItem(color: primaryColor, title: 'Caché de imágenes', size: _formatBytes(_imageCacheSize)),
                _LegendItem(color: Colors.blueAccent, title: 'Historial e índices locales', size: '${_playbackHistoryCount + _searchHistoryCount + _homeCacheCount} elementos'),
                _LegendItem(color: Colors.white38, title: 'Total usado por AurisTV', size: _formatBytes(_totalAppSize)),
                
                const SizedBox(height: 32),
                const Divider(color: Colors.white10),
                const SizedBox(height: 16),

                // Sección: Eliminar Caché
                _ActionCard(
                  title: 'Eliminar caché de imágenes',
                  subtitle: 'Libera espacio eliminando posters y miniaturas guardadas (${_formatBytes(_imageCacheSize)}). No afectará tus cuentas ni tu sesión.',
                  buttonText: 'Borrar',
                  buttonColor: primaryColor,
                  onPressed: _clearImageCache,
                ),
                const SizedBox(height: 16),

                // Sección: Eliminar Historial / Datos
                _ActionCard(
                  title: 'Limpiar historiales y caché local',
                  subtitle: 'Borra el historial de reproducción, búsquedas recientes y caché de inicio (${_playbackHistoryCount + _searchHistoryCount + _homeCacheCount} registros).',
                  buttonText: 'Eliminar',
                  buttonColor: Colors.redAccent,
                  onPressed: _clearHistories,
                ),
              ],
            ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String title;
  final String size;

  const _LegendItem({required this.color, required this.title, required this.size});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14))),
          Text(size, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonText;
  final Color buttonColor;
  final VoidCallback onPressed;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.buttonColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
