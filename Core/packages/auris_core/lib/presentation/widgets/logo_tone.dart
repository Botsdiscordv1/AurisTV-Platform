import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

enum LogoTone { bright, dark }

class LogoToneService {
  LogoToneService._();

  static final Map<String, LogoTone> _resolved = {};
  static final Map<String, Future<LogoTone?>> _pending = {};

  static LogoTone? cached(String url) => _resolved[url];

  static Future<LogoTone?> resolve(String url) {
    final done = _resolved[url];
    if (done != null) return Future<LogoTone?>.value(done);
    final running = _pending[url];
    if (running != null) return running;
    final future = _load(url);
    _pending[url] = future;
    future.then((tone) {
      _pending.remove(url);
      if (tone != null) _resolved[url] = tone;
    });
    return future;
  }

  static Future<LogoTone?> _load(String url) async {
    try {
      for (var attempt = 0; attempt < 5; attempt++) {
        if (attempt > 0) await Future<void>.delayed(const Duration(milliseconds: 400));
        final info = await DefaultCacheManager().getFileFromCache(url);
        if (info == null) continue;
        final bytes = await info.file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: 64);
        final frame = await codec.getNextFrame();
        final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (data == null) return null;
        final pixels = data.buffer.asUint8List();
        var weight = 0.0;
        var total = 0.0;
        var count = 0;
        var opaque = 0;
        for (var i = 0; i + 3 < pixels.length; i += 4) {
          count++;
          final alpha = pixels[i + 3];
          if (alpha > 200) opaque++;
          if (alpha < 32) continue;
          final luminance = 0.299 * pixels[i] + 0.587 * pixels[i + 1] + 0.114 * pixels[i + 2];
          total += luminance * alpha;
          weight += alpha;
        }
        if (weight == 0 || count == 0) return null;
        if (opaque / count >= 0.85) return LogoTone.bright;
        return total / weight >= 128 ? LogoTone.bright : LogoTone.dark;
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

class LogoToneFilter extends StatefulWidget {
  const LogoToneFilter({super.key, required this.imageUrl, required this.child});

  final String imageUrl;
  final Widget child;

  @override
  State<LogoToneFilter> createState() => _LogoToneFilterState();
}

class _LogoToneFilterState extends State<LogoToneFilter> {
  LogoTone? _tone;

  @override
  void initState() {
    super.initState();
    _tone = LogoToneService.cached(widget.imageUrl);
    _fetch();
  }

  @override
  void didUpdateWidget(covariant LogoToneFilter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl == widget.imageUrl) return;
    _tone = LogoToneService.cached(widget.imageUrl);
    _fetch();
  }

  void _fetch() {
    final url = widget.imageUrl;
    if (url.isEmpty || _tone != null) return;
    LogoToneService.resolve(url).then((tone) {
      if (!mounted || tone == null || url != widget.imageUrl) return;
      setState(() => _tone = tone);
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget top = _tone == LogoTone.dark
        ? ColorFiltered(
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            child: widget.child,
          )
        : widget.child;
    return LayoutBuilder(builder: (context, constraints) {
      final sigma = _haloSigmaFor(constraints);
      return Stack(
        fit: StackFit.passthrough,
        children: [
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
              child: widget.child,
            ),
          ),
          top,
        ],
      );
    });
  }

  static double _haloSigmaFor(BoxConstraints constraints) {
    double? shortest;
    if (constraints.maxWidth.isFinite) shortest = constraints.maxWidth;
    if (constraints.maxHeight.isFinite &&
        (shortest == null || constraints.maxHeight < shortest)) {
      shortest = constraints.maxHeight;
    }
    if (shortest == null) return 4;
    final scaled = shortest * 0.07;
    if (scaled < 2) return 2;
    return scaled > 10 ? 10 : scaled;
  }
}
