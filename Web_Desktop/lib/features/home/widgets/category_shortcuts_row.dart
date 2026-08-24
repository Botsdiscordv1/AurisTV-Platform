import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/utils/responsive_utils.dart';

class CategoryShortcutsRow extends StatelessWidget {
  final ValueChanged<String> onCategoryTap;
  final String currentCategory;

  const CategoryShortcutsRow({
    super.key,
    required this.onCategoryTap,
    required this.currentCategory,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final horizontalPadding = ResponsiveUtils.horizontalPadding(context);

    final shortcuts = [
      {'id': 'animes', 'label': 'Animes', 'icon': Icons.auto_awesome, 'color': const Color(0xFFEF7A1E)},
      {'id': 'películas', 'label': 'Cine', 'icon': Icons.movie_filter_rounded, 'color': const Color(0xFF2196F3)},
      {'id': 'series', 'label': 'Series', 'icon': Icons.tv_rounded, 'color': const Color(0xFF4CAF50)},
      {'id': 'kdrama', 'label': 'KDramas', 'icon': Icons.favorite_rounded, 'color': const Color(0xFFE91E63)},
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 24 : 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Text(
              'Explorar por Categoría',
              style: GoogleFonts.poppins(
                fontSize: isMobile ? 18 : 24,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: isMobile ? 100 : 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              itemCount: shortcuts.length,
              separatorBuilder: (_, __) => SizedBox(width: isMobile ? 12 : 20),
              itemBuilder: (context, index) {
                final item = shortcuts[index];
                return _ShortcutCard(
                  label: item['label'] as String,
                  icon: item['icon'] as IconData,
                  color: item['color'] as Color,
                  onTap: () => onCategoryTap(item['id'] as String),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ShortcutCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ShortcutCard> createState() => _ShortcutCardState();
}

class _ShortcutCardState extends State<_ShortcutCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  bool get isSelected => _isHovered || _isFocused;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveUtils.isMobile(context);
    final size = isMobile ? 85.0 : 110.0;

    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: isSelected ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Column(
              children: [
                Container(
                  width: size,
                  height: size * 0.75,
                  decoration: BoxDecoration(
                    color: isSelected ? widget.color : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.white10,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.4),
                        blurRadius: 15,
                        spreadRadius: 2,
                      )
                    ] : [],
                  ),
                  child: Center(
                    child: Icon(
                      widget.icon,
                      color: isSelected ? Colors.white : widget.color.withValues(alpha: 0.8),
                      size: isMobile ? 32 : 44,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.label,
                  style: GoogleFonts.poppins(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: isMobile ? 12 : 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
