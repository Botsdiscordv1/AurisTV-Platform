import 'package:flutter/material.dart';

/// A shared content tab bar widget for all platforms (Mobile, TV, Web/Desktop).
///
/// Uses Flutter's native [TabBar] with [TickerProviderStateMixin] and safe post-frame
/// animation updates to guarantee butter-smooth animated indicator transitions
/// across Web, Mobile, and Desktop without any ticker conflicts.
class ContentTabBar extends StatefulWidget {
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
  State<ContentTabBar> createState() => _ContentTabBarState();
}

class _ContentTabBarState extends State<ContentTabBar> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.labels.length,
      vsync: this,
      initialIndex: widget.selectedIndex.clamp(0, widget.labels.length - 1),
      animationDuration: const Duration(milliseconds: 300), // Senior Fix: Animación fluida y configurable
    );
  }

  @override
  void didUpdateWidget(covariant ContentTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.labels.length != widget.labels.length) {
      _tabController.dispose();
      _tabController = TabController(
        length: widget.labels.length,
        vsync: this,
        initialIndex: widget.selectedIndex.clamp(0, widget.labels.length - 1),
        animationDuration: const Duration(milliseconds: 300),
      );
    } else if (widget.selectedIndex != _tabController.index && !_tabController.indexIsChanging) {
      // Senior Fix: Evitar conflicto/doble animación (race condition) si el usuario ya tocó el tab
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.selectedIndex != _tabController.index && !_tabController.indexIsChanging) {
          _tabController.animateTo(
            widget.selectedIndex.clamp(0, widget.labels.length - 1),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenW = MediaQuery.sizeOf(context).width;
    final double fontSize = widget.isMobile 
        ? 16.0 
        : (widget.isCompact ? 15.5 : (screenW * 0.011).clamp(16.0, 19.0));
    final double itemHPadding = widget.isMobile ? 16.0 : (widget.isCompact ? 14.0 : 22.0);
    final double indicatorHeight = widget.isCompact ? 2.5 : 3.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.hPadding),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        indicatorColor: const Color(0xFFEF7A1E),
        indicatorWeight: indicatorHeight,
        indicatorSize: TabBarIndicatorSize.tab, // Senior Fix: La barra ocupa todo el ancho del tab
        labelPadding: EdgeInsets.symmetric(horizontal: itemHPadding),
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFFA5A5AA),
        onTap: (i) {
          if (widget.selectedIndex != i) {
            widget.onTabSelected(i);
          }
        },
        tabs: widget.labels.map((label) {
          return Tab(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: widget.isCompact ? 6 : 8),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
