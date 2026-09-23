import 'package:flutter/material.dart';

/// A shared content tab bar widget for all platforms (Mobile, TV, Web/Desktop).
///
/// Supports responsive sizing, horizontal scrolling, and active tab indicator styling.
class ContentTabBar extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final void Function(int index) onTabSelected;
  final double hPadding;
  final bool isMobile;
  final bool isCompact;

  const ContentTabBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onTabSelected,
    this.hPadding = 0.0,
    this.isMobile = false,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final double screenW = MediaQuery.sizeOf(context).width;
    final double fontSize = isMobile 
        ? 16.0 
        : (isCompact ? 15.5 : (screenW * 0.011).clamp(16.0, 19.0));
    final double itemHPadding = isMobile ? 16.0 : (isCompact ? 14.0 : 22.0);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: hPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(labels.length, (i) {
          final selected = i == selectedIndex;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTabSelected(i),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: itemHPadding, vertical: isCompact ? 6 : 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: selected ? const Color(0xFFEF7A1E) : Colors.transparent,
                    width: isCompact ? 2.5 : 3,
                  ),
                ),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : const Color(0xFFA5A5AA),
                  letterSpacing: -0.2,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
