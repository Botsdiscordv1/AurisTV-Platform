import 'dart:convert';
import 'dart:io';
import 'dart:math';

class StreamProxyService {
  StreamProxyService._();
  static final StreamProxyService instance = StreamProxyService._();

  HttpServer? _server;
  final Map<String, _Session> _sessions = {};
  String? _ip;
  int? _port;

  bool get isRunning => _server != null;

  Future<String?> start() async {
    if (_server != null) return _baseUrl;
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      _port = _server!.port;
      _ip = await _resolveLocalIp();
      _server!.listen(_handleRequest, onError: (_) {});
      return _baseUrl;
    } catch (_) {
      _server = null;
      return null;
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _sessions.clear();
    _ip = null;
    _port = null;
  }

  String? get _baseUrl =>
      (_ip != null && _port != null) ? 'http://$_ip:$_port' : null;

  String register(String url, Map<String, String> headers) {
    final base = _baseUrl;
    if (base == null) return url;
    final token = _token();
    _sessions[token] = _Session(url, headers);
    return '$base/s/$token';
  }

  Future<void> _handleRequest(HttpRequest req) async {
    try {
      final segs = req.uri.pathSegments;
      if (segs.length < 2 || segs[0] != 's') {
        req.response.statusCode = 404;
        await req.response.close();
        return;
      }
      final token = segs[1];
      final session = _sessions[token];
      if (session == null) {
        req.response.statusCode = 404;
        await req.response.close();
        return;
      }

      final u = req.uri.queryParameters['u'];
      final targetUrl = (u != null && u.isNotEmpty)
          ? Uri.decodeComponent(u)
          : session.url;

      final client = HttpClient();
      client.autoUncompress = false;
      final uri = Uri.parse(targetUrl);
      final upReq = await client.getUrl(uri);
      session.headers.forEach((k, v) => upReq.headers.set(k, v));
      final range = req.headers.value('range');
      if (range != null) upReq.headers.set('range', range);
      if (!session.headers.keys
          .any((k) => k.toLowerCase() == 'user-agent')) {
        upReq.headers.set('user-agent', 'Mozilla/5.0');
      }
      upReq.headers.set('accept-encoding', 'identity');

      final upRes = await upReq.close();
      final ct = upRes.headers.contentType?.toString() ?? '';
      final isM3u8 = ct.contains('mpegurl') ||
          ct.contains('m3u8') ||
          targetUrl.toLowerCase().endsWith('.m3u8');

      if (isM3u8) {
        final body = await upRes.transform(utf8.decoder).join();
        final rewritten = _rewriteM3u8(body, targetUrl, token, _baseUrl!);
        req.response.statusCode = upRes.statusCode;
        req.response.headers.contentType =
            ContentType('application', 'vnd.apple.mpegurl', charset: 'utf-8');
        req.response.write(rewritten);
        await req.response.close();
        return;
      }

      req.response.statusCode = upRes.statusCode;
      upRes.headers.forEach((name, values) {
        final low = name.toLowerCase();
        if (low == 'transfer-encoding' || low == 'connection') return;
        for (final v in values) {
          req.response.headers.add(name, v);
        }
      });
      await upRes.pipe(req.response);
    } catch (_) {
      try {
        req.response.statusCode = 502;
        await req.response.close();
      } catch (_) {}
    }
  }

  String _rewriteM3u8(String body, String baseUrl, String token, String proxyBase) {
    final base = Uri.parse(baseUrl);
    final lines = body.split('\n');
    final out = <String>[];
    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) {
        out.add(line);
        continue;
      }
      if (t.startsWith('#')) {
        if (t.contains('URI="')) {
          out.add(t.replaceAllMapped(RegExp(r'URI="([^"]+)"'), (m) {
            final resolved = _resolveUrl(m.group(1)!, base);
            final enc = Uri.encodeComponent(resolved);
            return 'URI="$proxyBase/s/$token?u=$enc"';
          }));
        } else {
          out.add(line);
        }
        continue;
      }
      final resolved = _resolveUrl(t, base);
      final enc = Uri.encodeComponent(resolved);
      out.add('$proxyBase/s/$token?u=$enc');
    }
    return out.join('\n');
  }

  String _resolveUrl(String url, Uri base) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return base.resolve(url).toString();
  }

  String _token() {
    final r = Random.secure();
    final bytes = List<int>.generate(12, (_) => r.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  Future<String?> _resolveLocalIp() async {
    try {
      final ifaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      final preferred = <NetworkInterface>[];
      final others = <NetworkInterface>[];
      for (final iface in ifaces) {
        final name = iface.name.toLowerCase();
        if (name.contains('wlan') ||
            name.contains('wifi') ||
            name.contains('en0') ||
            name.contains('eth') ||
            name.contains('wlp')) {
          preferred.add(iface);
        } else {
          others.add(iface);
        }
      }
      for (final iface in [...preferred, ...others]) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}
    return null;
  }
}

class _Session {
  final String url;
  final Map<String, String> headers;
  _Session(this.url, this.headers);
}
