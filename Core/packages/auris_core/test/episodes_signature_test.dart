import 'package:auris_core/data/providers/content_providers.dart';
import 'package:flutter_test/flutter_test.dart';

GroupedEpisodesParams _p({String url = 'https://a.com/x', int? season = 1}) =>
    GroupedEpisodesParams(
      title: 'T',
      category: 'anime',
      season: season,
      familyKey: 'animeav1',
      currentSourceUrl: url,
      sourcesSignature: episodesSignature(url, season),
      source: 'AnimeAV1',
    );

void main() {
  group('episodesSignature', () {
    test('estable ante crecimiento de descubiertas (misma seleccion)', () {
      // La firma NO incluye la lista: N chunks -> misma firma -> sin refire.
      expect(episodesSignature('https://a.com/x', 1),
          episodesSignature('https://a.com/x', 1));
    });
    test('cambia con fuente o temporada', () {
      expect(episodesSignature('https://a.com/x', 1) == episodesSignature('https://a.com/y', 1), false);
      expect(episodesSignature('https://a.com/x', 1) == episodesSignature('https://a.com/x', 2), false);
    });
  });

  group('GroupedEpisodesParams', () {
    test('igualdad ignora lista externa (solo firma)', () {
      expect(_p(), _p());
    });
    test('firma distinta distingue params', () {
      expect(
          _p().copyWithForTest('https://a.com/x|2') == _p(),
          false);
    });
    test('source real viaja en params', () {
      expect(_p().source, 'AnimeAV1');
    });
  });
}

extension on GroupedEpisodesParams {
  GroupedEpisodesParams copyWithForTest(String sig) => GroupedEpisodesParams(
        title: title,
        metadataTitle: metadataTitle,
        category: category,
        year: year,
        season: season,
        tmdbId: tmdbId,
        familyKey: familyKey,
        currentSourceUrl: currentSourceUrl,
        sourcesSignature: sig,
        source: source,
      );
}
