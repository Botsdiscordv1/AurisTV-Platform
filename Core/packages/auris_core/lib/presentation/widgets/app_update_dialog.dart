import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../data/services/app_update_service.dart';
import 'tv_dialog_action.dart';

/// Diálogo de actualización: muestra las novedades y gestiona la descarga del
/// APK con progreso en vivo, opción de ocultar (sigue en segundo plano),
/// cancelar y lanzar el instalador al terminar.
class AppUpdateDialog extends StatefulWidget {
  final AppUpdateInfo info;

  /// "mobile" o "tv": determina qué APK del release se descarga.
  final String flavor;

  const AppUpdateDialog({
    super.key,
    required this.info,
    this.flavor = 'mobile',
  });

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  static const Color brandOrange = Color(0xFFEF7A1E);

  AppUpdateAsset? _asset;
  bool _resolving = true;
  bool _installing = false;
  bool _needsPermission = false;
  bool _installFailed = false;

  final FocusNode _primaryFocusNode =
      FocusNode(debugLabel: 'appUpdatePrimary');
  Timer? _focusRetry;

  bool get _isTv => widget.flavor == 'tv';

  @override
  void initState() {
    super.initState();
    AppUpdateDownloader.instance.isDialogOpen = true;
    AppUpdateDownloader.instance.addListener(_onDownloaderChanged);
    _resolveAsset();
    if (_isTv) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _primaryFocusNode.requestFocus();
      });
      // El hero de Home pide foco en su post-frame y puede pisar el del
      // diálogo; reintento una vez para garantizar que el D-pad entre aquí.
      _focusRetry = Timer(const Duration(milliseconds: 400), () {
        if (mounted &&
            !_primaryFocusNode.hasFocus &&
            _primaryFocusNode.canRequestFocus) {
          _primaryFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _focusRetry?.cancel();
    _primaryFocusNode.dispose();
    AppUpdateDownloader.instance.removeListener(_onDownloaderChanged);
    AppUpdateDownloader.instance.isDialogOpen = false;
    super.dispose();
  }

  Future<void> _resolveAsset() async {
    final String? abi = await AppUpdateService.currentAbi();
    final AppUpdateAsset? asset =
        AppUpdateService.pickAsset(widget.info.assets, widget.flavor, abi);
    if (!mounted) return;
    setState(() {
      _asset = asset;
      _resolving = false;
    });
  }

  void _onDownloaderChanged() {
    final AppUpdateDownloader downloader = AppUpdateDownloader.instance;
    if (downloader.status == AppUpdateDownloadStatus.downloaded && !_installing) {
      _installing = true;
      _maybeInstall();
    }
  }

  Future<void> _maybeInstall() async {
    final bool canInstall = await AppUpdateService.canInstallPackages();
    if (!mounted) return;
    if (!canInstall) {
      setState(() {
        _installing = false;
        _needsPermission = true;
      });
      await AppUpdateService.openInstallSettings();
      return;
    }
    final bool ok = await AppUpdateDownloader.instance.install();
    if (!mounted) return;
    setState(() {
      _installing = false;
      _installFailed = !ok;
    });
  }

  Future<void> _onUpdateNow() async {
    if (!AppUpdateService.isAndroid) {
      await AppUpdateService.launchReleaseUrl(widget.info.releaseUrl);
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final AppUpdateAsset? asset = _asset;
    if (asset == null) {
      // No hay APK para esta arquitectura: abrir la release en el navegador.
      await AppUpdateService.launchReleaseUrl(widget.info.releaseUrl);
      if (mounted) Navigator.of(context).pop();
      return;
    }
    await AppUpdateDownloader.instance.start(widget.info, asset);
  }

  String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final AppUpdateDownloader downloader = AppUpdateDownloader.instance;
    final double screenWidth = MediaQuery.of(context).size.width;

    return ListenableBuilder(
      listenable: downloader,
      builder: (BuildContext context, Widget? _) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.system_update, color: brandOrange, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '¡Nueva versión disponible!',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: screenWidth * 0.92,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: _buildContent(downloader),
              ),
            ),
          ),
          actions: _buildActions(downloader),
        );
      },
    );
  }

  List<Widget> _buildContent(AppUpdateDownloader downloader) {
    switch (downloader.status) {
      case AppUpdateDownloadStatus.downloading:
        return [
          Text(
            'Descargando versión ${widget.info.latestVersion}…',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: downloader.total > 0 ? downloader.progress : null,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(brandOrange),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${(downloader.progress * 100).toStringAsFixed(0)} %',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              Text(
                downloader.total > 0
                    ? '${_mb(downloader.received)} / ${_mb(downloader.total)} MB'
                    : '${_mb(downloader.received)} MB',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ];
      case AppUpdateDownloadStatus.error:
        return [
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('No se pudo completar la descarga.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(downloader.error ?? '',
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
        ];
      case AppUpdateDownloadStatus.downloaded:
        return [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.greenAccent, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Actualización descargada.',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _installing
                ? 'Abriendo el instalador…'
                : _needsPermission
                    ? 'Concede el permiso de instalación para continuar.'
                    : _installFailed
                        ? 'No se pudo abrir el instalador. Reintenta.'
                        : 'Iniciando instalación…',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ];
      case AppUpdateDownloadStatus.idle:
        return [
          Text(
            'Versión ${widget.info.latestVersion} ya está lista.',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          const Text(
            'Novedades y mejoras:',
            style: TextStyle(
                fontWeight: FontWeight.w600, color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: MarkdownBody(
              data: widget.info.releaseNotes,
              styleSheet:
                  MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: const TextStyle(fontSize: 14, color: Colors.white70),
                listBullet:
                    const TextStyle(fontSize: 14, color: Colors.white70),
                strong: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white),
                blockquote: const TextStyle(
                    color: Colors.white, fontStyle: FontStyle.italic),
                blockquoteDecoration: BoxDecoration(
                  color: brandOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: const Border(
                      left: BorderSide(color: brandOrange, width: 4)),
                ),
                code: const TextStyle(
                    backgroundColor: Colors.transparent,
                    color: brandOrange,
                    fontSize: 13),
              ),
            ),
          ),
        ];
    }
  }

  /// Botón de acción del diálogo. En TV usa un botón con foco visible
  /// (borde blanco + resaltado) y navegable con D-pad; en el resto de
  /// plataformas mantiene los botones Material de siempre.
  Widget _action({
    required String label,
    IconData? icon,
    required Color color,
    Color? background,
    required VoidCallback? onPressed,
    bool primary = false,
    bool first = false,
  }) {
    if (_isTv) {
      return TvDialogAction(
        label: label,
        icon: icon,
        color: color,
        background: background,
        onPressed: onPressed,
        focusNode: first ? _primaryFocusNode : null,
      );
    }
    if (primary) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon) : const SizedBox.shrink(),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: background ?? brandOrange,
          foregroundColor: Colors.white,
        ),
      );
    }
    return TextButton(
      onPressed: onPressed,
      child: Text(label, style: TextStyle(color: color)),
    );
  }

  List<Widget> _buildActions(AppUpdateDownloader downloader) {
    switch (downloader.status) {
      case AppUpdateDownloadStatus.downloading:
        return [
          _action(
            label: 'Ocultar',
            color: Colors.white70,
            onPressed: () => Navigator.of(context).pop(),
            first: true,
          ),
          _action(
            label: 'Cancelar',
            color: Colors.redAccent,
            onPressed: downloader.cancel,
          ),
        ];
      case AppUpdateDownloadStatus.error:
        return [
          _action(
            label: 'Cerrar',
            color: Colors.grey,
            onPressed: () => Navigator.of(context).pop(),
            first: true,
          ),
          _action(
            label: 'Reintentar',
            icon: Icons.refresh,
            color: Colors.white,
            background: brandOrange,
            primary: true,
            onPressed: _onUpdateNow,
          ),
        ];
      case AppUpdateDownloadStatus.downloaded:
        return [
          _action(
            label: 'Cerrar',
            color: Colors.grey,
            onPressed: () {
              downloader.reset();
              Navigator.of(context).pop();
            },
            first: true,
          ),
          if (!_installing)
            _action(
              label: 'Instalar',
              icon: Icons.install_mobile,
              color: Colors.white,
              background: brandOrange,
              primary: true,
              onPressed: _maybeInstall,
            ),
        ];
      case AppUpdateDownloadStatus.idle:
        return [
          _action(
            label: 'Más tarde',
            color: Colors.grey,
            onPressed: () => Navigator.of(context).pop(),
            first: true,
          ),
          _action(
            label: 'Actualizar ahora',
            icon: Icons.download,
            color: Colors.white,
            background: brandOrange,
            primary: true,
            onPressed: _resolving ? null : _onUpdateNow,
          ),
        ];
    }
  }
}

