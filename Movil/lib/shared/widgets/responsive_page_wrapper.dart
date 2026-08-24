import 'package:flutter/material.dart';
import '../../core/utils/responsive_utils.dart';

/// Un contenedor de seguridad senior que evita que el contenido se estire
/// infinitamente en monitores ultra-anchos.
/// Mantiene el catálogo centrado y legible, emulando la UX de Netflix/Prime Video.
class ResponsivePageWrapper extends StatelessWidget {
  final Widget child;
  final bool isImmersive;
  final Color? backgroundColor;

  const ResponsivePageWrapper({
    super.key,
    required this.child,
    this.isImmersive = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    // Si la página es inmersiva (como el Player) o estamos en móvil, no aplicamos límites.
    if (isImmersive || ResponsiveUtils.isMobile(context)) {
      return child;
    }

    return Container(
      color: backgroundColor ?? const Color(0xFF0B0B0D),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: ResponsiveUtils.maxContentWidth, // Senior: 3840px para Sangrado Total
          ),
          child: child,
        ),
      ),
    );
  }
}
