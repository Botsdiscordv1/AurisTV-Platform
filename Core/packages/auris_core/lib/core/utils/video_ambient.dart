import 'dart:typed_data';

import 'video_ambient_stub.dart'
    if (dart.library.js_interop) 'video_ambient_web.dart' as impl;

/// Genera la imagen del modo ambiente a partir del frame que está mostrando
/// media_kit, con el mismo método que usa YouTube: el video se copia a un
/// buffer diminuto con blur y se le hornea una máscara radial de alfa.
///
/// Devuelve los bytes PNG, o `null` si no se puede (plataforma no web, sin
/// frames todavía, canvas contaminado por CORS...).
Uint8List? sampleVideoAmbientFrame() => impl.sampleVideoAmbientFrameImpl();
