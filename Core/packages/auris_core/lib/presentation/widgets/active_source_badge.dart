import 'package:flutter/material.dart';

import 'package:auris_core/core/utils/source_utils.dart';

/// Badge que muestra el servidor activo y el idioma/calidad actual del track.
///
/// Centraliza la lógica de etiqueta (LAT/SUB/CAST) y bandera para que todos los
/// players (Movil/TV/Web) la reflejen sin duplicar código. Recibe el `quality`
/// en formato TIPO-IDIOMA (p.ej. "DUB-MX", "SUB-EN", "CAST-ES").
class ActiveSourceBadge extends StatelessWidget {
  final String? serverName;
  final String quality;
  final double serverFontSize;
  final double langFontSize;

  const ActiveSourceBadge({
    super.key,
    this.serverName,
    required this.quality,
    this.serverFontSize = 11,
    this.langFontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    final type = trackQualityType(quality);
    final label = type == 'SUB' ? 'SUB' : (type == 'CAST' ? 'CAST' : 'LAT');
    final code = languageCodeText(quality);
    final color = type == 'SUB' ? Colors.blueAccent : const Color(0xFFEF7A1E);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (serverName != null && serverName!.isNotEmpty)
                Text(
                  simplifySourceName(serverName!),
                  style: TextStyle(color: Colors.white, fontSize: serverFontSize, fontWeight: FontWeight.w900),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    code.isEmpty ? label : '$label · $code',
                    style: TextStyle(color: color, fontSize: langFontSize, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 12),
          const Icon(Icons.dns, color: Colors.white70, size: 18),
        ],
      ),
    );
  }
}
