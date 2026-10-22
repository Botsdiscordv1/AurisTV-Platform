import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:auris_core/auris_core.dart';

typedef MobileSurfaceReady = void Function(
  int viewId,
  int wid,
  int width,
  int height,
);

typedef MobileSurfaceDestroyed = void Function(int viewId, int? wid);

/// Superficie de video nativa (Android `SurfaceView`) para el player de Móvil.
///
/// Igual que `TvVideoSurface` en TV: entrega a mpv el `android.view.Surface`
/// como `--wid` para que el frame vaya directo al display, sin la textura de
/// media_kit (`vo=gpu`), cuyo reinit inicial provoca el salto 0:05-0:20.
///
/// Varias instancias (player grande, mini player, PiP) comparten el canal. Un
/// registro global enruta los eventos por `viewId`; el widget nunca reemplaza
/// el handler de las demás superficies al montarse o desmontarse.
class MobileVideoSurface extends StatefulWidget {
  const MobileVideoSurface({
    super.key,
    required this.onSurface,
    this.onSurfaceDestroyed,
  });

  /// `wid` (ref JNI del `Surface`), ancho y alto en píxeles.
  final MobileSurfaceReady onSurface;

  final MobileSurfaceDestroyed? onSurfaceDestroyed;

  @override
  State<MobileVideoSurface> createState() => _MobileVideoSurfaceState();
}

class _MobileVideoSurfaceState extends State<MobileVideoSurface> {
  int? _viewId;
  int? _lastWid;

  @override
  void dispose() {
    final int? id = _viewId;
    if (id != null) {
      final int? wid = _lastWid;
      if (wid != null) {
        // Desconectar mpv antes de que el PlatformView libere la Surface.
        widget.onSurfaceDestroyed?.call(id, wid);
      }
      _MobileSurfaceRegistry.unregister(id);
      _viewId = null;
      _lastWid = null;
    }
    super.dispose();
  }

  void _onCreated(int viewId) {
    if (!mounted) return;
    _viewId = viewId;
    _MobileSurfaceRegistry.register(viewId, this);
    debugPrint('[MobileVideoSurface] created view=$viewId');
  }

  void _handleSurface(int viewId, int wid, int width, int height) {
    if (!mounted) return;
    _lastWid = wid;
    widget.onSurface(viewId, wid, width, height);
  }

  void _handleDestroyed(int viewId, int? wid) {
    if (!mounted) return;
    _lastWid = null;
    widget.onSurfaceDestroyed?.call(viewId, wid);
  }

  @override
  Widget build(BuildContext context) {
    // Mismo ajuste de 1px que TV para evitar el borde/ghost de Hybrid
    // Composition.
    return LayoutBuilder(
      builder: (context, constraints) {
        return OverflowBox(
          minWidth: constraints.maxWidth + 2,
          maxWidth: constraints.maxWidth + 2,
          minHeight: constraints.maxHeight + 2,
          maxHeight: constraints.maxHeight + 2,
          alignment: Alignment.center,
          child: _buildPlatformView(),
        );
      },
    );
  }

  Widget _buildPlatformView() {
    return PlatformViewLink(
      viewType: 'auris/mobile-video-surface',
      surfaceFactory: (context, controller) {
        return AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          hitTestBehavior: PlatformViewHitTestBehavior.transparent,
        );
      },
      onCreatePlatformView: (params) {
        // Registrar ANTES de create(): el primer surfaceChanged puede llegar
        // antes que el listener de creación y se perdería el wid (primer
        // montaje del player -> UI duplicada/frame congelado).
        _onCreated(params.id);
        // HCPP compone la PlatformView en el sistema (SurfaceControl) y evita
        // el snapshot de UI que Hybrid Composition deja encima del SurfaceView
        // hasta que cambia el layout. Si el device no lo soporta, usamos el
        // modo textura: Flutter compone la vista y no hay overlay HC.
        final AndroidViewController controller =
            VideoSurfaceConfig.useHybridAndroidView
                ? PlatformViewsService.initHybridAndroidView(
                    id: params.id,
                    viewType: params.viewType,
                    layoutDirection: TextDirection.ltr,
                    onFocus: () => params.onFocusChanged(true),
                  )
                : PlatformViewsService.initSurfaceAndroidView(
                    id: params.id,
                    viewType: params.viewType,
                    layoutDirection: TextDirection.ltr,
                    onFocus: () => params.onFocusChanged(true),
                  );
        debugPrint(
            '[MobileVideoSurface] mode=${VideoSurfaceConfig.useHybridAndroidView ? 'hcpp' : 'texture'} view=${params.id}');
        controller
          ..addOnPlatformViewCreatedListener((id) {
            _onCreated(id);
            params.onPlatformViewCreated(id);
            // Si la Surface ya existía antes de que el registro estuviera
            // listo, pedirla de nuevo. Es idempotente y solo reenvía wid.
            unawaited(_MobileSurfaceRegistry.requestSurface(id));
          })
          ..create();
        return controller;
      },
    );
  }
}

/// Superficie nativa ajustada al aspect ratio real del video.
///
/// Evita que un video 4:3 o 2.39:1 se estire en el mini player o en PiP.
class FittedMobileVideoSurface extends StatelessWidget {
  const FittedMobileVideoSurface({
    super.key,
    required this.player,
    required this.onSurface,
    this.onSurfaceDestroyed,
    this.fit = BoxFit.contain,
  });

  final Player player;
  final MobileSurfaceReady onSurface;
  final MobileSurfaceDestroyed? onSurfaceDestroyed;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int?>(
      stream: player.stream.width,
      initialData: player.state.width,
      builder: (context, widthSnap) {
        return StreamBuilder<int?>(
          stream: player.stream.height,
          initialData: player.state.height,
          builder: (context, heightSnap) {
            final int w = widthSnap.data ?? 0;
            final int h = heightSnap.data ?? 0;
            final double aspect = (w > 0 && h > 0) ? w / h : 16 / 9;
            return LayoutBuilder(
              builder: (context, constraints) {
                final double cw = constraints.maxWidth;
                final double ch = constraints.maxHeight;
                final Widget surface = MobileVideoSurface(
                  onSurface: onSurface,
                  onSurfaceDestroyed: onSurfaceDestroyed,
                );
                if (!cw.isFinite || !ch.isFinite || cw <= 0 || ch <= 0) {
                  return surface;
                }

                double sw;
                double sh;
                if (fit == BoxFit.fill) {
                  sw = cw;
                  sh = ch;
                } else if (fit == BoxFit.cover) {
                  if (cw / ch > aspect) {
                    sw = cw;
                    sh = cw / aspect;
                  } else {
                    sh = ch;
                    sw = ch * aspect;
                  }
                } else {
                  if (cw / ch > aspect) {
                    sh = ch;
                    sw = ch * aspect;
                  } else {
                    sw = cw;
                    sh = cw / aspect;
                  }
                }

                return OverflowBox(
                  alignment: Alignment.center,
                  minWidth: sw,
                  maxWidth: sw,
                  minHeight: sh,
                  maxHeight: sh,
                  child: surface,
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Enruta los eventos nativos de todas las superficies por `viewId`.
class _MobileSurfaceRegistry {
  _MobileSurfaceRegistry._();

  static const MethodChannel _channel =
      MethodChannel('auris/mobile_video_surface');
  static final Map<int, _MobileVideoSurfaceState> _states =
      <int, _MobileVideoSurfaceState>{};
  static bool _handlerInstalled = false;

  static void register(int viewId, _MobileVideoSurfaceState state) {
    _states[viewId] = state;
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler(_handleCall);
  }

  static void unregister(int viewId) {
    _states.remove(viewId);
  }

  /// Pide a la vista nativa que reenvíe su `wid` y tamaño actuales.
  static Future<void> requestSurface(int viewId) async {
    try {
      await _channel.invokeMethod<void>(
        'requestSurface',
        <String, int>{'viewId': viewId},
      );
    } catch (e) {
      debugPrint('[MobileVideoSurface] requestSurface error: $e');
    }
  }

  static Future<void> _handleCall(MethodCall call) async {
    final args = (call.arguments as Map?)?.cast<Object?, Object?>();
    final int? viewId = (args?['viewId'] as num?)?.toInt();
    if (viewId == null) return;

    final _MobileVideoSurfaceState? state = _states[viewId];
    if (state == null) return;

    switch (call.method) {
      case 'onSurface':
        state._handleSurface(
          viewId,
          (args?['wid'] as num?)?.toInt() ?? 0,
          (args?['width'] as num?)?.toInt() ?? 0,
          (args?['height'] as num?)?.toInt() ?? 0,
        );
        break;
      case 'onSurfaceDestroyed':
        state._handleDestroyed(
          viewId,
          (args?['wid'] as num?)?.toInt(),
        );
        break;
    }
  }
}
