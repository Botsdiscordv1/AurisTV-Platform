import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

@JS('document')
external JSObject get _document;

@JS('fetch')
external JSPromise<JSObject> _jsFetch(JSString input, JSObject init);

/// Valores medidos en el APK de YouTube (clase `kjv`, config cinemática):
///  * refresco del frame: 5000 ms (adelanto de 4500 ms), crossfade 2500 ms (0,5×).
///  * escala del fondo: 2,0 × 2,0 (`kjv.f` → `kjw(2.0f, 2.0f)`).
///  * radio del degradado: mitad del lado menor del vídeo, en dp (`rkd.b`).
///  * **no hay blur en el cliente**: en el APK ningún `BlurMaskFilter` ni
///    `RenderEffect` toca el bitmap cinemático; llega ya difuminado desde el
///    pipeline de miniaturas. Aquí se copia el frame sin `filter: blur()`: el
///    suavizado lo da el reescalado del buffer diminuto y el degradado radial lo
///    pone la máscara geométrica que aplica [AmbientVideoLayer].
const int _kBufferWidth = 110;
const int _kBufferHeight = 75;

/// Copia el frame actual del `<video>` a un buffer diminuto.
///
/// El buffer de 110×75 es lo que da el degradado al estirarlo sobre el halo: al
/// reducir tanto se promedian los píxeles y queda el color del cuadro sin
/// detalle, sin necesidad de desenfocar.
Uint8List? sampleVideoAmbientFrameImpl() {
  try {
    final video = _findVideo();
    if (video == null) return null;

    // Un `<video>` con `src` http(s) de otro origen y sin `crossOrigin` deja el
    // canvas contaminado: `drawImage` funciona pero `toDataURL` lanza
    // `SecurityError`. Los MP4 directos (proxy) caen en ese caso, los HLS no
    // (hls.js los sirve por MSE con `blob:`). Si el servidor permite CORS se
    // activa `crossOrigin='anonymous'` para poder leer los píxeles.
    _ensureCorsReadable(video);

    final int videoWidth =
        video.getProperty<JSNumber?>('videoWidth'.toJS)?.toDartInt ?? 0;
    if (videoWidth <= 0) return null;

    final canvas = _document.callMethod<JSObject>(
      'createElement'.toJS,
      'canvas'.toJS,
    );
    canvas.setProperty('width'.toJS, _kBufferWidth.toJS);
    canvas.setProperty('height'.toJS, _kBufferHeight.toJS);

    final ctx = canvas.callMethod<JSObject?>('getContext'.toJS, '2d'.toJS);
    if (ctx == null) return null;

    ctx.callMethodVarArgs<JSAny?>(
      'drawImage'.toJS,
      <JSAny>[
        video,
        0.toJS,
        0.toJS,
        _kBufferWidth.toJS,
        _kBufferHeight.toJS,
      ],
    );

    final dataUrl = canvas.callMethod<JSString>('toDataURL'.toJS, 'image/png'.toJS);
    final String text = dataUrl.toDart;
    final int comma = text.indexOf(',');
    if (comma < 0) return null;
    return base64Decode(text.substring(comma + 1));
  } catch (_) {
    // Canvas contaminado o API no disponible: se usa el arte del contenido.
    return null;
  }
}

/// El `<video>` que media_kit monta como platform view. Se elige el de mayor
/// tamaño para no confundirlo con carteles u otros vídeos de la página.
JSObject? _findVideo() {
  final nodes = _document.callMethod<JSObject>(
    'querySelectorAll'.toJS,
    'video'.toJS,
  );
  final length = nodes.getProperty<JSNumber>('length'.toJS).toDartInt;
  JSObject? best;
  int bestArea = 0;
  for (int i = 0; i < length; i++) {
    final node = nodes.callMethod<JSObject?>('item'.toJS, i.toJS);
    if (node == null) continue;
    final int w = node.getProperty<JSNumber?>('videoWidth'.toJS)?.toDartInt ?? 0;
    final int h = node.getProperty<JSNumber?>('videoHeight'.toJS)?.toDartInt ?? 0;
    final int area = w * h;
    if (area > bestArea) {
      bestArea = area;
      best = node;
    }
  }
  return best;
}

/// Resultado de la sonda CORS por URL: `'pending'`, `'ok'` o `'rejected'`.
/// Se guarda en `globalThis` para sobrevivir a los rebuilds y no repetir la
/// petición cada 5 s.
JSObject _corsCache() {
  final JSObject? existing =
      globalContext.getProperty<JSObject?>('__aurisAmbientCors'.toJS);
  if (existing != null) return existing;
  final JSObject fresh = JSObject();
  globalContext.setProperty('__aurisAmbientCors'.toJS, fresh);
  return fresh;
}

/// Deja el `<video>` en un estado legible desde canvas, sin romper el playback.
///
/// Solo actúa con `src` http(s) de otro origen (un `blob:` de MSE nunca
/// contamina). Antes de tocar nada sondea el servidor con un `GET` simple
/// (`HEAD` no está soportado por el proxy y `Range` dispararía preflight, que
/// el proxy tampoco permite); si responde CORS se reabre el mismo `src` con
/// `crossOrigin='anonymous'` conservando posición y reproducción. Si el medio
/// falla al recargar, se revierte al modo normal.
void _ensureCorsReadable(JSObject video) {
  final String src =
      video.getProperty<JSString?>('currentSrc'.toJS)?.toDart ?? '';
  if (src.isEmpty) return;
  if (!src.startsWith('http://') && !src.startsWith('https://')) return;

  final Uri? uri = Uri.tryParse(src);
  if (uri == null || uri.origin == Uri.base.origin) return;

  final JSObject cache = _corsCache();
  final String? state = cache.getProperty<JSString?>(src.toJS)?.toDart;
  final String crossOrigin =
      video.getProperty<JSString?>('crossOrigin'.toJS)?.toDart ?? '';

  if (crossOrigin == 'anonymous') {
    // Ya se activó para este origen. Si la sonda había rechazado esta URL (por
    // ejemplo tras cambiar de episodio), se quita para que el medio cargue.
    if (state == 'rejected') _reload(video, src, crossOrigin: false);
    return;
  }
  if (state != null) return; // 'pending' u 'ok': ya hay algo en curso.

  cache.setProperty(src.toJS, 'pending'.toJS);

  final JSObject init = JSObject();
  init.setProperty('method'.toJS, 'GET'.toJS);
  init.setProperty('mode'.toJS, 'cors'.toJS);
  init.setProperty('credentials'.toJS, 'omit'.toJS);
  init.setProperty('cache'.toJS, 'no-store'.toJS);

  _jsFetch(src.toJS, init).toDart.then(
    (JSObject response) {
      final int status =
          response.getProperty<JSNumber?>('status'.toJS)?.toDartInt ?? 0;
      final String type =
          response.getProperty<JSString?>('type'.toJS)?.toDart ?? '';

      // Solo interesaban las cabeceras: se corta la descarga del vídeo entero.
      final JSObject? body = response.getProperty<JSObject?>('body'.toJS);
      if (body != null) {
        try {
          body.callMethod<JSAny?>('cancel'.toJS);
        } catch (_) {}
      }

      if ((status == 200 || status == 206) && type == 'cors') {
        cache.setProperty(src.toJS, 'ok'.toJS);
        _reload(video, src, crossOrigin: true);
      } else {
        cache.setProperty(src.toJS, 'rejected'.toJS);
        // El elemento ya venía con `crossOrigin` de una URL anterior: con esta
        // el servidor no permite CORS, así que se quita para que cargue.
        final String applied =
            video.getProperty<JSString?>('crossOrigin'.toJS)?.toDart ?? '';
        if (applied == 'anonymous') {
          _reload(video, src, crossOrigin: false);
        }
      }
    },
    onError: (Object _) {
      cache.setProperty(src.toJS, 'rejected'.toJS);
    },
  );
}

/// Reabre el mismo `src` conservando la posición y el estado de reproducción.
///
/// `crossOrigin` se fija antes de asignar `src` (es lo único que decide si el
/// fetch del medio usa CORS). Un `error` revierte a la carga normal para no
/// dejar el reproductor roto.
void _reload(
  JSObject video,
  String src, {
  required bool crossOrigin,
  bool? playing,
}) {
  final bool wasPlaying = playing ??
      !(video.getProperty<JSBoolean?>('paused'.toJS)?.toDart ?? true);
  final double at =
      video.getProperty<JSNumber?>('currentTime'.toJS)?.toDartDouble ?? 0;

  late final JSFunction restoreTime;
  restoreTime = ((JSAny? event) {
    video.callMethod<JSAny?>(
      'removeEventListener'.toJS,
      'loadedmetadata'.toJS,
      restoreTime,
    );
    try {
      video.setProperty('currentTime'.toJS, at.toJS);
    } catch (_) {}
  }).toJS;

  late final JSFunction resume;
  resume = ((JSAny? event) {
    video.callMethod<JSAny?>('removeEventListener'.toJS, 'canplay'.toJS, resume);
    if (!wasPlaying) return;
    final JSAny? played = video.callMethod<JSAny?>('play'.toJS);
    if (played is JSPromise) {
      played.toDart.then((_) {}, onError: (Object _) {});
    }
  }).toJS;

  late final JSFunction onError;
  onError = ((JSAny? event) {
    video.callMethod<JSAny?>('removeEventListener'.toJS, 'error'.toJS, onError);
    // Con CORS el medio no cargó (token caducado, cabecera, ...): se vuelve al
    // modo normal y se marca la URL para no reintentarlo.
    if (crossOrigin) {
      _corsCache().setProperty(src.toJS, 'rejected'.toJS);
      _reload(video, src, crossOrigin: false, playing: wasPlaying);
    }
  }).toJS;

  video.callMethod<JSAny?>('addEventListener'.toJS, 'loadedmetadata'.toJS, restoreTime);
  video.callMethod<JSAny?>('addEventListener'.toJS, 'error'.toJS, onError);
  if (wasPlaying) {
    video.callMethod<JSAny?>('addEventListener'.toJS, 'canplay'.toJS, resume);
  }

  if (crossOrigin) {
    video.setProperty('crossOrigin'.toJS, 'anonymous'.toJS);
  } else {
    video.callMethod<JSAny?>('removeAttribute'.toJS, 'crossorigin'.toJS);
  }
  video.setProperty('src'.toJS, src.toJS);
  video.callMethod<JSAny?>('load'.toJS);
}
