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
  /// Pestañas (Tabs) con scroll horizontal edge-to-edge
  final Widget? tabs;
  /// Contenido inferior (Slivers o widgets de caja como Column/ListView)
  final Widget content;
  /// Widget opcional para el botón de retroceso/cast
  final Widget? topBar;
  /// Barra de navegación inferior (opcional)
  final Widget? bottomNavigationBar;
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
    this.tabs,
    required this.content,
    this.topBar,
    this.bottomNavigationBar,
    this.maxContentWidth = 1000,
  });

  /// Helper defensivo para asegurar que el contenido inferior sea un Sliver válido,
  /// protegiendo contra errores de geometría nula, Expanded/Spacer con altura infinita 
  /// y evitando que la pantalla se quede en negro.
  Widget _buildSliverContent(BuildContext context, Widget widget) {
    if (widget is SliverList ||
        widget is SliverGrid ||
        widget is SliverToBoxAdapter ||
        widget is SliverPadding ||
        widget is SliverAppBar ||
        widget is SliverPersistentHeader ||
        widget is SliverFillRemaining ||
        widget is SliverFillViewport ||
        widget is SliverAnimatedList ||
        widget is SliverMainAxisGroup ||
        widget is SliverCrossAxisGroup) {
      return widget;
    }
    final screenH = MediaQuery.sizeOf(context).height;
    return SliverToBoxAdapter(
      key: const ValueKey('detail_content_box_adapter'),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: 200,
          maxHeight: screenH > 0 ? screenH * 1.5 : 900,
        ),
        child: widget,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final bool isDesktop = ResponsiveUtils.isDesktop(context) || width >= 1024;
    final bool isTablet = ResponsiveUtils.isTablet(context) || (width >= 768 && width < 1024);
    final bool isWide = width >= 768; // Botones de acción en horizontal para Tablet y Desktop
    final horizontalPadding = ResponsiveUtils.horizontalPadding(context);
    final double contentPadding = isDesktop ? horizontalPadding : (isTablet ? 16.0 : 24.0); // Senior Fix: 16px en tablets (iPad Mini) para aprovechar todo el ancho sin desbordes de 1px.
    final double topPadding = ResponsiveUtils.isNative ? MediaQuery.of(context).padding.top : 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      bottomNavigationBar: bottomNavigationBar,
      body: CustomScrollView(
        key: const ValueKey('adaptive_detail_scroll_view'),
        physics: const ClampingScrollPhysics(), // Senior Fix: Evitar bloque negro al scroll hacia abajo
        cacheExtent: 1000.0, // Senior Fix: Pre-layout de slivers para evitar Null check operator en hitTestChildren durante cargas async
        slivers: [
          // 1. CABECERA ADAPTATIVA CON BOTONES INTEGRADOS
          // Senior Fix: Usamos StackFit.loose para permitir que el backdrop (AspectRatio)
          // determine su altura natural sin generar excepciones de constraints (pantalla en negro).
          SliverToBoxAdapter(
            key: const ValueKey('detail_header_sliver'),
            child: Padding(
              padding: EdgeInsets.only(top: topPadding),
              child: Stack(
                fit: StackFit.loose,
                children: [
                  backdrop,
                  
                  if (topBar != null)
                    Positioned(
                      top: 0, left: 0, right: 0,
                      child: SizedBox(
                        height: 80,
                        child: topBar!,
                      ),
                    ),

                  if (logo != null)
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxContentWidth),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              contentPadding, 
                              0, 
                              contentPadding, 
                              isWide ? 24 : 12
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                logo!,
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

          // 2. PANEL DE INFORMACIÓN
          // Senior Fix: Eliminado SizedBox(width: double.infinity) que provocaba RenderBox was not laid out (infinito).
          SliverToBoxAdapter(
            key: const ValueKey('detail_info_sliver'),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: isWide ? 22.0 : 16.0),
                    if (meta != null) Padding(
                      padding: EdgeInsets.symmetric(horizontal: contentPadding),
                      child: meta!,
                    ),
                    const SizedBox(height: 20),

                    if (isWide)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: contentPadding),
                        child: Row(
                          children: [
                            if (mainAction != null) SizedBox(width: 300, child: mainAction!),
                            if (secondaryActions != null) ...[
                              const SizedBox(width: 16),
                              Expanded(child: secondaryActions!), // Senior Fix: Evitar overflow en plegables (Fold)
                            ],
                          ],
                        ),
                      )
                    else ...[
                      if (mainAction != null) Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: mainAction!,
                      ),
                      if (secondaryActions != null) ...[
                        const SizedBox(height: 16),
                        secondaryActions!,
                      ],
                    ],

                    const SizedBox(height: 16),
                    if (synopsis != null) Padding(
                      padding: EdgeInsets.symmetric(horizontal: contentPadding),
                      child: synopsis!,
                    ),
                    const SizedBox(height: 16),
                    if (selectors != null) Padding(
                      padding: EdgeInsets.only(
                        left: contentPadding,
                        right: 0,
                      ),
                      child: selectors!,
                    ),
                    if (tabs != null) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: EdgeInsets.only(
                          left: contentPadding,
                          right: 0,
                        ),
                        child: tabs!,
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),

          // 3. CONTENIDO (Tabs/Episodios)
          // Senior Fix: SliverPadding limpio con sliver válido directamente.
          SliverPadding(
            key: const ValueKey('detail_content_sliver_padding'),
            padding: EdgeInsets.symmetric(
              horizontal: width > maxContentWidth 
                  ? (width - maxContentWidth) / 2 
                  : contentPadding,
            ),
            sliver: _buildSliverContent(context, content),
          ),
        ],
      ),
    );
  }
}
