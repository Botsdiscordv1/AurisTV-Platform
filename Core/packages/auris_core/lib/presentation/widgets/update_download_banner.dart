import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/providers.dart';
import '../../data/services/app_update_service.dart';
import 'app_update_dialog.dart';

/// Barra flotante que aparece cuando hay una actualización descargándose o ya
/// lista, mientras el diálogo está oculto. Permite reabrir el diálogo,
/// cancelar o instalar.
class UpdateDownloadBanner extends ConsumerWidget {
  /// "mobile" o "tv": se pasa al diálogo al reabrirlo.
  final String flavor;

  const UpdateDownloadBanner({super.key, this.flavor = 'mobile'});

  Future<void> _install(BuildContext context) async {
    final AppUpdateDownloader downloader = AppUpdateDownloader.instance;
    final bool canInstall = await AppUpdateService.canInstallPackages();
    if (!canInstall) {
      await AppUpdateService.openInstallSettings();
      return;
    }
    final bool ok = await downloader.install();
    if (!ok && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el instalador')),
      );
    }
  }

  void _reopenDialog(WidgetRef ref, AppUpdateInfo info) {
    final GlobalKey<NavigatorState> navigator = ref.read(navigatorKeyProvider);
    final BuildContext? context = navigator.currentState?.overlay?.context;
    if (context == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppUpdateDialog(info: info, flavor: flavor),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUpdateDownloader downloader = AppUpdateDownloader.instance;
    return ListenableBuilder(
      listenable: downloader,
      builder: (BuildContext context, Widget? _) {
        if (downloader.isDialogOpen || !downloader.isActive) {
          return const SizedBox.shrink();
        }
        final AppUpdateInfo? info = downloader.info;
        if (info == null) return const SizedBox.shrink();

        return Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Material(
                color: const Color(0xFF1A1D24),
                elevation: 8,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: _buildContent(context, ref, downloader, info),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    AppUpdateDownloader downloader,
    AppUpdateInfo info,
  ) {
    switch (downloader.status) {
      case AppUpdateDownloadStatus.downloading:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.system_update,
                    color: Color(0xFFEF7A1E), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Descargando actualización… '
                    '${(downloader.progress * 100).toStringAsFixed(0)} %',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                TextButton(
                  onPressed: () => _reopenDialog(ref, info),
                  child:
                      const Text('Ver', style: TextStyle(color: Colors.white70)),
                ),
                TextButton(
                  onPressed: downloader.cancel,
                  child: const Text('Cancelar',
                      style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: downloader.total > 0 ? downloader.progress : null,
                minHeight: 5,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFFEF7A1E)),
              ),
            ),
          ],
        );
      case AppUpdateDownloadStatus.downloaded:
        return Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Actualización lista para instalar',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
            ),
            TextButton(
              onPressed: downloader.reset,
              child:
                  const Text('Cerrar', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton.icon(
              onPressed: () => _install(context),
              icon: const Icon(Icons.install_mobile, size: 18),
              label: const Text('Instalar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF7A1E),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      case AppUpdateDownloadStatus.error:
        return Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Error al descargar la actualización',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
            ),
            TextButton(
              onPressed: downloader.reset,
              child:
                  const Text('Cerrar', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                final AppUpdateAsset? asset = downloader.asset;
                if (asset != null) downloader.start(info, asset);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF7A1E),
                foregroundColor: Colors.white,
              ),
              child: const Text('Reintentar'),
            ),
          ],
        );
      case AppUpdateDownloadStatus.idle:
        return const SizedBox.shrink();
    }
  }
}
