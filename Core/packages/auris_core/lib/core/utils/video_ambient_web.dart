import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

@JS('document')
external JSObject get _document;

/// Valores medidos en el reproductor de YouTube (canvas `#cinematics`):
/// buffer de 110×75 px, `ctx.filter = blur(5px)` al copiar el frame y el
/// contenedor escalado 1.5 en X y 2 en Y.
const int _kBufferWidth = 110;
const int _kBufferHeight = 75;
const double _kBlur = 5;


/// Copia el frame actual del `<video>` a un buffer diminuto y lo difumina con el
/// filtro del canvas, igual que YouTube: sin máscara, el PNG es el frame nítido
/// de color pero sin detalle.
///
/// El buffer de 110×75 es lo que da el degradado al estirarlo sobre el halo.
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

    // El blur oscurece los bordes (muestrea fuera del frame), así que se dibuja
    // con un margen extra y luego se recorta.
    ctx.setProperty('filter'.toJS, 'blur($_kBlur' 'px)'.toJS);
    ctx.callMethodVarArgs<JSAny?>(
      'drawImage'.toJS,
      <JSAny>[
        video,
        (-_kBlur).toJS,
        (-_kBlur).toJS,
        (_kBufferWidth + _kBlur * 2).toJS,
        (_kBufferHeight + _kBlur * 2).toJS,
      ],
    );
    ctx.setProperty('filter'.toJS, 'none'.toJS);

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
