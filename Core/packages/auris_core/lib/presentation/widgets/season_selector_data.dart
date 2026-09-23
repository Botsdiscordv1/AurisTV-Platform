import 'package:flutter/material.dart';

/// Data model for season selector state.
///
/// Encapsulates all season-related state that was previously
/// duplicated across Web, TV, and Movil content screens.
class SeasonSelectorData {
  /// The currently selected season number (1-based).
  final int currentSeason;

  /// Total number of seasons available.
  final int totalSeasons;

  /// Callback when user selects a different season.
  final void Function(int season) onSeasonSelected;

  /// Whether to use compact styling (smaller dimensions).
  final bool compact;

  /// Optional fixed width override.
  final double? width;

  /// Whether to enable focus support (for TV remote control).
  final bool enableFocus;

  /// Optional scale function for responsive sizing.
  /// Example: TV uses ResponsiveUtils.sp, Web/Movil use null.
  /// Signature: double Function(BuildContext context, double value)
  final double Function(BuildContext, double)? scale;

  /// Optional fixed height override for precise fluid layout
  final double? height;

  /// Optional font size override
  final double? fontSize;

  /// Optional total episodes count to display in selector
  final int? totalEpisodes;

  const SeasonSelectorData({
    required this.currentSeason,
    required this.totalSeasons,
    required this.onSeasonSelected,
    this.compact = false,
    this.width,
    this.enableFocus = false,
    this.scale,
    this.height,
    this.fontSize,
    this.totalEpisodes,
  });

  /// Whether there are multiple seasons to choose from.
  bool get hasMultipleSeasons => totalSeasons > 1;
}