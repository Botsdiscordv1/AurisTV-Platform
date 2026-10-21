import 'dart:io';

import 'package:auris_core/core/api/providers.dart';
import 'package:auris_core/data/models/server/episodes_response.dart';
import 'package:auris_core/data/providers/community_translation_provider.dart';
import 'package:auris_core/data/providers/unified_content_notifier.dart';
import 'package:auris_core/data/repositories/auris_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

const _promo = 'Disfruta del capitulo 1 de La chispa del amor con subtítulos '
    'y con doblaje al Español Latino. Elige uno de los servidores que están '
    'disponibles y navega fácilmente entre los episodios';
const _full = 'Na Bo-bae is a struggling writer — and human electrical '
    'conductor. She meets a man who changes her life.';

class _FakeRepo implements AurisRepository {
  _FakeRepo({required this.fast, required this.full});

  final EpisodesResponse fast;
  final EpisodesResponse full;

  @override
  Future<EpisodesResponse> getEpisodes(
    String url,
    String source, {
    String? category,
    String? title,
    String? fullTitle,
    String? altTitle,
    int? tmdbId,
    int? season,
    int? year,
    bool fast = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return fast ? this.fast : this.full;
  }

  @override
  Future<List<CastInfo>> getCast(
    String url, {
    String? source,
    String? category,
    int? tmdbId,
    String? mediaType,
    String? title,
    int? year,
  }) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopTranslations extends CommunityTranslationManager {
  _NoopTranslations(super.ref);

  @override
  Future<({String? title, String? overview})?> processEpisodeTranslation({
    required int? tmdbId,
    required int? season,
    required EpisodeInfo episode,
    String? baseUrl,
  }) async =>
      null;
}

EpisodeInfo _ep({
  required String title,
  required String description,
  required bool needsTranslation,
}) =>
    EpisodeInfo(
      number: 1,
      id: 1,
      url: 'https://example/ep1',
      title: title,
      thumbnail: 'https://example/1.jpg',
      description: description,
      airDate: '2026-10-09',
      needsTranslation: needsTranslation,
    );

EpisodesResponse _res(EpisodeInfo ep) => EpisodesResponse(
      source: 'Tudorama',
      url: 'https://tudorama.com/serie/la-chispa-del-amor/',
      slug: 'la-chispa-del-amor',
      total: 1,
      episodes: [ep],
      tmdbId: 289423,
      season: 1,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('auris_hive_');
    Hive.init(tempDir.path);
    await Hive.openBox('community_translations_cache');
  });

  tearDown(() async {
    await Hive.close();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  Future<String?> mergedDescription({
    required bool fastNeedsTranslation,
    bool seedPromoCache = false,
  }) async {
    final box = Hive.box('community_translations_cache');
    await box.clear();
    if (seedPromoCache) {
      await box.put('sent_289423_1_1', {
        'title': 'Episodio 1',
        'overview': '$_promo ',
      });
    }

    final params = ProgressiveParams(
      url: 'https://tudorama.com/serie/la-chispa-del-amor/',
      source: 'Tudorama',
      category: 'kdrama',
      title: 'La chispa del amor',
      metadataTitle: 'La chispa del amor',
      season: 1,
      year: 2026,
      tmdbId: 289423,
    );

    final container = ProviderContainer(overrides: [
      aurisRepositoryProvider.overrideWithValue(_FakeRepo(
        fast: _res(_ep(
          title: 'Episodio 1',
          description: _promo,
          needsTranslation: fastNeedsTranslation,
        )),
        full: _res(_ep(
          title: 'Episode 1',
          description: _full,
          needsTranslation: true,
        )),
      )),
      communityTranslationManagerProvider
          .overrideWith((ref) => _NoopTranslations(ref)),
    ]);
    addTearDown(container.dispose);

    final sub = container.listen(progressiveContentProvider(params), (_, __) {});
    addTearDown(sub.close);

    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (DateTime.now().isBefore(deadline)) {
      final episodes = container
          .read(progressiveContentProvider(params))
          .episodes
          .valueOrNull
          ?.response
          .episodes;
      if (episodes != null &&
          episodes.isNotEmpty &&
          episodes.first.title == 'Episode 1') {
        return episodes.first.description;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return container
        .read(progressiveContentProvider(params))
        .episodes
        .valueOrNull
        ?.response
        .episodes
        .first
        .description;
  }

  test('full synopsis replaces fast promo', () async {
    expect(
      await mergedDescription(fastNeedsTranslation: true),
      _full,
    );
  });

  test('fast wrongly marked as ES still yields to full synopsis', () async {
    expect(
      await mergedDescription(fastNeedsTranslation: false),
      _full,
    );
  });

  test('poisoned promo cache does not override full synopsis', () async {
    expect(
      await mergedDescription(
        fastNeedsTranslation: true,
        seedPromoCache: true,
      ),
      _full,
    );
  });
}
