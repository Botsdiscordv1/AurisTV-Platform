import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Superficie de video nativa (Android `SurfaceView`) para el player TV.
///
/// Se compone con "Hybrid Composition" (`initExpensiveAndroidView`) para que el
/// `SurfaceView` viva en el view hierarchy real de Android y su superficie se
/// entregue a mpv (media_kit) como `--wid`. Así el frame decodificado va directo
/// al display (punch-out), sin pasar por el compositor de Flutter.
class TvVideoSurface extends StatefulWidget {
  const TvVideoSurface({
    super.key,
    required this.onSurface,
    this.onSurfaceDestroyed,
  });

  /// Notifica que la superficie está lista: `wid` (ref JNI del `Surface`), ancho
  /// y alto en píxeles.
  final void Function(int wid, int width, int height) onSurface;

  /// Notifica que la superficie fue destruida.
  final VoidCallback? onSurfaceDestroyed;

  @override
  State<TvVideoSurface> createState() => _TvVideoSurfaceState();
}

class _TvVideoSurfaceState extends State<TvVideoSurface> {
  static const MethodChannel _channel = MethodChannel('auris/tv_video_surface');

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
    return PlatformViewLink(
      viewType: 'auris/tv-video-surface',
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
