import 'dart:io';

import 'package:auris_core/auris_core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// Reproduce el bug real de la pestaña Animes:
/// el TOP10 llega por dos rutas con títulos que solo difieren en la tilde
///   - editorial/endpoint : "Top 10 Animes del Dia"  (10 items)
///   - user/home          : "Top 10 Animes del Día"  (3 items)
/// y el dedupe era por título exacto => DOS secciones TOP10 en el home,
/// ganando la de user/home (3 items) en vez del endpoint (10 items).
class Top10Repo implements AurisRepository {
  bool withCache = false;

  static const List<String> endpointIds = [
    'E1', 'E2', 'E3', 'E4', 'E5', 'E6', 'E7', 'E8', 'E9', 'E10',
  ];

  EditorialResponse editorial() => EditorialResponse(
        generatedAt: '2026-03-30T12:00:00Z',
        locale: 'es-MX',
        sections: const [
          EditorialSection(
            id: 'essential',
            title: 'Explora animes',
            badge: 'essential',
            format: 'poster',
            items: [
              EditorialItem(id: 'explore_1', title: 'Explora 1', posterUrl: 'u', badge: 'essential'),
            ],
          ),
          EditorialSection(
            id: 'top10Airing',
            title: 'Top 10 Animes del Dia',
            badge: 'essential',
            format: 'top10',
            items: [
              EditorialItem(id: 'E1', title: 'E1', posterUrl: 'u', badge: 'essential'),
              EditorialItem(id: 'E2', title: 'E2', posterUrl: 'u', badge: 'essential'),
              EditorialItem(id: 'E3', title: 'E3', posterUrl: 'u', badge: 'essential'),
              EditorialItem(id: 'E4', title: 'E4', posterUrl: 'u', badge: 'essential'),
              EditorialItem(id: 'E5', title: 'E5', posterUrl: 'u', badge: 'essential'),
              EditorialItem(id: 'E6', title: 'E6', posterUrl: 'u', badge: 'essential'),
              EditorialItem(id: 'E7', title: 'E7', posterUrl: 'u', badge: 'essential'),
              EditorialItem(id: 'E8', title: 'E8', posterUrl: 'u', badge: 'essential'),
              EditorialItem(id: 'E9', title: 'E9', posterUrl: 'u', badge: 'essential'),
              EditorialItem(id: 'E10', title: 'E10', posterUrl: 'u', badge: 'essential'),
            ],
          ),
        ],
      );

  HomeResponse userHome(String userId) => HomeResponse(
        userId: userId,
        maturityLevel: 'personalized',
        generatedAt: '',
        sections: const [
          HomeSection(
            id: 'sec_top10',
            title: 'Top 10 Animes del Día',
            strategy: 's',
            type: 'editorial',
            priority: 1,
            format: 'top10',
            items: [
              HomeItem(id: 'U1', title: 'U1'),
              HomeItem(id: 'U2', title: 'U2'),
              HomeItem(id: 'U3', title: 'U3'),
            ],
          ),
          HomeSection(
            id: 'sec_personal',
            title: 'Sección personalizada',
            strategy: 's',
            type: 'recommendation',
            priority: 2,
            items: [
              HomeItem(id: 'P1', title: 'P1'),
            ],
          ),
        ],
      );

  @override
  Future<EditorialResponse> getEditorial({String? imgSize, String? category, String? userId}) async =>
      editorial();

  @override
  Future<HomeResponse> getUserHome({required String userId, String? category}) async =>
      userHome(userId);

  @override
  Future<SearchResponse> filter({String? genre, int? year, String? category, String? status, String? idioma, int page = 1, String? source}) async =>
      SearchResponse(results: [], query: '', category: category ?? '', count: 0);

  @override
  Future<int> getHomeVersion({String? category}) async => 0;
  @override
  Future<void> sendUserEvent({required String userId, required String animeId, required String event, String? sectionId}) async {}
  @override
  Future<SearchResponse> search(String category, String query, {int? year, String? server, String? phase, String? imgSize, int page = 1, CancelToken? cancelToken}) async => SearchResponse(results: [], query: query, category: category, count: 0);
  @override
  Stream<SearchResponse> searchStream(String category, String query, {int? year, String? server, String? phase, String? imgSize, int page = 1, CancelToken? cancelToken}) async* {}
  @override
  Future<SearchResponse> searchAnimeVariants({required String q, String? display, String? english, String? native_, String? collapsed, List<String>? synonyms}) async => SearchResponse(results: [], query: q, category: 'anime', count: 0);
  @override
  Future<AnimeDetail?> getAnimeDetail({required String title, int? malId, String? metadataTitle, int? year, int? season, String? kind, String? url, String? type, String? server, String? imgSize}) async => null;
  @override
  Future<AnimeThemesData> getAnimeThemes({required String title, String? english, String? native_, String? server}) async => const AnimeThemesData();
  @override
  Future<MovieDetail?> getMovieDetail({required String title, int? year, String? metadataTitle, String? url, String? type, String category = 'movie', String? server, String? kind, String? imgSize}) async => null;
  @override
  Future<List<MediaItem>> getHomeHero({String category = 'anime', String? imgSize}) async => [];
  @override
  Future<List<ContentSports>> getSportsEvents({bool live = true}) async => [];
  @override
  Future<ScheduleResponse> getSchedule() async => const ScheduleResponse(days: [], season: '1', year: 2026, total: 0);
  @override
  Future<Map<String, dynamic>?> pingSchedulePremieres(int since) async => null;
  @override
  Future<List<SourceInfo>> getSources() async => [];
  @override
  Future<AnimeTitleInfo> getAnimeTitles(String query) async => const AnimeTitleInfo();
  @override
  Future<MovieTitleInfo> getMovieTitles(String query) async => const MovieTitleInfo();
  @override
  Future<ExtractResult> extractVideo(String url, String source, {String? category, bool direct = false, CancelToken? cancelToken}) async => const ExtractResult(url: '', headers: {});
  @override
  Future<String> resolveEpisodeUrl(String url, String source, int episode, {String? category}) async => '';
  @override
  Future<EpisodesResponse> getEpisodes(String url, String source, {String? category, String? title, String? fullTitle, String? altTitle, int? tmdbId, int? season, int? year, bool fast = false}) async => EpisodesResponse(episodes: const [], source: source, url: url, slug: '', total: 0);
  @override
  Future<List<CastInfo>> getCast(String url, {String? source, String? category, int? tmdbId, String? mediaType, String? title, int? year}) async => [];
  @override
  Future<List<RelatedInfo>> getRelations(String url, {String? source, String? category}) async => [];
  @override
  Future<SearchResponse> getCastCredits({String? url, String? name, String? profile, int? personId}) async => SearchResponse(results: [], query: '', category: '', count: 0);
  @override
  Future<List<OmdbEpisode>> getOmdbSeason({required String title, int season = 1, bool enrich = true}) async => [];
  @override
  Future<AnilistMedia?> getAnilistMedia(int id) async => null;
  @override
  Future<List<MediaItem>> getHomeRecent(int limit) async => [];
  @override
  Future<List<MediaItem>> getHomeTop(int limit) async => [];
  @override
  Future<GalleryResponse> getGallery({int? tmdbId, String kind = 'tv', String? title, int? year}) async => const GalleryResponse();
  @override
  Future<void> updateCatalogSources({required String title, required List<SourceItem> sources, int? season}) async {}
  @override
  Future<void> registerDeviceToken(String userId, String token, String platform) async {}
  @override
  Future<void> subscribeToTopic(String userId, String topic) async {}
  @override
  Future<void> unsubscribeFromTopic(String userId, String topic) async {}
  @override
  Future<OmdbEpisode?> getOmdbEpisode({required String title, int season = 1, int episode = 1}) async => null;
}

class MockAuthNotifier extends AuthNotifier {
  MockAuthNotifier(UserAccount? user) : super() {
    state = user;
  }
}

void main() {
  const userId = 'user_top10';
  late Top10Repo repo;
  late ProviderContainer container;

  /// Cuenta las TOP10 del layout final y exige UNA sola, servida por el
  /// endpoint (10 items, título sin tilde) y nunca la copia de user/home.
  void expectSingleTop10FromEndpoint(List<ComposedHomeSection> layout) {
    final tops = layout.where((s) => s.presentation == SectionPresentation.top10).toList();

    expect(tops.length, 1, reason: 'Debe haber UNA sola sección TOP10, hay: '
        '${tops.map((t) => '${t.title}(${t.items.length})').join(', ')}');
    expect(tops.first.title, 'Top 10 Animes del Dia');
    expect(tops.first.items.length, 10, reason: 'Debe servir los 10 items del endpoint, no los 3 de user/home');
  }

  setUpAll(() async {
    final tempDir = Directory.systemTemp.createTempSync();
    Hive.init(tempDir.path);
    await Hive.openBox('home_cache');
  });

  setUp(() async {
    // Limpia la caché del test anterior para que cada caso arranque en frío.
    await Hive.box('home_cache').clear();
    repo = Top10Repo();
    container = ProviderContainer(
      overrides: [
        aurisRepositoryProvider.overrideWithValue(repo),
        authProvider.overrideWith((ref) => MockAuthNotifier(UserAccount(id: userId, activeProfileId: userId))),
      ],
    );
    container.read(homeCategoryProvider.notifier).state = 'animes';
  });

  tearDown(() {
    container.dispose();
  });

  test('TOP10 duplicado: cold start (sin caché) deja UNA sección con los 10 items del endpoint', () async {
    // La sección de user/home solo llega en la ETAPA 3: con esta condición el
    // test espera el layout final y no se conforma con el yield de ETAPA 2.
    final layout = await container.read(homeLayoutProvider.stream).firstWhere(
          (l) => l.any((s) => s.title == 'Sección personalizada') &&
              l.any((s) => s.presentation == SectionPresentation.top10 && s.items.length == 10),
        );

    expectSingleTop10FromEndpoint(layout);
    expect(layout.any((s) => s.title == 'Sección personalizada'), isTrue);
  });

  test('TOP10 duplicado: con caché de user/home (título con tilde) el endpoint pisa a la copia', () async {
    final box = Hive.box('home_cache');
    await box.put('personalized_home_${userId}_animes', repo.userHome(userId).toJson());

    final layout = await container.read(homeLayoutProvider.stream).firstWhere(
          (l) => l.any((s) => s.title == 'Sección personalizada') &&
              l.any((s) => s.presentation == SectionPresentation.top10 && s.items.length == 10),
        );

    expectSingleTop10FromEndpoint(layout);
  });

  test('TOP10 duplicado: si el editorial falla, se conserva la de user/home como fallback', () async {
    final brokenRepo = Top10BrokenEditorialRepo();
    final brokenContainer = ProviderContainer(
      overrides: [
        aurisRepositoryProvider.overrideWithValue(brokenRepo),
        authProvider.overrideWith((ref) => MockAuthNotifier(UserAccount(id: userId, activeProfileId: userId))),
      ],
    );
    brokenContainer.read(homeCategoryProvider.notifier).state = 'animes';

    final layout = await brokenContainer.read(homeLayoutProvider.stream).firstWhere(
          (l) => l.any((s) => s.title == 'Sección personalizada') &&
              l.any((s) => s.presentation == SectionPresentation.top10),
        );

    final tops = layout.where((s) => s.presentation == SectionPresentation.top10).toList();
    expect(tops.length, 1, reason: 'Sin editorial no debe aparecer ninguna TOP10 extra');
    expect(tops.first.title, 'Top 10 Animes del Día');
    expect(tops.first.items.length, 3);

    brokenContainer.dispose();
  });
}

class Top10BrokenEditorialRepo extends Top10Repo {
  @override
  Future<EditorialResponse> getEditorial({String? imgSize, String? category, String? userId}) async =>
      const EditorialResponse(generatedAt: '', locale: '', sections: []);
}
