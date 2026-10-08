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
/// opcional de D-pad ([trapFocus]: izquierda/atrás = [onBack], derecha se
/// contiene para no fugar el foco a los controles del video).
class AurisTwoPanel extends StatelessWidget {
  final Widget video;

  /// Capas pintadas sobre el video pero DEBAJO del panel
  /// (spinners, indicadores de seek, etc.). Preserva el orden de pintado.
  final List<Widget> videoOverlays;

  final String panelTitle;
  final Widget panelContent;
  final bool panelOpen;
  final VoidCallback onDismiss;

  final FocusNode? closeFocusNode;
  final bool trapFocus;
  final VoidCallback? onBack;

  final double railWidth;
  final double breakpoint;
  final double margin;
  final double borderRadius;
  final bool lockAspect;

  /// Fracción máxima del ancho que puede ocupar el rail. Evita el reparto
  /// 50/50 en pantallas justas: el rail es `min(railWidth, ancho*fraction)`
  /// y el video conserva el resto.
  final double maxRailFraction;

  const AurisTwoPanel({
    super.key,
    required this.video,
    required this.panelTitle,
    required this.panelContent,
    required this.panelOpen,
    required this.onDismiss,
    this.videoOverlays = const [],
    this.closeFocusNode,
    this.trapFocus = false,
    this.onBack,
    this.railWidth = 460,
    this.breakpoint = 800,
    this.margin = 32,
    this.borderRadius = 20,
    this.lockAspect = true,
    this.maxRailFraction = 0.35,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool wide = constraints.maxWidth >= breakpoint;
        final bool showRail = panelOpen && wide;
        final double effectiveRail = showRail
            ? (railWidth < constraints.maxWidth * maxRailFraction
                ? railWidth
                : constraints.maxWidth * maxRailFraction)
            : railWidth;

        final Widget panel = wide
            ? _buildRail(context, effectiveRail)
            : _buildSheet(context, constraints);

        final Widget trapped =
            (trapFocus && panelOpen) ? _trap(panel) : panel;

        return Stack(
          fit: StackFit.expand,
          children: [
            AnimatedPadding(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              padding: showRail
                  ? EdgeInsets.fromLTRB(
                      margin, margin, effectiveRail + margin, margin)
                  : EdgeInsets.zero,
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(showRail ? borderRadius : 0),
                child: (showRail && lockAspect)
                    ? Center(
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: video,
                        ),
                      )
                    : video,
              ),
            ),
            ...videoOverlays,
            if (panelOpen)
              Positioned.fill(
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: onDismiss,
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

  Widget _trap(Widget panel) {
    // Sin onBack explícito, Back equivale a la X (onDismiss).
    final VoidCallback back = onBack ?? onDismiss;
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.arrowLeft ||
              key == LogicalKeyboardKey.goBack ||
              key == LogicalKeyboardKey.escape ||
              key == LogicalKeyboardKey.browserBack) {
            back();
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
                  child: panelContent,
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
                    child: panelContent,
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
              panelTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _PanelCloseButton(onClose: onDismiss, focusNode: closeFocusNode),
        ],
      ),
    );
  }
}

/// Botón X circular estilo leanback: cápsula gris translúcida en reposo,
/// blanca con icono negro al enfocar.
class _PanelCloseButton extends StatelessWidget {
  final VoidCallback onClose;
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
