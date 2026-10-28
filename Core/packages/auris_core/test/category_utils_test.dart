import 'package:flutter_test/flutter_test.dart';
import 'package:auris_core/core/utils/category_utils.dart';
import 'package:auris_core/core/utils/content_logic.dart';
import 'package:auris_core/core/utils/source_utils.dart';
import 'package:auris_core/data/providers/library_providers.dart';
import 'package:auris_core/data/models/playback_history.dart';
import 'package:auris_core/data/models/server/search_result.dart';
import 'package:auris_core/data/models/server/episodes_response.dart';

void main() {
  group('isMovieLike - Series con episodio de +50 min', () {
    test('Series con episodio de 55 min NO debe categorizarse como película', () {
      final isMovie = isMovieLike('series', 'Game of Thrones', 55 * 60 * 1000);
      expect(isMovie, false);
    });

    test('Series Western con episodio de 75 min NO debe categorizarse como película', () {
      final isMovie = isMovieLike('series_western', 'Stranger Things', 75 * 60 * 1000);
      expect(isMovie, false);
    });

    test('Kdrama con episodio de 80 min NO debe categorizarse como película', () {
      final isMovie = isMovieLike('kdrama', 'Crash Landing on You', 80 * 60 * 1000);
      expect(isMovie, false);
    });

    test('Anime de TV con episodio especial de 45 min NO debe categorizarse como película', () {
      final isMovie = isMovieLike('anime', 'Attack on Titan Special', 45 * 60 * 1000);
      expect(isMovie, false);
    });

    test('Película explícita de 120 min SÍ debe categorizarse como película', () {
      final isMovie = isMovieLike('movie', 'Inception', 120 * 60 * 1000);
      expect(isMovie, true);
    });

    test('Película de anime explícita SÍ debe categorizarse como película', () {
      final isMovie = isMovieLike('movie_anime', 'Kimi no Na wa', 106 * 60 * 1000);
      expect(isMovie, true);
    });

    test('Sin categoría pero con "Ep 1" y 55 min NO debe ser película', () {
      final isMovie = isMovieLike(null, 'Ep 1 - Piloto', 55 * 60 * 1000);
      expect(isMovie, false);
    });

    test('Sin categoría y sin título de episodio con 120 min SÍ es película', () {
      final isMovie = isMovieLike(null, 'Oppenheimer', 180 * 60 * 1000);
      expect(isMovie, true);
    });
  });

  group('continueCardSubtitle para series de +50 min', () {
    test('Mantiene subtítulo T1:E1 para episodios largos de serie', () {
      final history = PlaybackHistory(
        contentId: 'series_123',
        season: 1,
        episode: '1',
        positionInMilliseconds: 10 * 60 * 1000,
        durationInMilliseconds: 55 * 60 * 1000,
        updatedAt: DateTime.now(),
        title: 'Serie Larga',
        category: 'series',
        episodeTitle: 'Capítulo Inicial',
      );

      final subtitle = continueCardSubtitle(history);
      expect(subtitle.line1, 'T1:E1 · Capítulo Inicial');
      expect(subtitle.line2, contains('Quedan:'));
    });
  });

  group('inferOpenCategory e isMovieLike para Tudorama / KDramas', () {
    test('Infiere kdrama cuando kind es Dorama', () {
      final result = SearchResult(
        title: 'Dorama Test',
        url: 'https://tudorama.net/dorama/test',
        quality: 'HD',
        thumbnail: '',
        source: 'Tudorama',
        kind: 'Dorama',
        type: 'Series',
      );

      final category = inferOpenCategory(result);
      expect(category, 'kdrama');
    });

    test('Infiere movie_dorama e isMovieLike cuando kind es movie_dorama', () {
      final result = SearchResult(
        title: 'Pelicula Dorama Test',
        url: 'https://tudorama.net/movie/test',
        quality: 'HD',
        thumbnail: '',
        source: 'Tudorama',
        kind: 'movie_dorama',
        type: 'Movie',
      );

      final category = inferOpenCategory(result);
      expect(category, 'movie_dorama');
      expect(isMovieLike(category, result.title, 110 * 60 * 1000), true);
    });
  });

  group('cleanSeriesUrl e isEpisodeUrl', () {
    test('Convierte URL de episodio OnlyPelis a URL de serie', () {
      const epUrl = 'https://onlypelis.com/episodios/it-bienvenidos-a-derry-1x1/';
      expect(isEpisodeUrl(epUrl), true);
      expect(cleanSeriesUrl(epUrl), 'https://onlypelis.com/serie/it-bienvenidos-a-derry/');
    });

    test('Convierte URL de episodio GnulaHD a URL de serie', () {
      const epUrl = 'https://gnulahd.nu/episodio/it-bienvenidos-a-derry-1x1/';
      expect(isEpisodeUrl(epUrl), true);
      expect(cleanSeriesUrl(epUrl), 'https://gnulahd.nu/serie/it-bienvenidos-a-derry/');
    });

    test('No modifica URL de serie ya canónica', () {
      const seriesUrl = 'https://onlypelis.com/serie/it-bienvenidos-a-derry/';
      expect(isEpisodeUrl(seriesUrl), false);
      expect(cleanSeriesUrl(seriesUrl), seriesUrl);
    });

    test('historyToSeed limpia URL de episodio enviando la URL de serie', () {
      final history = PlaybackHistory(
        contentId: 'IT: Bienvenidos a Derry',
        season: 1,
        episode: '1',
        positionInMilliseconds: 60000,
        durationInMilliseconds: 3000000,
        updatedAt: DateTime.now(),
        title: 'IT: Bienvenidos a Derry',
        category: 'series',
        source: 'OnlyPelis',
        url: 'https://onlypelis.com/episodios/it-bienvenidos-a-derry-1x1/',
      );

      final seed = historyToSeed(history);
      expect(seed?.url, 'https://onlypelis.com/serie/it-bienvenidos-a-derry/');
      expect(seed?.kind, 'series');
    });
  });

  group('totalSeasons de SearchResult y EpisodesResponse', () {
    test('SearchResult almacena y expone totalSeasons', () {
      final result = SearchResult(
        title: 'Serie Con 3 Temporadas',
        url: 'https://onlypelis.com/serie/test/',
        quality: 'HD',
        thumbnail: '',
        source: 'OnlyPelis',
        totalSeasons: 3,
      );

      expect(result.totalSeasons, 3);
    });

    test('EpisodesResponse lee totalSeasons y seasons del JSON de /api/episodes', () {
      final json = {
        'source': 'DoramasMP4',
        'url': 'https://doramasmp4.io/doramas/squid-game',
        'slug': 'squid-game',
        'total': 21,
        'totalSeasons': 3,
        'seasons': [
          {'number': 1, 'episodeCount': 9},
          {'number': 2, 'episodeCount': 7},
          {'number': 3, 'episodeCount': 6},
        ],
        'episodes': [],
      };

      final response = EpisodesResponse.fromJson(json);
      expect(response.totalSeasons, 3);
      expect(response.seasons.length, 3);
      expect(response.seasons.first.number, 1);
      expect(response.seasons.first.episodeCount, 9);
      expect(response.seasons.last.number, 3);
      expect(response.seasons.last.episodeCount, 6);
    });
  });

  group('simplifySourceName para Cuevana', () {
    test('Simplifica Cuevana a CVN', () {
      expect(simplifySourceName('cuevana'), 'CVN');
      expect(simplifySourceName('Cuevana'), 'CVN');
      expect(simplifySourceName('CUEVANA'), 'CVN');
    });
  });

  group('simplifySourceName para DoramasMP4', () {
    test('Simplifica DoramasMP4 a DM4', () {
      expect(simplifySourceName('doramasmp4'), 'DM4');
      expect(simplifySourceName('DoramasMP4'), 'DM4');
      expect(simplifySourceName('DORAMASMP4'), 'DM4');
    });
  });

  group('simplifySourceName para Tudorama', () {
    test('Simplifica Tudorama a TDM', () {
      expect(simplifySourceName('tudorama'), 'TDM');
      expect(simplifySourceName('TuDorama'), 'TDM');
      expect(simplifySourceName('TUDORAMA'), 'TDM');
    });
  });
}
