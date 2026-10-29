import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Stream HLS ya resuelto, listo para abrir en media_kit con sus headers.
class LacanchaResolvedStream {
  final String m3u8;
  final String referer;
  const LacanchaResolvedStream({required this.m3u8, required this.referer});
}

/// Hook de JS inyectado al inicio de la carga del embed (onPageStarted).
///
/// Envuelve `fetch`, `XMLHttpRequest.open` y el setter de `src` de los
/// elementos de media para reportar cualquier manifiesto HLS (`.m3u8`) que pida
/// el player (hls.js) de vuelta a Flutter por el canal `AurisStream` y dejarlo
/// guardado en `window.__aurisStreams` como respaldo. Validado contra el embed
/// real de lacancha con Chrome headless + CDP.
const String _kHookSource = r'''
(function(){
  if (window.__aurisHook) return; window.__aurisHook = true;
  window.__aurisStreams = [];
  function report(u){
    try{
      if (typeof u === 'string' && /\.m3u8|\.m3u\b|format=m3u8|index\.m3u/i.test(u)){
        if (window.__aurisStreams.indexOf(u) === -1){
          window.__aurisStreams.push(u);
          if (window.AurisStream){ try{ window.AurisStream.postMessage(u); }catch(e){} }
        }
      }
    }catch(e){}
  }
  var of = window.fetch;
  window.fetch = function(input){ try{ report(typeof input === 'string' ? input : (input && input.url)); }catch(e){} return of.apply(this, arguments); };
  var ox = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function(m,u){ try{ report(u); }catch(e){} return ox.apply(this, arguments); };
  var d = Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,'src');
  if (d && d.set){ Object.defineProperty(HTMLMediaElement.prototype,'src',{ set:function(v){ try{ report(v); }catch(e){} return d.set.call(this,v); }, get:d.get }); }
})();
''';

const String _kBrowserUa =
    'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36';

/// Resuelve el `embed_url` de un stream lacancha a un m3u8 jugable por
/// media_kit.
///
/// Carga el embed en un WebView casi invisible, inyecta el hook al empezar la
/// navegación y captura el manifiesto HLS que pide hls.js. Devuelve `null` si
/// no se resuelve (timeout o embed caído), para que el llamador caiga al
/// reproductor embed.
Future<LacanchaResolvedStream?> resolveLacanchaStream(
  BuildContext context,
  String embedUrl,
) async {
  final referer = '${Uri.tryParse(embedUrl)?.origin ?? ''}/';
  if (!context.mounted) return null;
  return showDialog<LacanchaResolvedStream>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ResolverDialog(embedUrl: embedUrl, referer: referer),
  );
}

class _ResolverDialog extends StatefulWidget {
  final String embedUrl;
  final String referer;
  const _ResolverDialog({required this.embedUrl, required this.referer});

  @override
  State<_ResolverDialog> createState() => _ResolverDialogState();
}

class _ResolverDialogState extends State<_ResolverDialog> {
  late final WebViewController _controller;
  Timer? _poll;
  Timer? _timeout;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => _controller.runJavaScript(_kHookSource),
      ))
      ..addJavaScriptChannel('AurisStream', onMessageReceived: (msg) {
        _complete(msg.message);
      })
      ..loadRequest(Uri.parse(widget.embedUrl), headers: {
        'Referer': widget.referer,
        'User-Agent': _kBrowserUa,
      });

    // Respaldo: lee window.__aurisStreams por si el canal de JS perdió el
    // primer m3u8 por timing de la plataforma.
    _poll = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_done) return;
      _controller.runJavaScriptReturningResult(
              'window.__aurisStreams ? JSON.stringify(window.__aurisStreams) : "[]"')
          .then((raw) {
        final m3u8 = _extractFirstM3u8(raw.toString());
        if (m3u8 != null) _complete(m3u8);
      }).catchError((_) {});
    });
    _timeout = Timer(const Duration(seconds: 20), () => _finish(null));
  }

  String? _extractFirstM3u8(String jsonLike) {
    final m = RegExp(r'https?[^"\s\\]*\.m3u8[^"\s\\]*').firstMatch(jsonLike);
    return m?.group(0)?.replaceAll(r'\/', '/');
  }

  void _complete(String url) {
    if (_done) return;
    _finish(LacanchaResolvedStream(m3u8: url, referer: widget.referer));
  }

  void _finish(LacanchaResolvedStream? result) {
    if (_done) return;
    _done = true;
    _poll?.cancel();
    _timeout?.cancel();
    if (mounted) Navigator.of(context).pop(result);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // WebView a pantalla completa pero casi invisible (opacidad no
            // nula para que la vista nativa se pinte y ejecute su JS). De ahí
            // sale el m3u8 que luego reproduce media_kit.
            Positioned.fill(
              child: Opacity(
                opacity: 0.003,
                child: WebViewWidget(controller: _controller),
              ),
            ),
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFFEF7A1E)),
                  SizedBox(height: 16),
                  Text(
                    'Conectando con el servidor...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
