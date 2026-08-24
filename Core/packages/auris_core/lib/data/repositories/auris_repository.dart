import '../models/server/anilist_media.dart';
import '../models/server/editorial_section.dart';
import '../models/server/episodes_response.dart';
import '../models/server/extract_result.dart';
import '../models/server/omdb_episode.dart';
import '../models/server/search_result.dart';
import '../models/server/anime_detail.dart';
import '../models/server/movie_detail.dart';
import '../models/server/schedule.dart';
import '../models/server/source_info.dart';
import '../models/server/title_info.dart';
import '../models/server/gallery.dart';
import '../models/media_item.dart';

abstract class AurisRepository {
  Future<SearchResponse> search(String category, String query, {int? year, String? server});
  Future<SearchResponse> searchAnimeVariants({
    required String q,
    String? display,
    String? english,
    String? native_,
    String? collapsed,
    List<String>? synonyms,
  });
  Future<AnimeDetail?> getAnimeDetail({
    required String title,
    int? malId,
    String? metadataTitle,
    int? year,
    int? season,
  });
  Future<MovieDetail?> getMovieDetail({
    required String title,
    int? year,
    String? metadataTitle,
    String? url,
    String? quality,
    String category = 'movie',
    String? server,
  });
  Future<ScheduleResponse> getSchedule();
  Future<List<SourceInfo>> getSources();
  Future<EditorialResponse> getEditorial();
  Future<AnimeTitleInfo> getAnimeTitles(String query);
  Future<MovieTitleInfo> getMovieTitles(String query);
  Future<ExtractResult> extractVideo(String url, String source, {String? category, bool direct = false});
  Future<String> resolveEpisodeUrl(String url, String source, int episode, {String? category});
  Future<EpisodesResponse> getEpisodes(String url, String source, {String? category, String? title, String? fullTitle, String? altTitle, int? tmdbId, int? season, int? year});
  Future<List<OmdbEpisode>> getOmdbSeason({required String title, int season = 1, bool enrich = true});
  Future<OmdbEpisode?> getOmdbEpisode({required String title, int season = 1, int episode = 1});
  Future<AnilistMedia?> getAnilistMedia(int id);
  Future<List<MediaItem>> getHomeRecent(int limit);
  Future<List<MediaItem>> getHomeTop(int limit);
  Future<GalleryResponse> getGallery({int? tmdbId, String kind = 'tv', String? title, int? year});
}
