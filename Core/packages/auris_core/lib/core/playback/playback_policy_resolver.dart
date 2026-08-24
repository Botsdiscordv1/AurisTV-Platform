import 'media_category.dart';
import 'playback_policy.dart';

class PlaybackPolicyResolver {
  static const animePolicy = PlaybackPolicy(
    nextContentThreshold: 0.93,
    completedThreshold: 0.95,
    preloadNext: true,
    autoPlayNext: true,
  );

  static const seriesPolicy = PlaybackPolicy(
    nextContentThreshold: 0.95,
    completedThreshold: 0.95,
    preloadNext: true,
    autoPlayNext: true,
  );

  static const moviePolicy = PlaybackPolicy(
    remainingTimeThreshold: Duration(seconds: 60),
    completedThreshold: 0.98,
    preloadNext: false,
    autoPlayNext: false,
  );

  static const ovaPolicy = PlaybackPolicy(
    nextContentThreshold: 0.95,
    completedThreshold: 0.95,
    preloadNext: true,
    autoPlayNext: true,
  );

  static const specialPolicy = PlaybackPolicy(
    remainingTimeThreshold: Duration(seconds: 60),
    completedThreshold: 0.98,
    preloadNext: false,
    autoPlayNext: false,
  );

  static PlaybackPolicy resolve(MediaCategory category) {
    switch (category) {
      case MediaCategory.anime:
        return animePolicy;
      case MediaCategory.series:
        return seriesPolicy;
      case MediaCategory.movie:
        return moviePolicy;
      case MediaCategory.ova:
        return ovaPolicy;
      case MediaCategory.special:
        return specialPolicy;
    }
  }

  static MediaCategory fromString(String category) {
    switch (category.toLowerCase()) {
      case 'anime':
        return MediaCategory.anime;
      case 'series':
      case 'kdrama':
        return MediaCategory.series;
      case 'movie':
      case 'peliculas':
      case 'movie_anime':
        return MediaCategory.movie;
      case 'ova':
        return MediaCategory.ova;
      case 'special':
        return MediaCategory.special;
      default:
        return MediaCategory.anime;
    }
  }
}
