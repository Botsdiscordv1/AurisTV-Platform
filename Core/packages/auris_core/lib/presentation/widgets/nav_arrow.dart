import 'package:flutter/material.dart';

class NavArrow extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool useBackground;
  final bool enableScale;

  const NavArrow({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 30,
    this.useBackground = true,
    this.enableScale = true,
  });

  @override
  State<NavArrow> createState() => _NavArrowState();
}

class _NavArrowState extends State<NavArrow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Widget arrow = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.useBackground ? Colors.black.withOpacity(0.4) : Colors.transparent,
        boxShadow: (widget.useBackground && _isHovered) ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ] : [],
      ),
      child: Icon(
        widget.icon,
        color: Colors.white,
        size: widget.size,
      ),
    );

    if (widget.enableScale) {
      arrow = AnimatedScale(
        scale: _isHovered ? 1.2 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: arrow,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (hovered) { if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _isHovered = hovered); }); },
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        child: arrow,
      ),
    );
  }
}
