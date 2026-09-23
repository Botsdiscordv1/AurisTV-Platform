import 'package:flutter_test/flutter_test.dart';
import 'package:auris_core/auris_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive.dart';
import 'package:dio/dio.dart';
import 'dart:io';

class MockPersonalizedRepo implements AurisRepository {
  final Map<String, HomeResponse> responses = {};

  @override
  Future<HomeResponse> getUserHome({required String userId, String? category}) async {
    return responses[userId] ?? HomeResponse(userId: userId, maturityLevel: 'cold', sections: [], generatedAt: '');
  }

  @override
  Future<SearchResponse> filter({String? genre, int? year, String? category, String? status, String? idioma, int page = 1, String? source}) async => SearchResponse(results: [], query: '', category: category ?? '', count: 0);

  // Stubs
  @override Future<int> getHomeVersion({String? category}) async => 0;
  @override Future<void> sendUserEvent({required String userId, required String animeId, required String event, String? sectionId}) async {}
  @override Future<SearchResponse> search(String category, String query, {int? year, String? server, String? phase, String? imgSize, int page = 1, CancelToken? cancelToken}) async => SearchResponse(results: [], query: query, category: category, count: 0);
  @override Stream<SearchResponse> searchStream(String category, String query, {int? year, String? server, String? phase, String? imgSize, CancelToken? cancelToken}) async* {}
  @override Future<SearchResponse> searchAnimeVariants({required String q, String? display, String? english, String? native_, String? collapsed, List<String>? synonyms}) async => SearchResponse(results: [], query: q, category: 'anime', count: 0);
  @override Future<AnimeDetail?> getAnimeDetail({required String title, int? malId, String? metadataTitle, int? year, int? season, String? kind, String? url, String? type, String? server, String? imgSize}) async => null;
  @override Future<MovieDetail?> getMovieDetail({required String title, int? year, String? metadataTitle, String? url, String? type, String category = 'movie', String? server, String? kind, String? imgSize}) async => null;
  @override Future<List<MediaItem>> getHomeHero({String category = 'anime', String? imgSize}) async => [];
  @override Future<ScheduleResponse> getSchedule() async => const ScheduleResponse(days: [], season: '1', year: 2026, total: 0);
  @override Future<List<SourceInfo>> getSources() async => [];
  @override Future<EditorialResponse> getEditorial({String? imgSize, String? category, String? userId}) async => const EditorialResponse(generatedAt: '', locale: '', sections: []);
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
  late MockPersonalizedRepo mockRepo;
  late ProviderContainer container;

  setUp(() async {
    mockRepo = MockPersonalizedRepo();
    final tempDir = Directory.systemTemp.createTempSync();
    Hive.init(tempDir.path);
    await Hive.openBox('home_cache');

    container = ProviderContainer(
      overrides: [
        aurisRepositoryProvider.overrideWithValue(mockRepo),
        authProvider.overrideWith((ref) => MockAuthNotifier(null)),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('homeLayoutProvider — Cache isolated by userId', () async {
    const userIdA = 'user_A';
    const userIdB = 'user_B';

    mockRepo.responses[userIdA] = HomeResponse(
      userId: userIdA, 
      maturityLevel: 'personalized', 
      sections: [
        const HomeSection(id: 'sec_A', title: 'Para A', strategy: 's', type: 'recommendation', priority: 1, items: [
          HomeItem(id: 'item_A', title: 'Contenido A')
        ])
      ], 
      generatedAt: ''
    );

    mockRepo.responses[userIdB] = HomeResponse(
      userId: userIdB, 
      maturityLevel: 'personalized', 
      sections: [
        const HomeSection(id: 'sec_B', title: 'Para B', strategy: 's', type: 'recommendation', priority: 1, items: [
          HomeItem(id: 'item_B', title: 'Contenido B')
        ])
      ], 
      generatedAt: ''
    );

    // 1. Cargar para Usuario A
    container.read(authProvider.notifier).state = UserAccount(id: userIdA, activeProfileId: userIdA);
    final layoutA = await container.read(homeLayoutProvider.stream).firstWhere((l) => l.any((s) => s.title == 'Para A'));
    expect(layoutA.any((s) => s.title == 'Para A'), isTrue);

    // 2. Cambiar a Usuario B
    container.read(authProvider.notifier).state = UserAccount(id: userIdB, activeProfileId: userIdB);
    final layoutB = await container.read(homeLayoutProvider.stream).firstWhere((l) => l.any((s) => s.title == 'Para B'));
    expect(layoutB.any((s) => s.title == 'Para B'), isTrue);

    // 3. Verificar que el cache no se mezcla (Leyendo directamente de Hive)
    final box = Hive.box('home_cache');
    final cacheA = box.get('personalized_home_${userIdA}_inicio');
    final cacheB = box.get('personalized_home_${userIdB}_inicio');

    expect(cacheA['userId'], userIdA);
    expect(cacheB['userId'], userIdB);
  });

  test('homeLayoutProvider — Fallback to editorial on error', () async {
    final containerError = ProviderContainer(
      overrides: [
        aurisRepositoryProvider.overrideWithValue(ErrorRepo()),
        authProvider.overrideWith((ref) => MockAuthNotifier(UserAccount(id: 'err', activeProfileId: 'err'))),
      ],
    );

    final layout = await containerError.read(homeLayoutProvider.stream).firstWhere((l) => l.any((s) => s.title == 'Recién añadido a AurisTV'));
    
    final titles = layout.map((s) => s.title).toList();
    expect(titles, contains('Recién añadido a AurisTV'));
  });

  test('homeLayoutProvider — Respects dynamic format (SDUI)', () async {
    const userId = 'user_sdui';
    container.read(authProvider.notifier).state = UserAccount(id: userId, activeProfileId: userId);

    mockRepo.responses[userId] = HomeResponse(
      userId: userId, 
      maturityLevel: 'personalized', 
      sections: [
        const HomeSection(
          id: 'sec_1', 
          title: 'Section Forced Wide', 
          strategy: 's', 
          type: 'editorial', 
          priority: 1, 
          format: 'wide',
          items: [
            HomeItem(id: '1', title: 'T1', backdropUrl: 'b1')
          ]
        ),
        const HomeSection(
          id: 'sec_2', 
          title: 'Section Forced Top10', 
          strategy: 's', 
          type: 'editorial', 
          priority: 2, 
          format: 'top10',
          items: [
            HomeItem(id: '2', title: 'T2')
          ]
        )
      ], 
      generatedAt: ''
    );

    final layout = await container.read(homeLayoutProvider.stream).firstWhere((l) => l.any((s) => s.title == 'Section Forced Wide'));

    final wideSection = layout.firstWhere((s) => s.title == 'Section Forced Wide');
    final top10Section = layout.firstWhere((s) => s.title == 'Section Forced Top10');

    expect(wideSection.presentation, SectionPresentation.wide);
    expect(top10Section.presentation, SectionPresentation.top10);
  });

  test('homeLayoutProvider — Inicio mirrors and interleaves sections from all 4 categories', () async {
    final multiRepo = MultiCategoryRepo();
    final containerMulti = ProviderContainer(
      overrides: [
        aurisRepositoryProvider.overrideWithValue(multiRepo),
        authProvider.overrideWith((ref) => MockAuthNotifier(UserAccount(id: 'multi_user', activeProfileId: 'multi_user'))),
      ],
    );

    final layout = await containerMulti.read(homeLayoutProvider.stream).firstWhere(
      (l) => l.any((s) => s.title.contains('películas') || s.title.contains('series') || s.title.contains('animes') || s.title.contains('kdrama')),
    );

    final titles = layout.map((s) => s.title).toList();
    expect(titles.any((t) => t.contains('películas')), isTrue);
    expect(titles.any((t) => t.contains('series')), isTrue);
    expect(titles.any((t) => t.contains('animes')), isTrue);
    expect(titles.any((t) => t.contains('kdrama')), isTrue);
  });

  test('homeLayoutProvider — Format harmony prevents contiguous wide or top10 sections', () async {
    final harmonyRepo = HarmonyRepo();
    final containerHarmony = ProviderContainer(
      overrides: [
        aurisRepositoryProvider.overrideWithValue(harmonyRepo),
        authProvider.overrideWith((ref) => MockAuthNotifier(UserAccount(id: 'harmony_user', activeProfileId: 'harmony_user'))),
      ],
    );

    final layout = await containerHarmony.read(homeLayoutProvider.stream).firstWhere((l) => l.length >= 4);

    for (int i = 0; i < layout.length - 1; i++) {
      final current = layout[i].presentation;
      final next = layout[i + 1].presentation;
      if (current == SectionPresentation.top10) {
        expect(next, isNot(SectionPresentation.top10), reason: 'Contiguous top10 at $i and ${i + 1}');
      }
      if (current == SectionPresentation.wide) {
        expect(next, isNot(SectionPresentation.wide), reason: 'Contiguous wide at $i and ${i + 1}');
      }
    }
  });

  test('HomeSection.fromJson supports all SDUI format aliases', () {
    final aliases = ['layout', 'carousel', 'displayMode', 'carouselType'];
    
    for (final alias in aliases) {
      final json = {
        'id': 'sec_1',
        'title': 'Test',
        'strategy': 's',
        'type': 't',
        'priority': 1,
        alias: 'wide',
        'items': []
      };
      
      final section = HomeSection.fromJson(json);
      expect(section.format, 'wide', reason: 'Failed for alias: $alias');
    }
  });
}

class ErrorRepo extends MockPersonalizedRepo {
  @override
  Future<HomeResponse> getUserHome({required String userId, String? category}) async {
    throw Exception("Backend Down");
  }

  @override
  Future<EditorialResponse> getEditorial({String? imgSize, String? category, String? userId}) async {
    return const EditorialResponse(
      generatedAt: '2026-03-30T12:00:00Z',
      locale: 'es-MX',
      sections: [
        EditorialSection(
          id: 'recent',
          title: 'Recién añadido a AurisTV',
          badge: 'essential',
          format: 'poster',
          items: [
            EditorialItem(id: 'item_1', title: 'Test Anime', posterUrl: 'url', badge: 'essential')
          ],
        )
      ],
    );
  }
}

class MultiCategoryRepo extends MockPersonalizedRepo {
  @override
  Future<EditorialResponse> getEditorial({String? imgSize, String? category, String? userId}) async {
    final cat = category ?? 'animes';
    return EditorialResponse(
      generatedAt: '2026-03-30T12:00:00Z',
      locale: 'es-MX',
      sections: [
        EditorialSection(
          id: 'sec_$cat',
          title: 'Sección $cat',
          badge: 'essential',
          format: 'poster',
          items: [
            EditorialItem(id: 'item_$cat', title: 'Item $cat', posterUrl: 'url_$cat', badge: 'essential')
          ],
        )
      ],
    );
  }
}

class HarmonyRepo extends MockPersonalizedRepo {
  @override
  Future<EditorialResponse> getEditorial({String? imgSize, String? category, String? userId}) async {
    final cat = category ?? 'animes';
    return EditorialResponse(
      generatedAt: '2026-03-30T12:00:00Z',
      locale: 'es-MX',
      sections: [
        EditorialSection(
          id: 'sec_top10_$cat',
          title: 'Top 10 $cat',
          badge: 'essential',
          format: 'top10',
          items: [
            EditorialItem(id: 'item_1_$cat', title: 'T1', posterUrl: 'u', badge: 'essential')
          ],
        ),
        EditorialSection(
          id: 'sec_wide_$cat',
          title: 'Estrenos $cat',
          badge: 'essential',
          format: 'wide',
          items: [
            EditorialItem(id: 'item_2_$cat', title: 'T2', posterUrl: 'u', bannerUrl: 'b', badge: 'essential')
          ],
        ),
        EditorialSection(
          id: 'sec_poster_$cat',
          title: 'Explora $cat',
          badge: 'essential',
          format: 'poster',
          items: [
            EditorialItem(id: 'item_3_$cat', title: 'T3', posterUrl: 'u', badge: 'essential')
          ],
        ),
      ],
    );
  }
}
