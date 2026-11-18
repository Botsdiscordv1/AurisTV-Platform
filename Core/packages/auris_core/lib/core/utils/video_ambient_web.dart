import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

@JS('document')
external JSObject get _document;

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
    final video = _document.callMethod<JSObject?>(
      'querySelector'.toJS,
      'video'.toJS,
    );
    if (video == null) return null;

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
