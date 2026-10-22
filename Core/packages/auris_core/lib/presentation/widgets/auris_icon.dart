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
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: SvgPicture.string(
          svgContent,
          width: size,
          height: size,
          fit: BoxFit.contain,
          colorFilter: color != null
              ? ColorFilter.mode(color!, BlendMode.srcIn)
              : null,
        ),
      ),
    );
  }
}
