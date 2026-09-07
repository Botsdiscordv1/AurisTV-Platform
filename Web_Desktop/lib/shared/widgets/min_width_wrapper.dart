import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../core/utils/responsive_utils.dart';

/// Un wrapper senior que garantiza un ancho mínimo para la versión Web/Desktop.
/// Si el viewport es menor a [minWidth], activa un scroll horizontal y
/// sobrescribe el MediaQuery para proteger la integridad del layout.
/// El valor por defecto es [Breakpoint.lg] (1024dp).
class MinWidthWrapper extends StatefulWidget {
  final Widget child;
  final double minWidth;

  const MinWidthWrapper({
    super.key,
    required this.child,
    this.minWidth = 360, // Cambiado de 1024 para permitir breakpoints adaptativos
  });

  @override
  State<MinWidthWrapper> createState() => _MinWidthWrapperState();
}

class _MinWidthWrapperState extends State<MinWidthWrapper> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Solo aplicamos la restricción en Web/WebView2 Desktop si NO es una plataforma móvil.
    // Esto permite que "Web (Móvil)" reutilice el diseño nativo de la app.
    if (!kIsWeb) return widget.child;

    if (ResponsiveUtils.isMobilePlatform) return widget.child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        final double screenHeight = constraints.maxHeight;

        // Si el ancho real es suficiente, no intervenimos.
        if (screenWidth >= widget.minWidth) return widget.child;

        // Si el ancho es menor al límite, forzamos un contenedor de ancho fijo
        // y permitimos el desplazamiento horizontal (solo para Desktop Web).
        return Scrollbar(
          controller: _scrollController,
          thumbVisibility: true, // Forzamos visibilidad para feedback visual
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: widget.minWidth,
              height: screenHeight,
              child: MediaQuery(
                // Sobrescribimos el MediaQuery para que la app interna use el escalado
                // y los breakpoints correspondientes a [widget.minWidth].
                data: MediaQuery.of(context).copyWith(
                  size: Size(widget.minWidth, screenHeight),
                ),
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}
