import 'package:flutter/material.dart';
import '../../auris_core.dart';

/// Widget reutilizable para "Continuar Viendo", basado en el diseño oficial de AurisTV.
/// 
/// Este widget replica la estética de [FocusableWideCard] del repositorio móvil para
/// asegurar consistencia visual en todas las plataformas, pero integrado con la 
/// lógica de historial del Core.
class ContinueWatchingCard extends StatelessWidget {
  final PlaybackHistory history;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final double width;
  final double height;

  const ContinueWatchingCard({
    super.key,
    required this.history,
    this.onTap,
    this.onDelete,
    this.width = 440,
    this.height = 280, // Ajustado para incluir el texto inferior
  });

  @override
  Widget build(BuildContext context) {
    const brandOrange = Color(0xFFEF7A1E);
    const textPrimary = Color(0xFFF5F5F5);
    const textSecondary = Color(0xFFA5A5AA);
    const progressTrack = Color(0xFF39393D);

    final String? imageUrl = history.bannerUrl ?? history.posterUrl;
    
    // Cálculo de tiempo restante (minutos)
    final remainingMs = history.durationInMilliseconds - history.positionInMilliseconds;
    final remainingMin = (remainingMs / 60000).ceil();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Área de la imagen (16:9 aprox)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Imagen
                      if (imageUrl != null)
                        Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => 
                              const Center(child: Icon(Icons.broken_image, color: Colors.white24)),
                        )
                      else
                        const Center(child: Icon(Icons.movie, color: Colors.white24)),

                      // Gradiente inferior
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                                stops: const [0.6, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Botón X (Eliminar)
                      if (onDelete != null)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: GestureDetector(
                            onTap: onDelete,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white70,
                                size: 16,
                              ),
                            ),
                          ),
                        ),

                      // Barra de progreso (Color Naranja AurisTV)
                      if (history.progress > 0)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 4,
                            color: progressTrack,
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: history.progress.clamp(0.0, 1.0),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: brandOrange,
                                  boxShadow: [
                                    BoxShadow(color: brandOrange, blurRadius: 4)
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),

            // Área de Texto
            SizedBox(
              height: 52, // Altura fija para alineación
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título: Ep 7 • Nombre
                  Text(
                    '${history.episode != null ? 'Ep ${history.episode} • ' : ''}${history.title ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  
                  const SizedBox(height: 4),

                  // Subtítulo: Quedan X min
                  if (remainingMin > 0)
                    Text(
                      'Quedan $remainingMin min',
                      style: TextStyle(
                        color: textPrimary.withOpacity(0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
