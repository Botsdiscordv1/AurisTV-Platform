import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Salto vertical determinista para D-pad en TV.
///
/// Desde el foco actual, mueve el foco al primer elemento (más a la izquierda)
/// de la fila de abajo. El traversal direccional geométrico de Flutter cae
/// bajo el centro del widget actual: desde una wide card (ancha) aterriza en
/// un poster intermedio en vez del primero.
class TvDirectionalFocus {
  /// Candidatos elegibles: mismo filtro que
  /// FocusScopeNode.traversalDescendants (el que usa el traversal oficial).
  /// NO caminar ancestros mirando su _skipTraversal propio: ese flag no se
  /// hereda hacia abajo (solo lo hace descendantsAreTraversable) y mataría
  /// el árbol completo.
  static Iterable<FocusNode> _eligible(FocusNode current) sync* {
    for (final node in FocusManager.instance.rootScope.descendants) {
      if (identical(node, current)) continue;
      if (node.skipTraversal || !node.canRequestFocus) continue;
      // Fuera de la cadena del foco actual (scopes, botón X interno).
      var inChain = false;
      for (final a in current.ancestors) {
        if (identical(a, node)) {
          inChain = true;
          break;
        }
      }
      if (inChain) continue;
      var childOfCurrent = false;
      for (final a in node.ancestors) {
        if (identical(a, current)) {
          childOfCurrent = true;
          break;
        }
      }
      if (childOfCurrent) continue;
      yield node;
    }
  }

  /// Enfoca la tarjeta de la fila de abajo conservando la columna.
  ///
  /// Con [preserveColumn] = true (por defecto) elige, dentro de la fila
  /// inmediatamente inferior, la tarjeta con MAYOR solape horizontal con la
  /// actual; a igualdad, la más a la izquierda. Así una wide/billboard (que
  /// cubre varias columnas) baja a la PRIMERA de su columna y un póster baja al
  /// de su misma columna. Solo si no hay solape alguno (fila destino desplazada)
  /// cae en la de centro horizontal más cercano. Con false conserva el
  /// comportamiento previo (primera tarjeta de la fila de abajo), que usa el hero.
  static bool focusFirstBelow({bool preserveColumn = true}) {
    final current = FocusManager.instance.primaryFocus;
    if (current == null) return false;
    late final Rect curRect;
    try {
      curRect = current.rect;
    } catch (_) {
      return false;
    }

    // Tops dentro de esta tolerancia se consideran la misma fila.
    const rowTolerance = 24.0;
    final below = <MapEntry<FocusNode, Rect>>[];
    var bandTop = double.infinity;

    for (final node in _eligible(current)) {
      late final Rect r;
      try {
        r = node.rect;
      } catch (_) {
        continue;
      }
      if (r.width <= 0 || r.height <= 0) continue;
      // Estrictamente debajo (con tolerancia de solape).
      if (r.top < curRect.bottom - 8) continue;
      below.add(MapEntry(node, r));
      if (r.top < bandTop) bandTop = r.top;
    }
    if (below.isEmpty) return false;

    FocusNode? best;
    if (preserveColumn) {
      // Máximo solape horizontal con la tarjeta actual; a igualdad, la más a la
      // izquierda. Así una wide/billboard (que cubre varias columnas) baja a la
      // PRIMERA de su columna, y un póster baja al de su misma columna.
      final double curLeft = curRect.left;
      final double curRight = curRect.right;
      var bestOverlap = -1.0;
      var bestLeft = double.infinity;
      FocusNode? bestOverlapping;
      for (final e in below) {
        if ((e.value.top - bandTop).abs() > rowTolerance) continue;
        final double ovLeft = e.value.left > curLeft ? e.value.left : curLeft;
        final double ovRight = e.value.right < curRight ? e.value.right : curRight;
        final double overlap = ovRight > ovLeft ? ovRight - ovLeft : 0.0;
        if (overlap > bestOverlap + 0.5 ||
            ((overlap - bestOverlap).abs() <= 0.5 && e.value.left < bestLeft)) {
          bestOverlapping = e.key;
          bestOverlap = overlap;
          bestLeft = e.value.left;
        }
      }
      if (bestOverlap > 0.5) {
        best = bestOverlapping;
      } else {
        // Sin solape (fila destino desplazada): la de centro más cercano.
        final double curCenterX = curRect.center.dx;
        var bestDist = double.infinity;
        var nearestLeft = double.infinity;
        for (final e in below) {
          if ((e.value.top - bandTop).abs() > rowTolerance) continue;
          final double dist = (e.value.center.dx - curCenterX).abs();
          if (dist < bestDist - 0.5 ||
              ((dist - bestDist).abs() <= 0.5 && e.value.left < nearestLeft)) {
            best = e.key;
            bestDist = dist;
            nearestLeft = e.value.left;
          }
        }
      }
    } else {
      var bestLeft = double.infinity;
      for (final e in below) {
        if ((e.value.top - bandTop).abs() > rowTolerance) continue;
        if (e.value.left < bestLeft) {
          best = e.key;
          bestLeft = e.value.left;
        }
      }
    }

    if (best == null) return false;
    best.requestFocus();
    return true;
  }

  /// Espejo de [focusFirstBelow] hacia arriba, para tarjetas wide/poster:
  /// solo interviene cuando la fila de arriba está VACÍA en la columna de la
  /// tarjeta actual (el traversal geométrico saltaría la fila). Si la fila de
  /// arriba tiene algo alineado en horizontal, devuelve false y el traversal
  /// normal de Flutter se encarga.
  static bool focusFirstAboveIfEmpty() {
    final current = FocusManager.instance.primaryFocus;
    if (current == null) return false;
    late final Rect curRect;
    try {
      curRect = current.rect;
    } catch (_) {
      return false;
    }

    // Candidatos estrictamente arriba con sus rects.
    final above = <MapEntry<FocusNode, Rect>>[];
    for (final node in _eligible(current)) {
      late final Rect r;
      try {
        r = node.rect;
      } catch (_) {
        continue;
      }
      if (r.width <= 0 || r.height <= 0) continue;
      // Estrictamente arriba (con tolerancia de solape).
      if (r.bottom > curRect.top + 8) continue;
      above.add(MapEntry(node, r));
    }
    if (above.isEmpty) return false;

    // Fila más cercana por arriba: la de bottom máximo.
    const rowTolerance = 24.0;
    var bandBottom = double.negativeInfinity;
    for (final e in above) {
      if (e.value.bottom > bandBottom) bandBottom = e.value.bottom;
    }

    FocusNode? best;
    var bestLeft = double.infinity;
    var alignedInRow = false;
    for (final e in above) {
      if ((bandBottom - e.value.bottom).abs() > rowTolerance) continue;
      // ¿Algo alineado horizontalmente en esta fila?
      if (e.value.right >= curRect.left && e.value.left <= curRect.right) {
        alignedInRow = true;
        break;
      }
      // Primero (más a la izquierda) de la fila.
      if (e.value.left < bestLeft) {
        best = e.key;
        bestLeft = e.value.left;
      }
    }

    // La fila de arriba alcanza esta columna: comportamiento normal.
    if (alignedInRow) return false;
    if (best == null) return false;
    best.requestFocus();
    return true;
  }
}

class TVFocusWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;
  final bool showBorder;
  final Duration duration;
  final FocusNode? focusNode;
  final bool autoScroll;

  const TVFocusWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 1.08,
    this.showBorder = true,
    this.duration = const Duration(milliseconds: 200),
    this.focusNode,
    this.autoScroll = true,
  });

  @override
  State<TVFocusWrapper> createState() => _TVFocusWrapperState();
}

class _TVFocusWrapperState extends State<TVFocusWrapper> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });

      if (_isFocused && widget.autoScroll) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_onFocusChange);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.space) {
            widget.onTap?.call();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isFocused ? widget.scaleFactor : 1.0,
          duration: widget.duration,
          curve: Curves.easeOutBack,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: widget.showBorder && _isFocused
                  ? Border.all(color: Colors.white, width: 2.0)
                  : Border.all(color: Colors.transparent, width: 2.0),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.15),
                        blurRadius: 15,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
