import 'package:flutter_test/flutter_test.dart';
import 'package:auris_core/auris_core.dart';
import 'package:dio/dio.dart';

class MockAurisRepository implements AurisRepository {
  final List<Map<String, dynamic>> sentEvents = [];

  @override
  Future<void> sendUserEvent({required String userId, required String animeId, required String event, String? sectionId}) async {
    sentEvents.add({
      'userId': userId,
      'animeId': animeId,
      'event': event,
      'sectionId': sectionId ?? '',
    });
  }

  // Stubs con fábricas/constructores reales obligatorios de la firma del modelo
  @override Future<SearchResponse> search(String category, String query, {int? year, String? server, String? phase, String? imgSize, int page = 1, CancelToken? cancelToken}) async => SearchResponse(results: [], query: query, category: category, count: 0);
  @override Stream<SearchResponse> searchStream(String category, String query, {int? year, String? server, String? phase, String? imgSize, CancelToken? cancelToken}) async* {}
  @override Future<SearchResponse> searchAnimeVariants({required String q, String? display, String? english, String? native_, String? collapsed, List<String>? synonyms}) async => SearchResponse(results: [], query: q, category: 'anime', count: 0);
  @override Future<AnimeDetail?> getAnimeDetail({required String title, int? malId, String? metadataTitle, int? year, int? season, String? kind, String? url, String? type, String? server, String? imgSize}) async => null;
  @override Future<AnimeThemesData> getAnimeThemes({required String title, String? english, String? native_, String? server}) async => const AnimeThemesData();
  @override Future<MovieDetail?> getMovieDetail({required String title, int? year, String? metadataTitle, String? url, String? type, String category = 'movie', String? server, String? kind, String? imgSize}) async => null;
  @override Future<List<MediaItem>> getHomeHero({String category = 'anime', String? imgSize}) async => [];
  @override Future<HomeResponse> getUserHome({required String userId, String? category}) async => HomeResponse(userId: userId, maturityLevel: 'cold', sections: [], generatedAt: '');
  @override Future<ScheduleResponse> getSchedule() async => const ScheduleResponse(days: [], season: '1', year: 2026, total: 0);
  @override Future<Map<String, dynamic>?> pingSchedulePremieres(int since) async => null;
  @override Future<List<SourceInfo>> getSources() async => [];
  @override Future<EditorialResponse> getEditorial({String? imgSize, String? category, String? userId}) async => const EditorialResponse(generatedAt: '', locale: '', sections: []);
  @override Future<SearchResponse> filter({String? genre, int? year, String? category, String? status, String? idioma, int page = 1, String? source}) async => SearchResponse(results: [], query: '', category: category ?? '', count: 0);
  @override Future<int> getHomeVersion({String? category}) async => 0;
  @override Future<AnimeTitleInfo> getAnimeTitles(String query) async => const AnimeTitleInfo();
  @override Future<MovieTitleInfo> getMovieTitles(String query) async => const MovieTitleInfo();
  @override Future<ExtractResult> extractVideo(String url, String source, {String? category, bool direct = false, CancelToken? cancelToken}) async => const ExtractResult(url: '', headers: {});
  @override Future<String> resolveEpisodeUrl(String url, String source, int episode, {String? category}) async => '';
  @override Future<EpisodesResponse> getEpisodes(String url, String source, {String? category, String? title, String? fullTitle, String? altTitle, int? tmdbId, int? season, int? year, bool fast = false}) async => EpisodesResponse(episodes: const [], source: source, url: url, slug: '', total: 0);
  @override Future<List<CastInfo>> getCast(String url, {String? source, String? category, int? tmdbId, String? mediaType, String? title, int? year}) async => [];
  @override Future<List<RelatedInfo>> getRelations(String url, {String? source, String? category}) async => [];
  @override Future<SearchResponse> getCastCredits({String? url, String? name, String? profile, int? personId}) async => SearchResponse(results: [], query: '', category: '', count: 0);
  @override Future<List<OmdbEpisode>> getOmdbSeason({required String title, int season = 1, bool enrich = true}) async => [];
  @override Future<AnilistMedia?> getAnilistMedia(int id) async => null;
  @override Future<List<MediaItem>> getHomeRecent(int limit) async => [];
  @override Future<List<MediaItem>> getHomeTop(int limit) async => [];
  @override Future<GalleryResponse> getGallery({int? tmdbId, String kind = 'tv', String? title, int? year}) async => const GalleryResponse();
  @override Future<void> updateCatalogSources({required String title, required List<SourceItem> sources, int? season}) async {}
  @override Future<void> registerDeviceToken(String userId, String token, String platform) async {}
  @override Future<void> subscribeToTopic(String userId, String topic) async {}
  @override Future<void> unsubscribeFromTopic(String userId, String topic) async {}
  @override Future<OmdbEpisode?> getOmdbEpisode({required String title, int season = 1, int episode = 1}) async => null;
}

void main() {
  group('UserEventTracker — Unit & Deduplication E2E Tests', () {
    late MockAurisRepository mockRepo;
    late UserEventTracker tracker;

    setUp(() {
      mockRepo = MockAurisRepository();
      tracker = UserEventTracker(mockRepo);
    });

    test('1. play iniciado — envia exactamente 1 evento real', () {
      tracker.record(
        userId: "user_real_01",
        animeId: "anime_shounen_01",
        event: "play",
        playbackSessionId: "session_xyz_1",
      );

      expect(mockRepo.sentEvents.length, 1);
      expect(mockRepo.sentEvents.first['event'], "play");
    });

    test('2. 10 rebuilds rápidos — deduplica por debounce o sesión impidiendo spam', () {
      for (int i = 0; i < 10; i++) {
        tracker.record(
          userId: "user_real_01",
          animeId: "anime_shounen_01",
          event: "detail_view",
        );
      }

      // El debounce cache bloquea ráfagas menores a 1.5s
      expect(mockRepo.sentEvents.length, 1);
    });

    test('3. completed_view — se envia solo una vez bajo la misma sesion', () {
      for (int i = 0; i < 5; i++) {
        tracker.record(
          userId: "user_real_01",
          animeId: "anime_shounen_01",
          event: "completed_view",
          playbackSessionId: "session_xyz_1",
        );
      }

      expect(mockRepo.sentEvents.length, 1);
      expect(mockRepo.sentEvents.first['event'], "completed_view");
    });

    test('4. null animeId o guest_profile — aborta de inmediato emitiendo 0 eventos', () {
      tracker.record(
        userId: "guest_profile",
        animeId: "anime_123",
        event: "play",
      );

      tracker.record(
        userId: "user_real_01",
        animeId: null,
        event: "play",
      );

      expect(mockRepo.sentEvents, isEmpty);
    });

    test('5. replay en nueva sesion posterior — permite registrar un nuevo play', () {
      tracker.record(
        userId: "user_real_01",
        animeId: "anime_shounen_01",
        event: "play",
        playbackSessionId: "session_xyz_1",
      );

      tracker.record(
        userId: "user_real_01",
        animeId: "anime_shounen_01",
        event: "play",
        playbackSessionId: "session_abc_2", // Nueva ID de sesión de reproducción
      );

      expect(mockRepo.sentEvents.length, 2);
    });
  });
}
