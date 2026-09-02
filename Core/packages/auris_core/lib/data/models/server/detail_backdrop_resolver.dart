import 'anime_detail.dart';
import 'movie_detail.dart';

/// Centralized backdrop resolution logic.
///
/// Priority: TMDB backdrop > banner param > source banner > poster
///
/// This ensures consistent backdrop selection across all platforms
/// (Web, TV, Movil) without duplicating logic.
class DetailBackdropResolver {
  /// Resolves the best available backdrop image URL.
  ///
  /// [detail] - The anime or movie detail object (can be null).
  /// [bannerParam] - Optional banner URL from navigation params.
  /// [sourceBanner] - Optional banner from search source.
  /// [poster] - Fallback poster URL.
  /// [season] - Current season number for dynamic backdrop.
  ///
  /// Returns the highest priority backdrop URL available.
  static String resolve({
    dynamic detail,
    String? bannerParam,
    String? sourceBanner,
    String? poster,
    int? season,
  }) {
    // 1. Specific season backdrop (if available)
    if (season != null && detail is AnimeDetail) {
      final seasonBackdrop = detail.backdropsBySeason[season];
      if (seasonBackdrop != null && seasonBackdrop.isNotEmpty) {
        return seasonBackdrop;
      }
    }

    // 2. TMDB backdrop (general or fallback for S1)
    final backdrop = _extractBackdrop(detail);
    if (backdrop != null && backdrop.isNotEmpty) return backdrop;

    // 3. Banner from navigation param
    if (bannerParam != null && bannerParam.isNotEmpty) return bannerParam;

    // 4. Banner from search source
    if (sourceBanner != null && sourceBanner.isNotEmpty) return sourceBanner;

    // 5. Poster (fallback)
    return poster ?? '';
  }

  static String? _extractBackdrop(dynamic detail) {
    if (detail is AnimeDetail) return detail.backdrop;
    if (detail is MovieDetail) return detail.backdrop;
    return null;
  }
}