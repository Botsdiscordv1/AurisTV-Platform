import 'package:flutter/material.dart';
import '../../auris_core.dart';

/// Layout base adaptativo para pantallas de detalle de contenido.
/// Gestiona la transición entre vista móvil (vertical) y vista de escritorio/plegable (horizontal).
class AdaptiveDetailLayout extends StatelessWidget {
  /// Widget para la imagen de fondo (Backdrop)
  final Widget backdrop;
  /// Logo o título principal
  final Widget? logo;
  /// Fila de metadata (año, rating, géneros)
  final Widget? meta;
  /// Botón principal (Play/Continuar)
  final Widget? mainAction;
  /// Botones secundarios (Mi lista, Trailer, etc)
  final Widget? secondaryActions;
  /// Texto de sinopsis
  final Widget? synopsis;
  /// Selectores (Temporadas, Servidores)
  final Widget? selectors;
  /// Contenido inferior (Slivers: Tabs, Episodios, Relacionados)
  final Widget content;
  /// Widget opcional para el botón de retroceso/cast
  final Widget? topBar;
  /// Ancho máximo del contenido (Senior: 1000px para legibilidad óptima)
  final double maxContentWidth;

  const AdaptiveDetailLayout({
    super.key,
    required this.backdrop,
    this.logo,
    this.meta,
    this.mainAction,
    this.secondaryActions,
    this.synopsis,
    this.selectors,
    required this.content,
    this.topBar,
    this.maxContentWidth = 1000,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width > 600; 
    final horizontalPadding = ResponsiveUtils.horizontalPadding(context);
    
    // Altura de cabecera adaptativa centralizada
    final double appBarHeight = isWide ? 420 : (width * 0.85);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. CABECERA ADAPTATIVA
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: appBarHeight),
                    child: Stack(
                      children: [
                        backdrop,
                        if (isWide && logo != null)
                          Positioned.fill(
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: maxContentWidth),
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 16),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      logo!,
                                      const SizedBox(height: 24),
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

              // 2. PANEL DE INFORMACIÓN (Centrado y con ancho limitado)
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: isWide ? horizontalPadding : 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isWide && logo != null) ...[
                            const SizedBox(height: 16),
                            logo!,
                          ],
                          const SizedBox(height: 8),
                          if (meta != null) meta!,
                          const SizedBox(height: 20),
                          
                          // Lógica de botones: Row en Wide, Column en Mobile
                          if (isWide)
                            Row(
                              children: [
                                if (mainAction != null) SizedBox(width: 300, child: mainAction!),
                                if (secondaryActions != null) ...[
                                  const SizedBox(width: 16),
                                  secondaryActions!,
                                ],
                              ],
                            )
                          else ...[
                            if (mainAction != null) mainAction!,
                            if (secondaryActions != null) ...[
                              const SizedBox(height: 16),
                              secondaryActions!,
                            ],
                          ],
                          
                          const SizedBox(height: 16),
                          if (synopsis != null) synopsis!,
                          const SizedBox(height: 16),
                          if (selectors != null) selectors!,
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 3. CONTENIDO (Tabs/Episodios)
              SliverMainAxisGroup(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: width > maxContentWidth ? (width - maxContentWidth) / 2 : 0),
                    sliver: content,
                  ),
                ],
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 50)),
            ],
          ),

          // 4. TOP BAR (Flotante)
          if (topBar != null)
            Positioned(
              top: 0, left: 0, right: 0,
              child: topBar!,
            ),
        ],
      ),
    );
  }
}
