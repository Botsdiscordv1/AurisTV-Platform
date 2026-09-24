import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/api/api_endpoints.dart';

/// Imagen con cura reactiva 2→1 para OnlyPelis.
///
/// Flujo: si la carga falla y la URL (desenrollada de proxy/weserv) es de
/// onlypelis, pide UNA vez la URL curada a
/// `GET /api/images/onlypelis-cure` (server movies) y reintenta por el proxy
/// del VPS directo. Sin cura disponible → [errorWidget]/placeholder.
/// Las URLs ya intentadas se registran a nivel proceso para no repetir
/// llamadas en la sesión.
class CuredNetworkImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit? fit;
  final FilterQuality filterQuality;
  final int? memCacheWidth;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final String? source;
  final String? category;

  const CuredNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit,
    this.filterQuality = FilterQuality.medium,
    this.memCacheWidth,
    this.placeholder,
    this.errorWidget,
    this.source,
    this.category,
  });

  static final Set<String> _cureAttempted = {};

  @override
  State<CuredNetworkImage> createState() => _CuredNetworkImageState();
}

class _CuredNetworkImageState extends State<CuredNetworkImage> {
  late String _url;
  bool _curing = false;
  bool _cureScheduled = false;

  @override
  void initState() {
    super.initState();
    _url = widget.imageUrl;
  }

  @override
  void didUpdateWidget(covariant CuredNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _url = widget.imageUrl;
      _curing = false;
      _cureScheduled = false;
    }
  }

  /// Extrae la URL original de un proxy/weserv anidado (?url=...).
  static String _unwrap(String url) {
    try {
      final nested = Uri.parse(url).queryParameters['url'];
      if (nested != null && nested.isNotEmpty) return nested;
    } catch (_) {}
    return url;
  }

  static bool _isOnlyPelis(String url) {
    final lower = url.toLowerCase();
    return lower.contains('onlypelis.com') || lower.contains('onlypelis.net');
  }

  void _scheduleCure(String failedUrl) {
    if (_cureScheduled) return;
    final raw = _unwrap(failedUrl);
    if (!_isOnlyPelis(raw)) return;
    if (!CuredNetworkImage._cureAttempted.add(raw)) return;
    _cureScheduled = true;
    Future.microtask(() => _doCure(failedUrl));
  }

  Future<void> _doCure(String failedUrl) async {
    if (!mounted) return;
    setState(() => _curing = true);
    try {
      // El endpoint de cura vive en movies (onlypelis → movies siempre).
      final base = ApiEndpoints.baseUrlForSource(widget.source ?? 'OnlyPelis', widget.category);
      final resp = await Dio().get(
        '$base/api/images/onlypelis-cure',
        queryParameters: {'url': failedUrl},
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final body = resp.data;
      final data = body is Map && body['data'] is Map ? body['data'] : body;
      final cured = data is Map ? data['url']?.toString() : null;
      if (!mounted) return;
      if (cured != null && cured.isNotEmpty) {
        setState(() {
          _curing = false;
          // Por el proxy del VPS directo (evita rebotar en weserv).
          _url = '$base/api/proxy/image?url=${Uri.encodeComponent(cured)}';
        });
      } else {
        setState(() => _curing = false);
      }
    } catch (_) {
      if (mounted) setState(() => _curing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      key: ValueKey(_url),
      imageUrl: _url,
      fit: widget.fit,
      filterQuality: widget.filterQuality,
      memCacheWidth: widget.memCacheWidth,
      placeholder: widget.placeholder,
      errorWidget: (context, url, error) {
        _scheduleCure(url);
        if (_curing && widget.placeholder != null) {
          return widget.placeholder!(context, url);
        }
        if (widget.errorWidget != null) return widget.errorWidget!(context, url, error);
        return const SizedBox.shrink();
      },
    );
  }
}
