import 'package:flutter_test/flutter_test.dart';
import 'package:auris_core/auris_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:dio/dio.dart';
import 'dart:io';

class AuditRepository implements AurisRepository {
  final List<Map<String, dynamic>> log = [];
  
  @override
  Future<void> sendUserEvent({required String userId, required String animeId, required String event, String? sectionId}) async {
    log.add({
      'method': 'POST',
      'path': '/api/user/events',
      'body': {
        'userId': userId,
        'animeId': animeId,
        'event': event,
        'sectionId': sectionId,
      }
    });
  }

  @override Future<HomeResponse> getUserHome({required String userId, String? category}) async => HomeResponse(userId: userId, maturityLevel: 'cold', sections: [], generatedAt: '');
  @override Future<SearchResponse> search(String category, String query, {int? year, String? server, String? phase, String? imgSize, int page = 1, CancelToken? cancelToken}) async => SearchResponse(results: [], query: query, category: category, count: 0);
  @override Stream<SearchResponse> searchStream(String category, String query, {int? year, String? server, String? phase, String? imgSize, CancelToken? cancelToken}) async* {}
  @override Future<SearchResponse> searchAnimeVariants({required String q, String? display, String? english, String? native_, String? collapsed, List<String>? synonyms}) async => SearchResponse(results: [], query: q, category: 'anime', count: 0);
  @override Future<AnimeDetail?> getAnimeDetail({required String title, int? malId, String? metadataTitle, int? year, int? season, String? kind, String? url, String? type, String? server, String? imgSize}) async => null;
  @override Future<MovieDetail?> getMovieDetail({required String title, int? year, String? metadataTitle, String? url, String? type, String category = 'movie', String? server, String? kind, String? imgSize}) async => null;
  @override Future<List<MediaItem>> getHomeHero({String category = 'anime', String? imgSize}) async => [];
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

class MockAuthNotifier extends AuthNotifier {
  MockAuthNotifier(UserAccount? user) : super() { state = user; }
  @override void _init() {} 
}

void main() {
  late AuditRepository auditRepo;
  late ProviderContainer container;

  setUp(() async {
    auditRepo = AuditRepository();
    final user = UserAccount(id: 'user_e2e_test', activeProfileId: 'profile_action_fan');
    
    final tempDir = Directory.systemTemp.createTempSync();
    Hive.init(tempDir.path);
    await Hive.openBox('user_data');
    await Hive.openBox('home_cache');
    await Hive.openBox('favorites');
    await Hive.openBox('playback_history');

    container = ProviderContainer(
      overrides: [
        aurisRepositoryProvider.overrideWithValue(auditRepo),
        authProvider.overrideWith((ref) => MockAuthNotifier(user)),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('Auditoría Ciclo E2E: Payload y Contrato de Red', () async {
    const String canonicalId = "113415"; // Jujutsu Kaisen
    final tracker = container.read(userEventTrackerProvider);
    final userId = 'profile_action_fan';

    // Disparar los 4 eventos principales
    tracker.record(userId: userId, animeId: canonicalId, event: 'detail_view');
    tracker.record(userId: userId, animeId: canonicalId, event: 'play', playbackSessionId: 'sess_1');
    tracker.record(userId: userId, animeId: canonicalId, event: 'favorite');
    tracker.record(userId: userId, animeId: canonicalId, event: 'completed_view', playbackSessionId: 'sess_1');

    final events = auditRepo.log.where((l) => l['method'] == 'POST').toList();

    expect(events.length, 4);

    for (var i = 0; i < events.length; i++) {
      final e = events[i];
      final body = e['body'] as Map;
      
      expect(e['path'], '/api/user/events');
      expect(body['userId'], userId);
      expect(body['animeId'], canonicalId);
    }
    
    final names = events.map((e) => e['body']['event']).toList();
    expect(names, ['detail_view', 'play', 'favorite', 'completed_view']);
  });

  test('Auditoría Contexto: El evento conserva el sectionId si se proporciona', () {
    final tracker = container.read(userEventTrackerProvider);
    const String sectionId = 'for_you';
    const String animeId = '113415';

    tracker.record(
      userId: 'profile_action_fan', 
      animeId: animeId, 
      event: 'play', 
      sectionId: sectionId
    );

    final event = auditRepo.log.last;
    expect(event['body']['sectionId'], sectionId);
  });

  test('Auditoría Deduplicación: Misma sesión no duplica completed_view', () {
     final tracker = container.read(userEventTrackerProvider);
     final userId = 'profile_action_fan';
     const String animeId = "123";

     tracker.record(userId: userId, animeId: animeId, event: 'completed_view', playbackSessionId: 'sess_A');
     tracker.record(userId: userId, animeId: animeId, event: 'completed_view', playbackSessionId: 'sess_A'); // Duplicado
     tracker.record(userId: userId, animeId: animeId, event: 'completed_view', playbackSessionId: 'sess_B'); // Nueva sesión

     final events = auditRepo.log.where((l) => l['body']['event'] == 'completed_view').toList();
     expect(events.length, 2);
  });

  test('Auditoría Seguridad: guest_profile es ignorado', () {
     final tracker = container.read(userEventTrackerProvider);
     tracker.record(userId: 'guest_profile', animeId: '123', event: 'play');
     
     expect(auditRepo.log, isEmpty);
  });
}
