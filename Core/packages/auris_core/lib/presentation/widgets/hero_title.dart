import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/api/api_endpoints.dart';

class HeroTitle extends StatefulWidget {
  final String title;
  final String? logo;
  final bool logoReady;
  final double maxWidth;
  final double maxHeight;
  final TextStyle style;
  final int timeoutSeconds;

  const HeroTitle({
    super.key,
    required this.title,
    required this.logo,
    required this.logoReady,
    required this.maxWidth,
    required this.maxHeight,
    required this.style,
    this.timeoutSeconds = 3,
  });

  @override
  State<HeroTitle> createState() => _HeroTitleState();
}

class _HeroTitleState extends State<HeroTitle> {
  late final DateTime _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    // Logo siempre gana si existe (llegó del detalle).
    if (widget.logo != null && widget.logo!.isNotEmpty) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: widget.maxWidth,
          maxHeight: widget.maxHeight,
        ),
        child: CachedNetworkImage(
          imageUrl: ApiEndpoints.proxyImage(widget.logo),
          fit: BoxFit.contain,
          alignment: Alignment.bottomLeft,
          fadeInDuration: const Duration(milliseconds: 300),
          placeholder: (_, __) => const SizedBox.shrink(),
          errorWidget: (_, __, ___) => Text(
            widget.title.toUpperCase(),
            style: widget.style,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    // Timeout sin logo -> fallback a título.
    final int elapsed = DateTime.now().difference(_startTime).inSeconds;
    if (elapsed >= widget.timeoutSeconds) {
      return Text(
        widget.title.toUpperCase(),
        style: widget.style,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Sin logo y timeout no vencido -> nada (esperando logo).
    return SizedBox(width: widget.maxWidth, height: widget.maxHeight / 2);
  }
}