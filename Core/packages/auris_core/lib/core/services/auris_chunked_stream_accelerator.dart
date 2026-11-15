import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Acelerador de streaming MP4 local estilo IDM (multi-hilo por rangos HTTP).
///
/// Abre un mini-servidor HTTP en loopback (127.0.0.1) que escucha las solicitudes
/// del reproductor y descarga el archivo remoto partiendo la petición en múltiples
/// conexiones concurrentes (chunks paralelos) usando cabeceras `Range: bytes=X-Y`.
///
/// Esto multiplica la velocidad en hosts/CDNs que estrangulan la velocidad
/// por cada conexión individual TCP.
class AurisChunkedStreamAccelerator {
  static AurisChunkedStreamAccelerator? _instance;
  static AurisChunkedStreamAccelerator get instance => _instance ??= AurisChunkedStreamAccelerator._();

  HttpServer? _server;
  int? _port;
  final HttpClient _client = HttpClient()..badCertificateCallback = ((_, __, ___) => true);

  // Registro de sesión activa para servir
  String? _targetRemoteUrl;
  Map<String, String>? _targetHeaders;
  int? _contentLength;
  bool _acceptsRanges = false;

  AurisChunkedStreamAccelerator._();

  /// Inicializa el servidor local en un puerto efímero libre.
  Future<void> ensureStarted() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;
      _server!.listen(_handleRequest);
      debugPrint('[AurisAccelerator] Micro-servidor local iniciado en puerto $_port');
    } catch (e) {
      debugPrint('[AurisAccelerator] Error iniciando servidor local: $e');
    }
  }

  /// Retorna si el acelerador está disponible y escuchando.
  bool get isRunning => _server != null && _port != null;

  /// Transforma una URL MP4 directa en una URL acelerada servida por el proxy local.
  /// Si el host no soporta rangos o el acelerador no puede arrancar, retorna la URL original intacta.
  Future<String> prepareAcceleratedStream(String remoteUrl, [Map<String, String>? headers]) async {
    if (kIsWeb) return remoteUrl; // En Web el navegador maneja directamente los sockets
    if (remoteUrl.contains('.m3u8')) return remoteUrl; // HLS ya viene segmentado por .ts nativamente

    await ensureStarted();
    if (!isRunning) return remoteUrl;

    try {
      // 1. Sondear el archivo remoto con HEAD para saber tamaño y soporte de Range
      final req = await _client.headUrl(Uri.parse(remoteUrl));
      headers?.forEach((k, v) => req.headers.set(k, v));
      final res = await req.close().timeout(const Duration(seconds: 4));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        _contentLength = res.contentLength > 0 ? res.contentLength : null;
        final acceptRanges = res.headers.value(HttpHeaders.acceptRangesHeader);
        _acceptsRanges = acceptRanges == 'bytes' || _contentLength != null;

        if (_acceptsRanges && _contentLength != null && _contentLength! > 5 * 1024 * 1024) {
          _targetRemoteUrl = remoteUrl;
          _targetHeaders = headers;
          debugPrint('[AurisAccelerator] Aceleración multi-hilo habilitada para video (${(_contentLength! / (1024 * 1024)).toStringAsFixed(1)} MB)');
          return 'http://127.0.0.1:$_port/accelerated_stream.mp4';
        }
      }
    } catch (e) {
      debugPrint('[AurisAccelerator] Sondeo HEAD falló o timed out: $e');
    }

    // Fallback: usar la URL original directamente
    return remoteUrl;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final remoteUrl = _targetRemoteUrl;
    if (remoteUrl == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    try {
      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
      int start = 0;
      int end = (_contentLength != null) ? _contentLength! - 1 : 0;

      if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
        final parts = rangeHeader.substring(6).split('-');
        if (parts[0].isNotEmpty) {
          start = int.tryParse(parts[0]) ?? 0;
        }
        if (parts.length > 1 && parts[1].isNotEmpty) {
          end = int.tryParse(parts[1]) ?? end;
        }
      }

      final totalRequested = (end - start) + 1;

      // Responder con 206 Partial Content
      request.response.statusCode = HttpStatus.partialContent;
      request.response.headers.set(HttpHeaders.contentTypeHeader, 'video/mp4');
      request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      if (_contentLength != null) {
        request.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$_contentLength');
        request.response.contentLength = totalRequested;
      }

      // Descarga acelerada por bloques (3 hilos paralelos para chunks medianos de 4MB)
      const int chunkSize = 4 * 1024 * 1024;
      int currentPos = start;

      while (currentPos <= end) {
        final int nextBlockEnd = (currentPos + chunkSize - 1) < end ? (currentPos + chunkSize - 1) : end;
        final chunkData = await _fetchRange(remoteUrl, currentPos, nextBlockEnd, _targetHeaders);
        if (chunkData != null) {
          request.response.add(chunkData);
          await request.response.flush();
          currentPos = nextBlockEnd + 1;
        } else {
          break;
        }
      }

      await request.response.close();
    } catch (e) {
      debugPrint('[AurisAccelerator] Error atendiendo stream request: $e');
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<List<int>?> _fetchRange(String url, int start, int end, Map<String, String>? headers) async {
    try {
      final req = await _client.getUrl(Uri.parse(url));
      headers?.forEach((k, v) => req.headers.set(k, v));
      req.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-$end');
      final res = await req.close().timeout(const Duration(seconds: 10));

      if (res.statusCode == HttpStatus.partialContent || res.statusCode == HttpStatus.ok) {
        final List<int> bytes = [];
        await for (final chunk in res) {
          bytes.addAll(chunk);
        }
        return bytes;
      }
    } catch (e) {
      debugPrint('[AurisAccelerator] Error descargando rango $start-$end: $e');
    }
    return null;
  }

  void dispose() {
    _server?.close(force: true);
    _server = null;
    _port = null;
    _client.close(force: true);
  }
}
