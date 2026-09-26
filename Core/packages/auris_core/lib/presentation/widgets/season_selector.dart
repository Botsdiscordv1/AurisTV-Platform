import 'package:flutter/material.dart';
import 'season_selector_data.dart';

/// A shared season selector widget for all platforms.
///
/// Supports configurable sizing, focus (TV remote), responsive scaling,
/// and a modern pill-shaped dropdown design.
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

  double _getHeight(BuildContext context) {
    if (widget.data.height != null) return widget.data.height!;
    return widget.data.compact ? _sp(context, 40) : _sp(context, 50);
  }

  bool get _isActive => _isHovered || (widget.data.enableFocus && _isFocused);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        canvasColor: const Color(0xFF161618),
        popupMenuTheme: const PopupMenuThemeData(
          color: Color(0xFF161618),
          surfaceTintColor: Colors.transparent,
        ),
      ),
      child: PopupMenuButton<int>(
        onSelected: widget.data.onSeasonSelected,
        offset: Offset(0, _sp(context, 52)),
        constraints: BoxConstraints(minWidth: _sp(context, 200)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF2C2C32), width: 1),
        ),
        color: const Color(0xFF161618),
        itemBuilder: (context) => List.generate(
          widget.data.totalSeasons,
          (i) => PopupMenuItem(
            value: i + 1,
            height: _sp(context, 46),
            child: Text(
              'Temporada ${i + 1}',
              style: TextStyle(
                color: (i + 1) == widget.data.currentSeason
                    ? Colors.white
                    : const Color(0xFF9E9FA5),
                fontWeight: (i + 1) == widget.data.currentSeason
                    ? FontWeight.bold
                    : FontWeight.normal,
                fontSize: _sp(context, 15),
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
              constraints: BoxConstraints(
                minWidth: widget.data.width ?? (widget.data.compact ? _sp(context, 140) : _sp(context, 210)),
                maxWidth: widget.data.width ?? _sp(context, 400),
              ),
              height: _getHeight(context),
              decoration: BoxDecoration(
                color: _isActive ? const Color(0xFF26262A) : const Color(0xFF161618),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isActive ? Colors.white54 : const Color(0xFF2C2C32),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.data.compact ? _sp(context, 14) : _sp(context, 18)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: RichText(
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Temporada ${widget.data.currentSeason}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: widget.data.fontSize ?? _sp(context, widget.data.compact ? 14 : 16),
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            if (widget.data.totalEpisodes != null && widget.data.totalEpisodes! > 0)
                              TextSpan(
                                text: ' (${widget.data.totalEpisodes} episodios)',
                                style: TextStyle(
                                  color: const Color(0xFFB2B4BC),
                                  fontSize: widget.data.fontSize ?? _sp(context, widget.data.compact ? 13 : 15),
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: _sp(context, 12)),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: widget.data.compact ? 20 : 24,
                      color: Colors.white,
                      weight: 700,
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
