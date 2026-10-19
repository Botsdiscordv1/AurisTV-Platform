import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../core/utils/tv_responsive_utils.dart';

/// Scroll de carruseles de TV.
class TvScroll {
  /// Ancla en la ranura inicial del carrusel: la tarjeta enfocada queda en la
  /// MISMA posición de pantalla que ocupa la primera tarjeta al inicio de la
  /// fila (borde izquierdo en el margen horizontal de la fila). La fila avanza
  /// de tarjeta en tarjeta y la seleccionada nunca cambia de sitio.
  ///
  /// Detalle del cálculo: `getOffsetToReveal(_, 0.0)` devuelve el offset donde
  /// el borde izquierdo de la tarjeta toca el borde izquierdo del viewport
  /// (ignora el padding de la fila), es decir su coordenada en contenido;
  /// restar el margen (`horizontalPadding`) la deja exactamente en la ranura
  /// de la primera tarjeta. Cerca del final de la fila el clamp del extent la
  /// deja lo más a la derecha posible (borde derecho simétrico).
  ///
  /// En scrollables verticales (rejillas) el ancla no aplica: se mantiene el
  /// centrado clásico para que la celda enfocada siga siendo visible.
  ///
  /// [leadingInset] = ancho de lo que precede a la tarjeta DENTRO de su
  /// elemento (p. ej. el número gigante del Top10). El ancla es entonces el
  /// inicio del ELEMENTO, no el del póster: número y tarjeta siempre juntos.
  static bool ensureCardVisible(
    BuildContext context, {
    Duration? duration,
    Curve curve = Curves.easeOutCubic,
    double leadingInset = 0,
    double alignment = 0.0,
  }) {
    final RenderObject? object = context.findRenderObject();
    if (object is! RenderBox || !object.attached) return false;
    final RenderAbstractViewport? viewport =
        RenderAbstractViewport.maybeOf(object);
    final ScrollableState? scrollable = Scrollable.maybeOf(context);
    if (viewport == null || scrollable == null) return false;
    final ScrollPosition position = scrollable.position;
    if (!position.hasContentDimensions) return false;

    if (position.axis != Axis.horizontal) {
      final double contentTop = viewport.getOffsetToReveal(object, 0.0).offset;
      final double target = (contentTop - 24.0)
          .clamp(position.minScrollExtent, position.maxScrollExtent);
      final double travel = (target - position.pixels).abs();
      if (travel < 1.0) return false;
      position.animateTo(
        target,
        duration: duration ?? _distanceDuration(travel),
        curve: curve,
      );
      return true;
    }

    final double contentLeft = viewport.getOffsetToReveal(object, 0.0).offset;
    final double anchor = TVResponsiveUtils.horizontalPadding(context);
    final double target = (contentLeft - leadingInset - anchor)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    final double travel = (target - position.pixels).abs();
    if (travel < 1.0) return false;
    position.animateTo(
      target,
      duration: duration ?? _distanceDuration(travel),
      curve: curve,
    );
    return true;
  }

  /// Ancla una sección (fila completa, título incluido) justo debajo del
  /// topbar fijo. Sustituye al centrado vertical: al navegar con el D-pad, la
  /// sección enfocada cae SIEMPRE en el mismo punto de pantalla — pegada bajo
  /// la barra — en paralelo con el ancla horizontal de [ensureCardVisible].
  /// Al final del scroll, el clamp del extent la deja lo más arriba posible.
  ///
  /// Se llama desde el nivel de fila (su contexto = borde superior de la
  /// sección) cuando el foco entra en su subárbol.
  static bool anchorSectionBelowTopbar(
    BuildContext context, {
    Duration? duration,
    Curve curve = Curves.easeOutCubic,
  }) {
    final RenderObject? object = context.findRenderObject();
    if (object is! RenderBox || !object.attached || !object.hasSize) {
      return false;
    }

    // Subir hasta el scrollable vertical (el de la fila es horizontal).
    ScrollableState? scrollable = Scrollable.maybeOf(context);
    while (scrollable != null &&
        scrollable.position.axis == Axis.horizontal) {
      scrollable = scrollable.context
          .findAncestorStateOfType<ScrollableState>();
    }
    if (scrollable == null) return false;
    final ScrollPosition position = scrollable.position;
    if (!position.hasContentDimensions) return false;

    // Objetivo: el borde superior de la sección a la altura del topbar
    // (barra fija en top:0 de la pantalla en TV, sin insets).
    final double sectionTop = object.localToGlobal(Offset.zero).dy;
    final double desiredTop = TVResponsiveUtils.topBarHeight(context);
    final double delta = sectionTop - desiredTop;
    if (delta.abs() < 1.0) return false;

    final double target = (position.pixels + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    final double travel = (target - position.pixels).abs();
    if (travel < 1.0) return false;
    // Duración proporcional al recorrido (estilo Leanback/Netflix
    // `setSelectedPositionSmooth`): saltos cortos, rápidos; largos, más suaves.
    position.animateTo(
      target,
      duration: duration ?? _distanceDuration(travel),
      curve: curve,
    );
    return true;
  }

  /// Duración del scroll proporcional a la distancia recorrida, imitando el
  /// `SmoothScroller` de Leanback que Netflix usa en el grid vertical
  /// (`setSelectedPositionSmooth`): base fija + fracción por píxel, acotada.
  static Duration _distanceDuration(
    double distance, {
    double base = 150,
    double perPixel = 0.32,
    int minMs = 200,
    int maxMs = 450,
  }) {
    final int ms = (base + distance * perPixel).round();
    return Duration(milliseconds: ms.clamp(minMs, maxMs));
  }

  /// Repite el ancla de [anchorSectionBelowTopbar] al cierre del frame.
  /// El traversal direccional de Flutter llama a `Scrollable.ensureVisible`
  /// DESPUÉS del `onFocusChange` de la fila, así que en el salto con D-pad
  /// ARRIBA el ensureVisible reescribe el scroll y la sección queda pegada al
  /// borde (bajo el topbar). Reanclar un frame después deja el ancla como
  /// última palabra, igual que al bajar.
  static void anchorSectionBelowTopbarDeferred(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) anchorSectionBelowTopbar(context);
    });
  }
}
