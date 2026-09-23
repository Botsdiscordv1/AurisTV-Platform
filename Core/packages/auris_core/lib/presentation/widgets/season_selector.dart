import 'package:flutter/material.dart';
import 'season_selector_data.dart';

/// A shared season selector widget for all platforms.
///
/// Supports configurable sizing, focus (TV remote), and responsive scaling.
///
/// Usage:
/// ```dart
/// // Web/Desktop
/// SeasonSelector(
///   currentSeason: 1,
///   totalSeasons: 3,
///   onSeasonSelected: (s) => setState(() => _selectedSeason = s),
/// )
///
/// // TV (with focus and responsive scaling)
/// SeasonSelector(
///   currentSeason: 1,
///   totalSeasons: 3,
///   onSeasonSelected: (s) => setState(() => _selectedSeason = s),
///   enableFocus: true,
///   scale: ResponsiveUtils.sp,
/// )
/// ```
class SeasonSelector extends StatefulWidget {
  final SeasonSelectorData data;

  const SeasonSelector({super.key, required this.data});

  @override
  State<SeasonSelector> createState() => _SeasonSelectorState();
}

class _SeasonSelectorState extends State<SeasonSelector> {
  bool _isHovered = false;
  bool _isFocused = false;

  double _sp(BuildContext context, double value) {
    return widget.data.scale?.call(context, value) ?? value;
  }

  double _getWidth(BuildContext context) {
    if (widget.data.width != null) return widget.data.width!;
    return widget.data.compact ? _sp(context, 160) : _sp(context, 220);
  }

  double _getHeight(BuildContext context) {
    if (widget.data.height != null) return widget.data.height!;
    return widget.data.compact ? _sp(context, 44) : _sp(context, 56);
  }

  bool get _isActive => _isHovered || (widget.data.enableFocus && _isFocused);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(canvasColor: const Color(0xFF1E1E26)),
      child: PopupMenuButton<int>(
        onSelected: widget.data.onSeasonSelected,
        offset: Offset(0, _sp(context, 50)),
        constraints: BoxConstraints(minWidth: _sp(context, 180)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white12),
        ),
        itemBuilder: (context) => List.generate(
          widget.data.totalSeasons,
          (i) => PopupMenuItem(
            value: i + 1,
            height: _sp(context, 48),
            child: Text(
              'Temporada ${i + 1}',
              style: TextStyle(
                color: (i + 1) == widget.data.currentSeason
                    ? Colors.white
                    : const Color(0xFFA5A5AA),
                fontWeight: (i + 1) == widget.data.currentSeason
                    ? FontWeight.bold
                    : FontWeight.normal,
                fontSize: _sp(context, 16),
              ),
            ),
          ),
        ),
        child: MouseRegion(
          onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _isHovered = true);
          }),
          onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _isHovered = false);
          }),
          child: Focus(
            onFocusChange: widget.data.enableFocus
                ? (hasFocus) {
                    if (mounted) setState(() => _isFocused = hasFocus);
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _getWidth(context),
              height: _getHeight(context),
              decoration: BoxDecoration(
                color: _isActive ? const Color(0xFF454652) : const Color(0xFF32333E),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isActive ? const Color(0xFFA5A5AA) : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.data.compact ? _sp(context, 12) : _sp(context, 20)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'T ${widget.data.currentSeason}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: widget.data.fontSize ?? _sp(context, 20),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: widget.data.compact ? 18 : 24,
                      color: _isActive ? Colors.white : const Color(0xFFA5A5AA),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}