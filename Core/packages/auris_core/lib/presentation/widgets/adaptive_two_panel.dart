import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Layout two-panel adaptativo compartido (TV / Móvil / Web).
///
/// - Pantalla ancha (>= [breakpoint]): panel lateral derecho de altura
///   completa ([railWidth]) y video encogido a la izquierda con márgenes,
///   bordes redondeados y candado 16:9 opcional. Es el diseño del player de TV.
/// - Pantalla angosta: el video queda intacto y el panel aparece como hoja
///   inferior flotante con el mismo header y contenido.
///
/// El contenido del panel (listas) lo pone cada plataforma; aquí solo el
/// contenedor, el header con botón X circular estilo leanback y la trampa
/// opcional de D-pad ([trapFocus]: Atrás/B = [onBack]; izquierda y derecha se
/// CONTIENEN para no fugar el foco a los controles del video ni retroceder de
/// nivel, ya que el contenido es de una sola columna vertical).
///
/// Con [enableVideoFocus] (TV) el panel permite además saltar el foco al
/// contenedor de video: LEFT desde el panel enfoca el video y dibuja un borde
/// blanco de 3px; RIGHT vuelve al panel; OK/SELECT cierra el panel (el video
/// vuelve a pantalla completa). El resto de teclas del video (Atrás, izquierda
/// de seek) siguen burbujeando al reproductor.
class AurisTwoPanel extends StatefulWidget {
  final Widget video;

  /// Capas pintadas sobre el video pero DEBAJO del panel
  /// (spinners, indicadores de seek, etc.). Preserva el orden de pintado.
  final List<Widget> videoOverlays;

  final String panelTitle;
  final Widget panelContent;
  final bool panelOpen;
  final VoidCallback onDismiss;
  final bool dismissOnBackgroundTap;

  final FocusNode? closeFocusNode;
  final bool trapFocus;
  final VoidCallback? onBack;

  /// Muestra el botón X circular del header. Poner en `false` para plataformas
  /// que cierran/suben de nivel solo con el botón Atrás (p. ej. TV).
  final bool showCloseButton;

  final double railWidth;
  final double breakpoint;
  final double margin;
  final double panelGap;
  final double borderRadius;
  final bool lockAspect;

  /// Fracción máxima del ancho que puede ocupar el rail. Evita el reparto
  /// 50/50 en pantallas justas: el rail es `min(railWidth, ancho*fraction)`
  /// y el video conserva el resto.
  final double maxRailFraction;

  /// Habilita que, con el panel abierto, LEFT mueva el foco al contenedor de
  /// video (izquierda) y dibuje un borde blanco de 3px; RIGHT vuelve al panel.
  final bool enableVideoFocus;

  /// Duración y curva de la transición compacto (panel abierto) ↔ pantalla
  /// completa. Configurable por plataforma: el default (300 ms easeInOutCubic)
  /// mantiene el comportamiento histórico de Móvil/Web; TV puede acortarla para
  /// una expansión más rápida y fluida.
  final Duration animationDuration;
  final Curve animationCurve;

  /// Color que rellena las 4 esquinas del video cuando su superficie no puede
  /// recortarse (SurfaceView punch-out en TV): se pinta una máscara opaca sobre
  /// las esquinas para simular el redondeo. Si es null se confía en el recorte
  /// del [ClipRRect] (superficies con textura normal). Debe coincidir con el
  /// fondo que rodea al video para que la máscara sea invisible.
  final Color? cornerMaskColor;

  /// Radio visual de las esquinas del video (usado por la máscara y el borde de
  /// foco). Si es null se usa [borderRadius]. Permite mantener [borderRadius] en
  /// 0 (para no clipar el SurfaceView) y aun así redondear las esquinas.
  final double? videoCornerRadius;

  const AurisTwoPanel({
    super.key,
    required this.video,
    required this.panelTitle,
    required this.panelContent,
    required this.panelOpen,
    required this.onDismiss,
    this.dismissOnBackgroundTap = true,
    this.videoOverlays = const [],
    this.closeFocusNode,
    this.trapFocus = false,
    this.onBack,
    this.showCloseButton = true,
    this.railWidth = 460,
    this.breakpoint = 800,
    this.margin = 32,
    this.panelGap = 12,
    this.borderRadius = 16,
    this.lockAspect = true,
    this.maxRailFraction = 0.35,
    this.enableVideoFocus = false,
    this.animationDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeInOutCubic,
    this.cornerMaskColor,
    this.videoCornerRadius,
  });

  @override
  State<AurisTwoPanel> createState() => _AurisTwoPanelState();
}

class _AurisTwoPanelState extends State<AurisTwoPanel> {
  /// Nodo del contenedor de video. `debugLabel == 'video_surface'` para que el
  /// reproductor trate LEFT/RIGHT como seek cuando el video tiene el foco.
  /// `skipTraversal` para que nunca se alcance por navegación normal: solo se
  /// enfoca explícitamente con LEFT desde el panel.
  final FocusNode _videoFocusNode =
      FocusNode(debugLabel: 'video_surface', skipTraversal: true);

  /// Nodo de la trampa del panel (fallback al volver del video).
  final FocusNode _panelFocusNode = FocusNode(debugLabel: 'two_panel_list');

  /// Último nodo enfocado dentro del panel (para devolverle el foco con RIGHT).
  FocusNode? _lastPanelFocus;

  /// El video solo muestra el borde de foco cuando el usuario lo pidió con LEFT.
  /// Evita que el foco transitorio del video al abrir el panel encienda el borde
  /// durante la animación de encogido.
  bool _videoFocusRequested = false;

  @override
  void initState() {
    super.initState();
    _videoFocusNode.addListener(_onVideoFocusChanged);
  }

  @override
  void dispose() {
    _videoFocusNode.removeListener(_onVideoFocusChanged);
    _videoFocusNode.dispose();
    _panelFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(AurisTwoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Al ABRIR el panel (transición cerrado→abierto) el foco debe quedar en el
    // primer item de la lista. No aplica al cambiar de menú/submenú ni al
    // volver desde un submenú (el panel ya estaba abierto), donde el autofocus
    // de cada selector gestiona el item (opción actual / item que lo abrió).
    if (widget.enableVideoFocus &&
        !oldWidget.panelOpen &&
        widget.panelOpen) {
      // Apertura limpia: el borde de video no debe estar activo.
      _videoFocusRequested = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.panelOpen) return;
        final FocusNode? first = _firstItemNode();
        if (first != null && first.canRequestFocus) first.requestFocus();
      });
    }
    // Al CERRAR el panel (abierto→cerrado) apagamos de inmediato el borde de
    // foco del video: si esperásemos a que el nodo pierda el foco, el borde de
    // 3px alcanzaría a verse sobre el video ya a pantalla completa durante la
    // animación de expansión (bug visual al pulsar OK sobre el video).
    if (oldWidget.panelOpen && !widget.panelOpen) {
      _videoFocusRequested = false;
    }
  }

  /// Primer item enfocable de la lista del panel (la tarjeta, no el InkWell
  /// interno). Devuelve null si el panel aún no está montado.
  FocusNode? _firstItemNode() {
    for (final FocusNode node in _panelFocusNode.traversalDescendants) {
      FocusNode target = node;
      while (target.parent != null && target.parent != _panelFocusNode) {
        target = target.parent!;
      }
      if (target.canRequestFocus) return target;
    }
    return null;
  }

  void _onVideoFocusChanged() {
    if (!_videoFocusNode.hasFocus) _videoFocusRequested = false;
    if (mounted) setState(() {});
  }

  void _focusVideo() {
    _lastPanelFocus = FocusManager.instance.primaryFocus;
    _videoFocusRequested = true;
    _videoFocusNode.requestFocus();
  }

  void _focusPanel() {
    final FocusNode? target = _lastPanelFocus;
    if (target != null) {
      try {
        if (target.canRequestFocus) {
          target.requestFocus();
          return;
        }
      } catch (_) {
        // El nodo pudo quedar huérfano (contenido del panel recreado).
      }
    }
    if (_panelFocusNode.canRequestFocus) _panelFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool wide = constraints.maxWidth >= widget.breakpoint;
        final bool showRail = widget.panelOpen && wide;
        final double effectiveRail = showRail
            ? (widget.railWidth < constraints.maxWidth * widget.maxRailFraction
                ? widget.railWidth
                : constraints.maxWidth * widget.maxRailFraction)
            : widget.railWidth;

        final Widget panel = wide
            ? _buildRail(context, effectiveRail)
            : _buildSheet(context, constraints);

        final Widget trapped =
            (widget.trapFocus && widget.panelOpen) ? _trap(panel) : panel;

        // Con [lockAspect], cuando el panel está abierto el área de video se
        // ajusta a 16:9 mediante padding vertical: así el video la rellena por
        // completo y el redondeo del contenedor coincide con el del propio
        // video. La ESTRUCTURA del subárbol NO cambia (sigue siendo
        // `ClipRRect(video)`), evitando recrear el PlatformView (SurfaceView) en
        // Hybrid Composition.
        double verticalPad = widget.margin;
        if (showRail && widget.lockAspect) {
          final double videoW = constraints.maxWidth -
              widget.margin -
              (effectiveRail + widget.panelGap);
          final double videoH = videoW * 9 / 16;
          final double availH = constraints.maxHeight - 2 * widget.margin;
          if (videoW > 0 && videoH > 0 && videoH <= availH) {
            verticalPad = (constraints.maxHeight - videoH) / 2;
          }
        }

        final double visualRadius =
            showRail ? (widget.videoCornerRadius ?? widget.borderRadius) : 0;

        final Widget videoArea = _wrapVideoFocus(
          ClipRRect(
            borderRadius:
                BorderRadius.circular(showRail ? widget.borderRadius : 0),
            child: widget.video,
          ),
          visualRadius,
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            AnimatedPadding(
              duration: widget.animationDuration,
              curve: widget.animationCurve,
              padding: showRail
                  ? EdgeInsets.fromLTRB(widget.margin, verticalPad,
                      effectiveRail + widget.panelGap, verticalPad)
                  : EdgeInsets.zero,
              child: videoArea,
            ),
            ...widget.videoOverlays,
            if (widget.panelOpen)
              Positioned.fill(
                child: Stack(
                  children: [
                    if (widget.dismissOnBackgroundTap)
                      GestureDetector(
                        onTap: widget.onDismiss,
                        behavior: HitTestBehavior.opaque,
                        child: Container(color: Colors.transparent),
                      ),
                    trapped,
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  /// Envuelve el contenedor de video con el foco + borde blanco (TV) y, si
  /// [AurisTwoPanel.cornerMaskColor] está definido, con la máscara de esquinas
  /// (para superficies que no se pueden recortar).
  Widget _wrapVideoFocus(Widget child, double radius) {
    Widget content = child;
    if (widget.cornerMaskColor != null) {
      // CustomPaint con foregroundPainter (NO un Stack): el Stack añade por
      // defecto una capa de RECORTE ancestra del SurfaceView, que en Hybrid
      // Composition fuerza el modo overlay y deja el video en negro. CustomPaint
      // pinta encima sin recortar ni crear capa, igual que el
      // foregroundDecoration del borde (que sí funciona).
      //
      // IMPORTANTE: el CustomPaint se añade SIEMPRE (aunque `radius` sea 0 y el
      // painter no pinte nada). En la ruta SurfaceView el árbol por ENCIMA del
      // PlatformView debe ser ESTRUCTURALMENTE ESTABLE: si este nodo sólo
      // apareciera al abrir el panel (radius>0), Flutter reconstruiría el
      // PlatformView (nuevo wid) y el video quedaría negro al abrir el rail.
      content = CustomPaint(
        foregroundPainter: _CornerMaskPainter(
          radius: radius,
          color: widget.cornerMaskColor!,
        ),
        child: child,
      );
    }
    if (!widget.enableVideoFocus) return content;
    // El borde solo existe con el panel abierto y el foco pedido en el video.
    final bool showBorder =
        widget.panelOpen && _videoFocusRequested && _videoFocusNode.hasFocus;
    return Focus(
      focusNode: _videoFocusNode,
      // Solo focusable con el panel abierto: al cerrarse el video suelta el
      // foco y no queda el borde encendido; al abrir, el foco va a la lista.
      canRequestFocus: widget.panelOpen,
      onKeyEvent: (node, event) {
        // El foco de video envuelve TODOS los controles (header, pills,
        // timeline): solo se consume la tecla cuando el propio contenedor de
        // video tiene el foco, para no romper la navegación por los controles.
        if (FocusManager.instance.primaryFocus != _videoFocusNode) {
          return KeyEventResult.ignored;
        }
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          final key = event.logicalKey;
          // RIGHT vuelve al panel. LEFT/Atrás burbujean al reproductor
          // (seek / cerrar).
          if (key == LogicalKeyboardKey.arrowRight) {
            _focusPanel();
            return KeyEventResult.handled;
          }
          // OK/SELECT con el foco en el video cierra el panel: el video vuelve
          // a pantalla completa (se consume para que no alterne play/pausa).
          if (key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.numpadEnter ||
              key == LogicalKeyboardKey.space) {
            widget.onDismiss();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: AnimatedContainer(
        // Al MOSTRAR el borde animamos brevemente; al QUITARLO (p. ej. al
        // cerrar el panel) debe ser instantáneo, o el borde de 3px se alcanza
        // a ver sobre el video ya a pantalla completa.
        duration: showBorder
            ? const Duration(milliseconds: 120)
            : Duration.zero,
        curve: Curves.easeOut,
        // foregroundDecoration: el borde se pinta ENCIMA del video para que
        // no lo tape el ClipRRect interno. Solo con el panel abierto y cuando
        // el usuario pidió el foco del video (LEFT): evita el borde durante la
        // animación de apertura por el foco transitorio del video.
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: showBorder ? Border.all(color: Colors.white, width: 3) : null,
        ),
        child: content,
      ),
    );
  }

  Widget _trap(Widget panel) {
    // Sin onBack explícito, Back equivale a la X (onDismiss).
    final VoidCallback back = widget.onBack ?? widget.onDismiss;
    return Focus(
      focusNode: _panelFocusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          final key = event.logicalKey;
          // Atrás (botón B/ESC y back del sistema) = subir un nivel o cerrar.
          if (key == LogicalKeyboardKey.goBack ||
              key == LogicalKeyboardKey.escape ||
              key == LogicalKeyboardKey.browserBack) {
            back();
            return KeyEventResult.handled;
          }
          // LEFT salta el foco al contenedor de video (TV). El panel es de una
          // sola columna vertical, así que no debe ni retroceder de nivel ni
          // fugar el foco a otros controles.
          if (key == LogicalKeyboardKey.arrowLeft) {
            if (widget.enableVideoFocus) _focusVideo();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowRight) {
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: panel,
    );
  }

  /// Rail derecho de altura completa, fondo sólido, pegado al borde.
  Widget _buildRail(BuildContext context, double effectiveRail) {
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: const Color(0xFF0F0F0F),
        elevation: 0,
        child: Container(
          width: effectiveRail,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF0F0F0F),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _panelHeader(context),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: widget.panelContent,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// Hoja inferior flotante para pantallas angostas.
  Widget _buildSheet(BuildContext context, BoxConstraints constraints) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        child: Material(
          color: const Color(0xFF0F0F0F),
          elevation: 0,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: constraints.maxHeight * 0.62,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _panelHeader(context),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: widget.panelContent,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _panelHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 18, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              widget.panelTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (widget.showCloseButton)
            _PanelCloseButton(
              onClose: widget.onDismiss,
              focusNode: widget.closeFocusNode,
            ),
        ],
      ),
    );
  }
}

/// Botón X circular estilo leanback: cápsula gris translúcida en reposo,
/// blanca con icono negro al enfocar.
class _PanelCloseButton extends StatelessWidget {  final VoidCallback onClose;
  final FocusNode? focusNode;

  const _PanelCloseButton({required this.onClose, this.focusNode});

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      // OK del mando (select) no tiene binding por defecto: se activa aquí.
      // Solo KeyDown para no repetir el cierre al mantener pulsado.
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.numpadEnter ||
              key == LogicalKeyboardKey.space) {
            onClose();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final bool isFocused = Focus.of(context).hasFocus;
          return AnimatedScale(
            scale: isFocused ? 1.12 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFocused
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.12),
                border: isFocused
                    ? Border.all(color: Colors.white, width: 2)
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onClose,
                  focusColor: Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                  child: Center(
                    child: Icon(
                      Icons.close_rounded,
                      color: isFocused ? Colors.black : Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Pinta una máscara opaca en las 4 esquinas de su área para simular esquinas
/// redondeadas cuando la superficie del video no puede recortarse (SurfaceView
/// punch-out). El color debe coincidir con el fondo que rodea al video.
class _CornerMaskPainter extends CustomPainter {
  final double radius;
  final Color color;

  const _CornerMaskPainter({required this.radius, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 0 || size.isEmpty) return;
    final Rect outer = Offset.zero & size;
    final Path corners = Path()
      ..addRect(outer)
      ..addRRect(RRect.fromRectAndRadius(outer, Radius.circular(radius)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(corners, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CornerMaskPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.color != color;
}
