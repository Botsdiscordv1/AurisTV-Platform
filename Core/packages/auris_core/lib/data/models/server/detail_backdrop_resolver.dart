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
  ///
  /// Returns the highest priority backdrop URL available.
  static String resolve({
    dynamic detail,
    String? bannerParam,
    String? sourceBanner,
    String? poster,
  }) {
    // 1. TMDB backdrop (highest priority)
    final backdrop = _extractBackdrop(detail);
    if (backdrop != null && backdrop.isNotEmpty) return backdrop;

    // 2. Banner from navigation param
    if (bannerParam != null && bannerParam.isNotEmpty) return bannerParam;

    // 3. Banner from search source
    if (sourceBanner != null && sourceBanner.isNotEmpty) return sourceBanner;

    // 4. Poster (fallback)
    return poster ?? '';
  }

  static String? _extractBackdrop(dynamic detail) {
    if (detail is AnimeDetail) return detail.backdrop;
    if (detail is MovieDetail) return detail.backdrop;
    return null;
  }
}