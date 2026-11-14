import 'package:auris_core/auris_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Payload real de `GET /api/search/anime?q=Ranma&stream=1` (count: 13).
/// El bug: `_fuseKey` quitaba `ova|special|oav` del título, así que
/// `"Ranma ½ OVA"` y `"Ranma ½"` (1989) caían en la misma clave y el frontend
/// mostraba 12 resultados en vez de 13.
const List<Map<String, Object?>> ranmaPayload = [
  {
    'title': 'Ranma ½ (2024) 3rd Season',
    'slug': 'ranma-2024-3rd-season',
    'year': 2024,
    'kind': 'anime'
  },
  {
    'title': 'Ranma ½ (2024) 2nd Season',
    'slug': 'ranma-2024-2nd-season',
    'year': 2024,
    'kind': 'anime'
  },
  {
    'title': 'Ranma ½ (2024)',
    'slug': 'ranma-2024',
    'year': 2024,
    'kind': 'anime'
  },
  {
    'title': 'Ranma ½ Super',
    'slug': 'ranma-super',
    'year': null,
    'kind': 'anime'
  },
  {
    'title': 'Ranma ½: Yomigaeru Kioku',
    'slug': 'ranma-yomigaeru-kioku',
    'year': null,
    'kind': 'anime'
  },
  {
    'title': 'Ranma ½: Chou Musabetsu Kessen! Ranma Team vs. Densetsu no Houou',
    'slug': 'ranma-chou-musabetsu-kessen-ranma-team-vs-densetsu-no-houou',
    'year': null,
    'kind': 'movie_anime',
  },
  {'title': 'Ranma ½ OVA', 'slug': 'ranma-ova', 'year': null, 'kind': 'anime'},
  {
    'title': 'Ranma ½: Kessen Tougenkyou! Hanayome wo Torimodose!',
    'slug': 'ranma-kessen-tougenkyou-hanayome-wo-torimodose',
    'year': null,
    'kind': 'movie_anime',
  },
  {
    'title':
        'Ranma ½: Chuugoku Nekonron Daikessen! Okite Yaburi no Gekitou-hen!!',
    'slug': 'ranma-chuugoku-nekonron-daikessen-okite-yaburi-no-gekitou-hen',
    'year': null,
    'kind': 'movie_anime',
  },
  {'title': 'Ranma ½', 'slug': 'ranma', 'year': 1989, 'kind': 'anime'},
  {
    'title': 'Fairy Ranmaru: Anata no Kokoro Otasuke Shimasu',
    'slug': 'fairy-ranmaru',
    'year': 2021,
    'kind': 'anime'
  },
  {
    'title': 'Appare-Ranman!',
    'slug': 'appare-ranman',
    'year': 2020,
    'kind': 'anime'
  },
  {'title': 'Neo Ranga', 'slug': 'neo-ranga', 'year': null, 'kind': 'anime'},
];

SearchResult _result(
  String title, {
  int? year,
  String? slug,
  String kind = 'anime',
  String url = '',
  String thumbnail = '',
  String banner = '',
  double? progress,
  List<SourceItem> sources = const [],
}) {
  final String resolvedSlug =
      slug ?? title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return SearchResult(
    title: title,
    url: url.isNotEmpty ? url : 'https://animeav1.com/media/$resolvedSlug',
    quality: 'ANIME – Sub Español',
    thumbnail: thumbnail,
    banner: banner,
    source: 'AnimeAV1',
    year: year,
    slug: resolvedSlug,
    kind: kind,
    progress: progress,
    sources: sources,
  );
}

List<SearchResult> _ranmaResults() => [
      for (final item in ranmaPayload)
        _result(
          item['title'] as String,
          year: item['year'] as int?,
          slug: item['slug'] as String,
          kind: item['kind'] as String,
        ),
    ];

void main() {
  test('búsqueda "Ranma": los 13 resultados del servidor se mantienen', () {
    final results = _ranmaResults();

    expect(results, hasLength(13));
    expect(
      deduplicateSearchResults(results),
      hasLength(13),
      reason: '"Ranma ½ OVA" y "Ranma ½" (1989) son obras distintas y no '
          'deben fusionarse (antes quedaban 12)',
    );
  });

  test('la misma obra con el título en español/inglés sí se fusiona', () {
    final en = _result(
      'Kimi no Na wa',
      kind: 'movie',
      year: 2016,
      url: 'https://a/kimi',
      sources: [
        const SourceItem(source: 'A', url: 'https://a/kimi', quality: '')
      ],
    );
    final es = _result(
      'Kimi no Na wa película',
      kind: 'movie',
      url: 'https://b/kimi',
      sources: [
        const SourceItem(source: 'B', url: 'https://b/kimi', quality: '')
      ],
    );

    final merged = deduplicateSearchResults([en, es]);

    expect(merged, hasLength(1));
    expect(merged.single.sources.map((s) => s.source), containsAll(['A', 'B']));
    expect(merged.single.year, 2016,
        reason: 'se conserva el año del que lo trae');
  });

  test('mismo título pero año distinto: son dos obras (remake vs original)',
      () {
    final original = _result('Ranma ½', year: 1989, url: 'https://a/ranma');
    final remake = _result('Ranma ½', year: 2024, url: 'https://a/ranma-2024');

    expect(deduplicateSearchResults([original, remake]), hasLength(2));
  });

  test('mismo título y mismo año (duplicado entre fuentes) sí se fusiona', () {
    final a = _result(
      'Yu-Gi-Oh! Zexal',
      year: 2011,
      url: 'https://a/zexal',
      sources: [
        const SourceItem(source: 'A', url: 'https://a/zexal', quality: '')
      ],
    );
    final b = _result(
      'Yu-Gi-Oh! Zexal',
      year: 2011,
      url: 'https://b/zexal',
      sources: [
        const SourceItem(source: 'B', url: 'https://b/zexal', quality: '')
      ],
    );

    final merged = deduplicateSearchResults([a, b]);

    expect(merged, hasLength(1));
    expect(merged.single.sources, hasLength(2));
  });

  test(
      'al fusionar no se pierden metadatos (progreso del historial + póster remoto)',
      () {
    final remote = _result('Ranma ½',
        year: 1989, url: 'https://a/ranma', thumbnail: 'poster.jpg');
    final history = _result('Ranma ½', url: 'https://a/ranma', progress: 0.42);

    final merged = fuseSearchResults(history, remote);

    expect(merged.thumbnail, 'poster.jpg');
    expect(merged.progress, 0.42);
    expect(merged.year, 1989);
  });
}
