import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auris_core.dart';

/// Bloque de información principal para la pantalla de detalles.
/// Contiene la sinopsis y metadata secundaria (Lanzamiento, Duración).
class AurisDetailInfo extends StatelessWidget {
  final String? overview;
  final String? releaseYear;
  final String? runtimeOrSeasons;
  final String? runtimeLabel;
  final bool revealed;

  const AurisDetailInfo({
    super.key,
    this.overview,
    this.releaseYear,
    this.runtimeOrSeasons,
    this.runtimeLabel,
    this.revealed = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. SINOPSIS
        _buildSynopsis(context),
        const SizedBox(height: 16),

        // 2. GRID DE METADATA (Lanzamiento / Temporadas)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.white12),
              bottom: BorderSide(color: Colors.white12),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    const Text('Lanzamiento', style: TextStyle(color: Color(0xFFA5A5AA), fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(releaseYear ?? 'N/A', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(runtimeLabel ?? 'Temporadas', style: const TextStyle(color: Color(0xFFA5A5AA), fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(runtimeOrSeasons ?? 'N/A', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSynopsis(BuildContext context) {
    if (!revealed && (overview == null || overview!.isEmpty)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          DetailSkeletonBox(width: double.infinity, height: 16),
          SizedBox(height: 8),
          DetailSkeletonBox(width: double.infinity, height: 16),
          SizedBox(height: 8),
          DetailSkeletonBox(width: 200, height: 16),
        ],
      );
    }
    
    return Text(
      (overview != null && overview!.isNotEmpty) ? overview! : 'Sinopsis no disponible.', 
      maxLines: 6, 
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.poppins(
        color: Colors.white.withOpacity(0.9), 
        fontSize: 15, 
        height: 1.4, 
        fontWeight: FontWeight.w400, 
      )
    );
  }
}
