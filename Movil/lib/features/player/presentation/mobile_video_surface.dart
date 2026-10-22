import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Superficie de video nativa (Android `SurfaceView`) para el player de Móvil.
///
/// Igual que `TvVideoSurface` en TV: entrega a mpv el `android.view.Surface`
/// como `--wid` para que el frame vaya directo al display, sin la textura de
/// media_kit (`vo=gpu`), cuyo reinit inicial provoca el salto 0:05-0:20.
class MobileVideoSurface extends StatefulWidget {
  const MobileVideoSurface({
    super.key,
    required this.onSurface,
    this.onSurfaceDestroyed,
  });

  /// `wid` (ref JNI del `Surface`), ancho y alto en píxeles.
  final void Function(int wid, int width, int height) onSurface;

  final VoidCallback? onSurfaceDestroyed;

  @override
  State<MobileVideoSurface> createState() => _MobileVideoSurfaceState();
}

class _MobileVideoSurfaceState extends State<MobileVideoSurface> {
  static const MethodChannel _channel =
      MethodChannel('auris/mobile_video_surface');

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_handleCall);
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _handleCall(MethodCall call) async {
    switch (call.method) {
      case 'onSurface':
        final args = (call.arguments as Map).cast<Object?, Object?>();
        widget.onSurface(
          (args['wid'] as num).toInt(),
          (args['width'] as num).toInt(),
          (args['height'] as num).toInt(),
        );
        break;
      case 'onSurfaceDestroyed':
        widget.onSurfaceDestroyed?.call();
        break;
    }
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
        return PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: params.viewType,
          layoutDirection: TextDirection.ltr,
          onFocus: () => params.onFocusChanged(true),
        )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create();
      },
    );
  }
}
