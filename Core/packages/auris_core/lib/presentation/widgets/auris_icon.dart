import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AurisIcon extends StatelessWidget {
  final String svgContent;
  final double size;
  final Color? color;

  const AurisIcon(
    this.svgContent, {
    super.key,
    this.size = 24.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      svgContent,
      width: size,
      height: size,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : null,
    );
  }
}
