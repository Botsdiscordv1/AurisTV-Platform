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
    required this.content,
    this.topBar,
    this.bottomNavigationBar,
    this.maxContentWidth = 1000,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width > 600; 
    final horizontalPadding = ResponsiveUtils.horizontalPadding(context);
    
    // Altura de cabecera adaptativa centralizada
    final double appBarHeight = isWide ? 420 : (width * 0.85);
    final double topPadding = ResponsiveUtils.isNative ? MediaQuery.of(context).padding.top : 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      bottomNavigationBar: bottomNavigationBar,
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(), // Senior Fix: Evitar bloque negro al scroll hacia abajo
        slivers: [
          // 1. CABECERA ADAPTATIVA CON BOTONES INTEGRADOS
          // Al estar dentro de un Sliver, los botones se desplazan con el header y no se sobreponen al contenido inferior.
          SliverToBoxAdapter(
            child: SizedBox(
              height: appBarHeight + topPadding,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Margen para Safe Area (Solo nativo)
                  Padding(
                    padding: EdgeInsets.only(top: topPadding),
                    child: backdrop,
                  ),
                  
                  // Botones Superiores (Integrados en el scroll)
                  if (topBar != null)
                    Positioned(
                      top: topPadding, left: 0, right: 0,
                      child: SizedBox(
                        height: 80,
                        child: topBar!,
                      ),
                    ),

                  // Logo / Título
                  if (logo != null)
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxContentWidth),
                          child: SizedBox(
                            width: double.infinity,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                isWide ? horizontalPadding : 24, 
                                0, 
                                isWide ? horizontalPadding : 24, 
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
                    ),
                ],
              ),
            ),
          ),

          // 2. PANEL DE INFORMACIÓN
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: isWide ? horizontalPadding : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        if (meta != null) meta!,
                        const SizedBox(height: 20),
                        
                        if (isWide)
                          Row(
                            children: [
                              if (mainAction != null) SizedBox(width: 300, child: mainAction!),
                              if (secondaryActions != null) ...[
                                const SizedBox(width: 16),
                                Expanded(child: secondaryActions!), // Senior Fix: Evitar overflow en plegables (Fold)
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
          ),

          // 3. CONTENIDO (Tabs/Episodios)
          SliverMainAxisGroup(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: width > maxContentWidth 
                      ? (width - maxContentWidth) / 2 
                      : (isWide ? horizontalPadding.clamp(24.0, 100.0) : 24), // Senior Fix: Nunca menos de 24px
                ),
                sliver: content,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
