import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../services/update_service.dart';

class UpdateDialog extends StatelessWidget {
  final AppUpdateInfo updateInfo;

  const UpdateDialog({Key? key, required this.updateInfo}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.system_update, color: Colors.blue, size: 28),
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
        width: MediaQuery.of(context).size.width * 0.85,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Versión ${updateInfo.latestVersion} ya está lista.',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 12),
              const Text(
                'Novedades y mejoras:',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: MarkdownBody(
                  data: updateInfo.releaseNotes,
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    p: const TextStyle(fontSize: 14),
                    listBullet: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (!updateInfo.forceUpdate)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Más tarde', style: TextStyle(color: Colors.grey)),
          ),
        ElevatedButton.icon(
          onPressed: () {
            UpdateService.launchUpdateUrl(updateInfo.updateUrl);
          },
          icon: const Icon(Icons.download),
          label: const Text('Actualizar ahora'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
