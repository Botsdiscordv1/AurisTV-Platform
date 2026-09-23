import 'package:flutter_test/flutter_test.dart';
import 'package:auris_core/auris_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:hive_ce/hive.dart';
import 'dart:io';

class MockAurisRepository implements AurisRepository {
  final List<Map<String, dynamic>> sentEvents = [];
  AnimeDetail? mockDetail;

  @override
  Future<void> sendUserEvent({required String userId, required String animeId, required String event, String? sectionId}) async {
    sentEvents.add({
      'userId': userId,
      'animeId': animeId,
      'event': event,
      'sectionId': sectionId,
    });
  }

  @override Future<AnimeDetail?> getAnimeDetail({required String title, int? malId, String? metadataTitle, int? year, int? season, String? kind, String? url, String? type, String? server, String? imgSize}) async {
    return mockDetail;
  }

  // Otros stubs
  @override Future<SearchResponse> search(String category, String query, {int? year, String? server, String? phase, String? imgSize, int page = 1, CancelToken? cancelToken}) async => SearchResponse(results: [], query: query, category: category, count: 0);
  @override Stream<SearchResponse> searchStream(String category, String query, {int? year, String? server, String? phase, String? imgSize, CancelToken? cancelToken}) async* {}
  @override Future<SearchResponse> searchAnimeVariants({required String q, String? display, String? english, String? native_, String? collapsed, List<String>? synonyms}) async => SearchResponse(results: [], query: q, category: 'anime', count: 0);
  @override Future<MovieDetail?> getMovieDetail({required String title, int? year, String? metadataTitle, String? url, String? type, String category = 'movie', String? server, String? kind, String? imgSize}) async => null;
  @override Future<List<MediaItem>> getHomeHero({String category = 'anime', String? imgSize}) async => [];
  @override Future<HomeResponse> getUserHome({required String userId, String? category}) async => HomeResponse(userId: userId, maturityLevel: 'cold', sections: [], generatedAt: '');
  @override Future<ScheduleResponse> getSchedule() async => const ScheduleResponse(days: [], season: '1', year: 2026, total: 0);
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

class SimpleMockAuthNotifier extends AuthNotifier {
  SimpleMockAuthNotifier(UserAccount? user) : super() {
    state = user;
  }
  @override void _init() {} // No cargar de Hive
}

void main() {
  late MockAurisRepository mockRepo;
  late ProviderContainer container;

  setUp(() async {
    mockRepo = MockAurisRepository();
    final user = UserAccount(id: 'user_1', activeProfileId: 'profile_1');
    
    final tempDir = Directory.systemTemp.createTempSync();
    Hive.init(tempDir.path);
    await Hive.openBox('user_data');
    await Hive.openBox('home_cache');

    container = ProviderContainer(
      overrides: [
        aurisRepositoryProvider.overrideWithValue(mockRepo),
        authProvider.overrideWith((ref) => SimpleMockAuthNotifier(user)),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('detail_view — NO se dispara por precarga del provider de datos', () async {
    mockRepo.mockDetail = const AnimeDetail(id: "anime_123", title: "Test");
    final params = const UnifiedDetailParams(title: "Test", category: "anime", url: "https://test.com/a", source: "AniList");

    await container.read(unifiedContentDetailProvider(params).future);
    
    expect(mockRepo.sentEvents.where((e) => e['event'] == 'detail_view'), isEmpty);
  });

  test('detail_view — SI se dispara cuando la UI observa el tracker provider', () async {
    mockRepo.mockDetail = const AnimeDetail(id: "anime_123", title: "Test");
    final params = const UnifiedDetailParams(title: "Test", category: "anime", url: "https://test.com/a", source: "AniList");

    container.read(detailViewTrackerProvider(params));
    await container.read(unifiedContentDetailProvider(params).future);
    await Future.delayed(const Duration(milliseconds: 100)); // Dar tiempo al listener
    
    final events = mockRepo.sentEvents.where((e) => e['event'] == 'detail_view').toList();
    expect(events.length, 1);
    expect(events.first['animeId'], "anime_123");
  });

  test('detail_view — NO se duplica por rebuilds (lecturas consecutivas)', () async {
    mockRepo.mockDetail = const AnimeDetail(id: "anime_123", title: "Test");
    final params = const UnifiedDetailParams(title: "Test", category: "anime", url: "https://test.com/a", source: "AniList");

    container.read(detailViewTrackerProvider(params));
    await container.read(unifiedContentDetailProvider(params).future);
    await Future.delayed(const Duration(milliseconds: 100));
    
    container.read(detailViewTrackerProvider(params));
    container.read(detailViewTrackerProvider(params));

    final events = mockRepo.sentEvents.where((e) => e['event'] == 'detail_view').toList();
    expect(events.length, 1); 
  });
}
