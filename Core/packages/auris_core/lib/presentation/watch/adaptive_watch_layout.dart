import 'package:flutter/material.dart';

/// Layout Adaptativo Responsivo para la WatchScreen (Estilo Web Desktop y Móvil).
///
/// Evalúa el tamaño disponible de pantalla y dispone los componentes en:
/// - **Móvil Retrato (< 768px):** Columna única vertical (Player 16:9 arriba, Metadatos abajo).
/// - **Tablet / Móvil Horizontal (768px - 1024px):** Layout dividido en dos columnas.
/// - **Web / Desktop (> 1024px):** TopBar superior con Breadcrumbs, Columna principal izquierda
///   (Player + Metadatos) y Cola Lateral derecha, con soporte fluido para Modo Teatro.
class AdaptiveWatchLayout extends StatelessWidget {
  const AdaptiveWatchLayout({
    super.key,
    required this.playerWidget,
    required this.metadataWidget,
    required this.actionBarWidget,
    required this.synopsisWidget,
    required this.nextEpisodeWidget,
    required this.previousEpisodeWidget,
    this.topBarWidget,
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
  final Widget? topBarWidget;
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
        final bool isMobile = width < 768;

        return Column(
          children: [
            // TopBar Superior (Breadcrumbs & Acciones): Oculto en móvil (<768px), visible en Tablet y Desktop (>=768px)
            if (topBarWidget != null && !isMobile) topBarWidget!,

            Expanded(
              child: Builder(
                builder: (context) {
                  if (isDesktopWeb) {
                    final double stageHeight = (height * 0.78).clamp(480.0, 850.0);

                    return SingleChildScrollView(
                      child: AnimatedPadding(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOutCubic,
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
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOutCubic,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(isTheaterMode ? 0 : 12),
                                      boxShadow: isTheaterMode
                                          ? []
                                          : [
                                              BoxShadow(
                                                color: const Color(0xFFEF7A1E).withValues(alpha: 0.10),
                                                blurRadius: 24,
                                                spreadRadius: 2,
                                              ),
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.80),
                                                blurRadius: 16,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                    ),
                                    child: isTheaterMode
                                        ? Container(
                                            width: double.infinity,
                                            height: stageHeight,
                                            color: Colors.black,
                                            child: playerWidget,
                                          )
                                        : ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: AspectRatio(
                                              aspectRatio: 16 / 9,
                                              child: playerWidget,
                                            ),
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
                            AnimatedPadding(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOutCubic,
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
                      ),
                    );
                  } else if (isTabletWidth) {
                    // Layout Tablet (768px - 1024px): Reproductor ancho completo arriba, metadatos y navegación limpia estilo móvil
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: playerWidget,
                          ),
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                metadataWidget,
                                actionBarWidget,
                                const Divider(color: Colors.white10, height: 24),
                                synopsisWidget,
                                const SizedBox(height: 24),
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
              ),
            ),
          ],
        );
      },
    );
  }
}
