import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

/// Engancha la `SurfaceView` nativa de Android a mpv.
///
/// Es el único punto que escribe `vo`, `wid` y `android-surface-size`, de modo
/// que el player grande, el mini player y PiP comparten el mismo estado. El
/// `wid` destruido solo desconecta si sigue siendo el activo: así una
/// superficie vieja no apaga la nueva durante una transición.
class NativeVideoSurfaceBinder {
  NativeVideoSurfaceBinder._();

  static const MethodChannel _channel =
      MethodChannel('auris/mobile_video_surface');

  static Player? _player;
  static int? _viewId;
  static int? _wid;
  static int _videoW = 0;
  static int _videoH = 0;

  static int? get activeWid => _wid;
  static int? get activeViewId => _viewId;

  /// Conecta [wid] al player. Si la misma superficie cambia de tamaño (rotación,
  /// mini -> full), solo actualiza el tamaño y evita un reinit del decoder.
  static Future<void> attach({
    required Player player,
    required int viewId,
    required int wid,
    required int width,
    required int height,
  }) async {
    // El primer PlatformView de Flutter tiene id 0: es válido. Solo un id
    // negativo indica que la vista aún no está registrada.
    if (viewId < 0 || wid <= 0 || width <= 0 || height <= 0) return;

    final bool sameSurface = _wid == wid && identical(_player, player);
    debugPrint(
        '[native-surface] attach view=$viewId wid=$wid ${width}x$height '
        'same=$sameSurface player=${player.hashCode}');
    _player = player;
    _viewId = viewId;
    _wid = wid;
    if (!sameSurface) {
      _videoW = 0;
      _videoH = 0;
    }

    try {
      final dynamic platform = player.platform;
      if (!sameSurface) {
        await platform.setProperty('vo', 'null');
      }
      await platform.setProperty('android-surface-size', '${width}x$height');
      if (!sameSurface) {
        await platform.setProperty('wid', wid.toString());
        await platform.setProperty('vo', 'mediacodec_embed');
        await platform.setProperty('vid', 'auto');
      }
    } catch (e) {
      debugPrint('[native-surface] attach error: $e');
    }

    await updateVideoSize(player);
  }

  /// Desconecta la salida de video. Solo actúa si la superficie destruida es la
  /// activa; si otra ya tomó el relevo, la ignora.
  static Future<void> detach(
    Player? player, {
    int? viewId,
    int? wid,
  }) async {
    // Sin identificador no se puede saber si sigue siendo la superficie
    // activa: no apagar el video a ciegas.
    if (viewId == null && (wid == null || wid <= 0)) return;
    if (viewId != null && _viewId != null && viewId != _viewId) return;
    if (wid != null && wid > 0 && _wid != null && wid != _wid) return;
    // La superficie activa pertenece a otro motor: no apagarlo desde el
    // callback tardío del anterior.
    if (player != null && _player != null && !identical(player, _player)) return;

    debugPrint(
        '[native-surface] detach view=$viewId wid=$wid activeView=$_viewId '
        'activeWid=$_wid');
    _player = null;
    _viewId = null;
    _wid = null;
    _videoW = 0;
    _videoH = 0;

    try {
      final dynamic platform = player?.platform;
      await platform?.setProperty('vo', 'null');
    } catch (e) {
      debugPrint('[native-surface] detach error: $e');
    }
  }

  /// Empuja el tamaño real del video a la superficie activa.
  static Future<void> updateVideoSize(Player player) async {
    final int w = player.state.width ?? 0;
    final int h = player.state.height ?? 0;
    if (w <= 0 || h <= 0) return;
    if (w == _videoW && h == _videoH) return;

    _videoW = w;
    _videoH = h;

    final int? viewId = _viewId;
    if (viewId == null) return;

    try {
      await _channel.invokeMethod<void>(
        'setVideoSize',
        <String, int>{'viewId': viewId, 'width': w, 'height': h},
      );
    } catch (e) {
      debugPrint('[native-surface] setVideoSize error: $e');
    }
  }
}
