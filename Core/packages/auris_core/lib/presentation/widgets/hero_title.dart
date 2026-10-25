import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/api/api_endpoints.dart';
import 'logo_tone.dart';

class HeroTitle extends StatefulWidget {
  final String title;
  final String? logo;
  final bool logoReady;
  final double maxWidth;
  final double maxHeight;
  final TextStyle style;
  final int timeoutSeconds;
  final bool centerAlignment;

  const HeroTitle({
    super.key,
    required this.title,
    required this.logo,
    required this.logoReady,
    required this.maxWidth,
    required this.maxHeight,
    required this.style,
    this.timeoutSeconds = 3,
    this.centerAlignment = false,
  });

  @override
  State<HeroTitle> createState() => _HeroTitleState();
}

class _HeroTitleState extends State<HeroTitle> {
  Timer? _fallbackTimer;
  bool _showTextFallback = false;

  @override
  void initState() {
    super.initState();
    _startFallbackTimer();
  }

  @override
  void didUpdateWidget(HeroTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si llega el logo o el título cambia, reseteamos el timer de seguridad
    if (widget.logo != oldWidget.logo || widget.title != oldWidget.title || widget.logoReady != oldWidget.logoReady) {
      _fallbackTimer?.cancel();
      _showTextFallback = false;
      _startFallbackTimer();
    }
  }

  void _startFallbackTimer() {
    if (widget.logo != null && widget.logo!.isNotEmpty) return;

    if (widget.logoReady) {
      setState(() => _showTextFallback = true);
      return;
    }

    _fallbackTimer = Timer(Duration(seconds: widget.timeoutSeconds), () {
      if (mounted && (widget.logo == null || widget.logo!.isEmpty)) {
        setState(() => _showTextFallback = true);
      }
    });
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: widget.centerAlignment ? AlignmentDirectional.topCenter : AlignmentDirectional.topStart,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: _buildIdentity(),
    );
  }

  Widget _buildIdentity() {
    // 1. Prioridad Máxima: Logo Gráfico (Si existe, lo mostramos ya)
    if (widget.logo != null && widget.logo!.isNotEmpty) {
      final imageUrl = ApiEndpoints.proxyImage(widget.logo, highQuality: true);
      return SizedBox(
        key: const ValueKey('identity_logo'),
        width: widget.maxWidth,
        height: widget.maxHeight,
        child: Align(
          alignment: widget.centerAlignment ? Alignment.bottomCenter : Alignment.bottomLeft,
          child: LogoToneFilter(
            imageUrl: imageUrl,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              alignment: widget.centerAlignment ? Alignment.bottomCenter : Alignment.bottomLeft,
              fadeInDuration: const Duration(milliseconds: 300),
              fadeOutDuration: Duration.zero,
              placeholder: (_, __) => const SizedBox.shrink(),
              errorWidget: (_, __, ___) => _buildTextFallback(forced: true),
            ),
          ),
        ),
      );
    }

    // 2. Si no hay logo, comprobamos si el tiempo de espera (30s) ha vencido
    if (_showTextFallback) {
      return _buildTextFallback();
    }

    // 3. Mientras esperamos al logo (Estado B solicitado), mantenemos el espacio reservado pero oculto
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return SizedBox(
      key: const ValueKey('identity_placeholder'),
      width: widget.maxWidth,
      height: widget.maxHeight,
    );
  }

  Widget _buildTextFallback({bool forced = false}) {
    return SizedBox(
      key: const ValueKey('identity_text'),
      width: widget.maxWidth,
      height: widget.maxHeight,
      child: Align(
        alignment: widget.centerAlignment ? Alignment.bottomCenter : Alignment.bottomLeft,
        child: Text(
          widget.title.toUpperCase(),
          style: widget.style,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: widget.centerAlignment ? TextAlign.center : TextAlign.left,
        ),
      ),
    );
  }
}
