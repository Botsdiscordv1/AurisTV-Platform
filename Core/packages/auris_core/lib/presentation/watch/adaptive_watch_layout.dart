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
    this.rightColumnWidget,
    this.mobileEpisodesWidget,
    this.isTheaterMode = false,
  });

  final Widget playerWidget;
  final Widget metadataWidget;
  final Widget actionBarWidget;
  final Widget synopsisWidget;
  final Widget nextEpisodeWidget;
  final Widget previousEpisodeWidget;
  final Widget? playlistSidebarWidget;
  final Widget? rightColumnWidget;
  final Widget? mobileEpisodesWidget;
  final bool isTheaterMode;

  @override
  Widget build(BuildContext context) {
    final Widget? activeRightWidget = rightColumnWidget ?? playlistSidebarWidget;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        final bool isDesktopWeb = width >= 1024;
        final bool isTabletWidth = width >= 768 && width < 1024;

        if (isDesktopWeb) {
          final double stageHeight = (height * 0.78).clamp(480.0, 850.0);

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isTheaterMode ? 0 : 24,
              vertical: isTheaterMode ? 0 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila 1: Reproductor (Ancho 100% en Modo Teatro, 70% en Modo Normal)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: isTheaterMode ? 10 : 7,
                      child: isTheaterMode
                          ? Container(
                              width: double.infinity,
                              height: stageHeight,
                              color: Colors.black,
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: playerWidget,
                                ),
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: playerWidget,
                              ),
                            ),
                    ),
                    if (!isTheaterMode && activeRightWidget != null) ...[
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 3,
                        child: LayoutBuilder(
                          builder: (context, colConstraints) {
                            // Si la altura no está acotada (dentro de SingleChildScrollView),
                            // calculamos una altura armónica igual a la del reproductor 16:9
                            final double playerEstimatedHeight =
                                (width - (isTheaterMode ? 0 : 48) - 24) * 0.7 * (9 / 16);
                            final double calculatedHeight =
                                playerEstimatedHeight > 200 ? playerEstimatedHeight : 450.0;
                            return SizedBox(
                              height: calculatedHeight,
                              child: activeRightWidget,
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 20),

                // Fila 2: Detalles (flex 7) y Lista de Episodios (flex 3 solo en Modo Teatro)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTheaterMode ? 32 : 0,
                    vertical: isTheaterMode ? 12 : 0,
                  ),
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
                            if (rightColumnWidget == null) ...[
                              const SizedBox(height: 24),
                              nextEpisodeWidget,
                              previousEpisodeWidget,
                            ],
                          ],
                        ),
                      ),
                      if (isTheaterMode && activeRightWidget != null) ...[
                        const SizedBox(width: 32),
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            height: 600,
                            child: activeRightWidget,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
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
                      const SizedBox(height: 16),
                      nextEpisodeWidget,
                      previousEpisodeWidget,
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
                      // Si mobileEpisodesWidget está activo, él gestiona
                      // internamente "Siguiente/Anterior episodio" (los oculta al expandir)
                      if (mobileEpisodesWidget == null) ...[
                        nextEpisodeWidget,
                        previousEpisodeWidget,
                      ],
                      if (mobileEpisodesWidget != null)
                        mobileEpisodesWidget!,
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
