import '../../data/models/server/search_result.dart';

/// Encapsulates season resolution logic that was previously
/// duplicated across Web, TV, and Movil content screens.
class SeasonResolver {
  /// Resolves the effective season state based on user selection and opened season.
  ///
  /// [selectedSeason] - User-selected season (null if not changed).
  /// [openedSeasonN] - Season number from the originally opened content.
  /// [title] - Base title without season suffix.
  ///
  /// Returns a [SeasonResolution] with all derived values.
  static SeasonResolution resolve({
    required int? selectedSeason,
    required int openedSeasonN,
    required String title,
  }) {
    final effectiveSeasonForUrl = selectedSeason ?? (openedSeasonN > 1 ? openedSeasonN : null);
    final seasonSwitched = selectedSeason != null && selectedSeason != openedSeasonN;
    final seasonTitle = seasonSwitched ? _seasonTitleFor(title, selectedSeason) : null;

    return SeasonResolution(
      selectedSeason: selectedSeason,
      openedSeasonN: openedSeasonN,
      effectiveSeasonForUrl: effectiveSeasonForUrl,
      seasonSwitched: seasonSwitched,
      seasonTitle: seasonTitle,
    );
  }

  /// Generates the season-aware title (e.g., "Youjo Senki" + S2 → "Youjo Senki II").
  static String _seasonTitleFor(String baseTitle, int? season) {
    if (season == null || season <= 1) return baseTitle;
    const suffixes = ['', '', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'];
    if (season < suffixes.length) return '$baseTitle ${suffixes[season]}';
    return '$baseTitle Season $season';
  }

  /// Extracts season number from a title string.
  static int? extractSeason(String? title) {
    if (title == null || title.isEmpty) return null;
    final match = RegExp(r'(?:season|temporada)\s*(\d+)', caseSensitive: false).firstMatch(title);
    if (match != null) return int.tryParse(match.group(1)!);
    final romanMatch = RegExp(r'\b(I{1,3}|IV|V|VI{0,3}|IX|X)\b', caseSensitive: false).firstMatch(title);
    if (romanMatch != null) {
      const romanMap = {'I': 1, 'II': 2, 'III': 3, 'IV': 4, 'V': 5, 'VI': 6, 'VII': 7, 'VIII': 8, 'IX': 9, 'X': 10};
      return romanMap[romanMatch.group(1)!.toUpperCase()];
    }
    return null;
  }

  /// Strips season suffix from title (e.g., "Youjo Senki II" → "Youjo Senki").
  static String stripSeasonSuffix(String title) {
    return title
        .replaceAll(RegExp(r'\s*(?:Season|Temporada)\s*\d+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*(?:I{1,3}|IV|V|VI{0,3}|IX|X)\s*$'), '')
        .trim();
  }

  /// Applies season unified transform to a SearchResult.
  static SearchResult? withSeasonUnified(SearchResult? source, int? season) {
    if (source == null || season == null || season <= 1) return source;
    return source.copyWith(season: season);
  }
}

/// Encapsulates resolved season state.
class SeasonResolution {
  final int? selectedSeason;
  final int openedSeasonN;
  final int? effectiveSeasonForUrl;
  final bool seasonSwitched;
  final String? seasonTitle;

  const SeasonResolution({
    this.selectedSeason,
    required this.openedSeasonN,
    this.effectiveSeasonForUrl,
    required this.seasonSwitched,
    this.seasonTitle,
  });

  /// The season number to display in the UI.
  int get displaySeason => selectedSeason ?? openedSeasonN;
}