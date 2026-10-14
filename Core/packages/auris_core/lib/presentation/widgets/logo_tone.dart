import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class LogoToneFilter extends StatelessWidget {
  const LogoToneFilter({super.key, required this.imageUrl, required this.child});

  final String imageUrl;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final sigma = _haloSigmaFor(constraints);
      return Stack(
        fit: StackFit.passthrough,
        children: [
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
              child: child,
            ),
          ),
          child,
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
