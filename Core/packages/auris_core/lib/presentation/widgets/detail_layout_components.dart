import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auris_core.dart';

/// Helper para construir etiquetas (Action, Sci-Fi, etc.)
Widget buildDetailBadge(BuildContext context, String? text, {bool small = false}) {
  if (text == null || text.isEmpty) return const SizedBox.shrink();
  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: ResponsiveUtils.sp(context, small ? 6 : 10), 
      vertical: ResponsiveUtils.sp(context, small ? 1.5 : 3)
    ),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.3),
      border: Border.all(
        color: Colors.white.withOpacity(0.5), 
        width: 1.0
      ),
      borderRadius: BorderRadius.circular(ResponsiveUtils.sp(context, small ? 3 : 4)),
    ),
    child: Text(
      text.toUpperCase(),
      style: GoogleFonts.poppins(
        color: Colors.white, 
        fontSize: ResponsiveUtils.sp(context, small ? 10 : 13), 
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    ),
  );
}

/// Helper para etiquetas de edad/certificación (16+, TV-MA, etc.)
Widget buildAgeBadge(BuildContext context, String? text, {bool small = false}) {
  if (text == null || text.isEmpty) return const SizedBox.shrink();
  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: ResponsiveUtils.sp(context, small ? 5 : 8), 
      vertical: ResponsiveUtils.sp(context, small ? 1.5 : 3)
    ),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.1),
      border: Border.all(
        color: Colors.white10, 
        width: 1.0
      ),
      borderRadius: BorderRadius.circular(ResponsiveUtils.sp(context, small ? 3 : 4)),
    ),
    child: Text(
      text,
      style: GoogleFonts.poppins(
        color: Colors.white, 
        fontSize: ResponsiveUtils.sp(context, small ? 10 : 13), 
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// Skeleton para la puntuación (Estrellas)
class DetailRatingSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final bool mobile;
  const DetailRatingSkeleton({super.key, required this.width, required this.height, this.mobile = false});
  
  @override
  Widget build(BuildContext context) {
    final base = mobile ? 18.0 : 24.0;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.35, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: mobile ? value : value * 0.85,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(base / 2),
            ),
          ),
        );
      },
    );
  }
}

/// Caja genérica de esqueleto para carga
class DetailSkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  const DetailSkeletonBox({super.key, required this.width, required this.height, this.borderRadius = 4});
  
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.35, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
        );
      },
    );
  }
}

/// Botón circular o de cápsula para acciones (Lista, Me gusta, Compartir)
class DetailActionButton extends StatefulWidget {
  final IconData icon; 
  final VoidCallback onPressed; 
  final String label; 
  final bool isMobile; 
  final double? size; 
  final double? iconSize; 
  final Color? color;
  final bool isLoading;

  const DetailActionButton({
    super.key,
    required this.icon, 
    required this.onPressed, 
    required this.label, 
    this.isMobile = false, 
    this.size, 
    this.iconSize, 
    this.color, 
    this.isLoading = false
  });

  @override
  State<DetailActionButton> createState() => _DetailActionButtonState();
}

class _DetailActionButtonState extends State<DetailActionButton> {
  final ValueNotifier<bool> _isHovered = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _isHovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isMobile) {
      return InkWell(
        onTap: widget.isLoading ? null : widget.onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            border: Border.all(color: widget.color ?? Colors.white24, width: 0.8), 
            borderRadius: BorderRadius.circular(8)
          ), 
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isLoading)
                SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: widget.color ?? Colors.white),
                )
              else
                Icon(widget.icon, color: widget.color ?? Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                widget.isLoading ? 'Cargando...' : widget.label,
                style: GoogleFonts.poppins(
                  color: Colors.white, 
                  fontSize: 13, 
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return MouseRegion(
      onEnter: (_) { _isHovered.value = true; },
      onExit: (_) { _isHovered.value = false; },
      child: ValueListenableBuilder<bool>(
        valueListenable: _isHovered,
        builder: (context, hovered, _) {
          return Tooltip(
            message: widget.label, 
            child: AnimatedScale(
              scale: hovered ? 1.1 : 1.0, 
              duration: const Duration(milliseconds: 200), 
              child: Container(
                height: widget.size ?? 56, 
                width: widget.size ?? 56, 
                decoration: BoxDecoration(
                  color: Colors.white10, 
                  shape: BoxShape.circle, 
                  border: Border.all(color: widget.color ?? Colors.white24)
                ), 
                child: widget.isLoading
                  ? Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: widget.color ?? Colors.white)))
                  : IconButton(
                      icon: Icon(widget.icon, color: widget.color ?? Colors.white, size: widget.iconSize ?? 28),
                      onPressed: widget.onPressed
                    )
              )
            ),
          );
        },
      ),
    );
  }
}
