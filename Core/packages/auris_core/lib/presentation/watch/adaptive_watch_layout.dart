import 'package:flutter/material.dart';

/// Layout Adaptativo Responsivo para la WatchScreen.
///
/// Evalúa el tamaño disponible de pantalla y dispone los componentes en:
/// - **Móvil Retrato (< 768px):** Columna única vertical (Player 16:9 arriba, Metadatos abajo).
/// - **Tablet / Móvil Horizontal (768px - 1024px):** Layout dividido en dos columnas.
/// - **Web / Desktop (> 1024px):** Columna principal izquierda (Player + Metadatos) y Cola Lateral derecha.
class AdaptiveWatchLayout extends StatelessWidget {
  const AdaptiveWatchLayout({
    super.key,
    required this.playerWidget,
    required this.metadataWidget,
    required this.actionBarWidget,
    required this.synopsisWidget,
    required this.nextEpisodeWidget,
    required this.previousEpisodeWidget,
    this.playlistSidebarWidget,
    this.isTheaterMode = false,
  });

  final Widget playerWidget;
  final Widget metadataWidget;
  final Widget actionBarWidget;
  final Widget synopsisWidget;
  final Widget nextEpisodeWidget;
  final Widget previousEpisodeWidget;
  final Widget? playlistSidebarWidget;
  final bool isTheaterMode;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        final bool isDesktopWeb = width >= 1024;
        final bool isTabletWidth = width >= 768 && width < 1024;

        if (isDesktopWeb) {
          if (isTheaterMode) {
            // Modo Cinemático / Teatro estilo YouTube (> 1024px)
            final double stageHeight = (height * 0.78).clamp(480.0, 850.0);

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Escenario de Video Cinemático al 100% del Ancho
                  Container(
                    width: double.infinity,
                    height: stageHeight,
                    color: Colors.black,
                    child: playerWidget,
                  ),
                  const SizedBox(height: 20),

                  // Detalles e información a la izquierda, lista de episodios a la derecha
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              metadataWidget,
                              actionBarWidget,
                              const Divider(color: Colors.white10, height: 24),
                              synopsisWidget,
                              const SizedBox(height: 24),
                              nextEpisodeWidget,
                              previousEpisodeWidget,
                            ],
                          ),
                        ),
                        if (playlistSidebarWidget != null) ...[
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 3,
                            child: SizedBox(
                              height: 600,
                              child: playlistSidebarWidget!,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          // Layout Normal Web / Desktop (> 1024px)
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Columna Izquierda: Reproductor + Metadatos
              Expanded(
                flex: 7,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Reproductor AspectRatio 16:9
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: playerWidget,
                        ),
                      ),
                      const SizedBox(height: 20),
                      metadataWidget,
                      actionBarWidget,
                      const Divider(color: Colors.white10, height: 24),
                      synopsisWidget,
                      const SizedBox(height: 24),
                      nextEpisodeWidget,
                      previousEpisodeWidget,
                    ],
                  ),
                ),
              ),

              // Columna Derecha: Cola de episodios lateral (solo si hay)
              if (playlistSidebarWidget != null)
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24, right: 24, bottom: 24),
                    child: playlistSidebarWidget!,
                  ),
                ),
            ],
          );
        } else if (isTabletWidth) {
          // Layout Tablet / Móvil Landscape (768px - 1024px)
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: playerWidget,
                      ),
                      const SizedBox(height: 16),
                      metadataWidget,
                      actionBarWidget,
                      synopsisWidget,
                    ],
                  ),
                ),
              ),
              if (playlistSidebarWidget != null)
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: playlistSidebarWidget!,
                  ),
                ),
            ],
          );
        } else {
          // Layout Móvil Retrato (< 768px)
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reproductor 16:9 arriba
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: playerWidget,
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      metadataWidget,
                      actionBarWidget,
                      const Divider(color: Colors.white10, height: 20),
                      synopsisWidget,
                      const SizedBox(height: 16),
                      nextEpisodeWidget,
                      previousEpisodeWidget,
                    ],
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }
}