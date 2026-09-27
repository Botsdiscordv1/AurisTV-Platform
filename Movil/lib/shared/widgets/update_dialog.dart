import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../services/update_service.dart';

class UpdateDialog extends StatelessWidget {
  final AppUpdateInfo updateInfo;

  const UpdateDialog({Key? key, required this.updateInfo}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const brandOrange = Color(0xFFEF7A1E);

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
                    p: const TextStyle(fontSize: 14, color: Colors.white70),
                    listBullet: const TextStyle(fontSize: 14, color: Colors.white70),
                    strong: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    blockquote: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic),
                    blockquoteDecoration: BoxDecoration(
                      color: brandOrange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: const Border(left: BorderSide(color: brandOrange, width: 4)),
                    ),
                    code: const TextStyle(backgroundColor: Colors.transparent, color: brandOrange, fontSize: 13),
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
            backgroundColor: brandOrange,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
