import 'package:flutter_test/flutter_test.dart';
import 'package:auris_web_desktop/core/utils/url_utils.dart';

/// Verifica el formato del token auto-contenido de `/watch/:token/:slug`:
/// - round-trip de los campos de reproducción nuevos (posiciones 7..19)
/// - compatibilidad con tokens antiguos de 7 campos
/// - query mínima (`episode` / `themes`)
void main() {
  group('encodeShareableToken / decodeShareableToken', () {
    test('round-trip de todos los campos de reproducción', () {
      final token = UrlUtils.encodeShareableToken(
        title: 'Yofukashi no Uta',
        source: 'Themes',
        url: 'https://v.animethemes.moe/YofukashiNoUta-ED1-NCBD1080.webm',
        category: 'anime',
        year: 2024,
        season: 1,
        episode: 'ED',
        serverName: 'Themes',
        episodeTitle: 'Daten',
        posterUrl: 'https://image.tmdb.org/t/p/w1280/poster.jpg',
        bannerUrl: 'https://image.tmdb.org/t/p/w1280/banner.jpg',
        logoUrl: 'https://image.tmdb.org/t/p/w300/logo.png',
        video720: 'https://v.animethemes.moe/YofukashiNoUta-ED1.webm',
        video1080: 'https://v.animethemes.moe/YofukashiNoUta-ED1-NCBD1080.webm',
        totalEpisodes: 1,
        certification: 'TV-14',
        contentId: 'yofukashi-no-uta',
        skipResume: true,
        isLive: false,
      );

      final payload = UrlUtils.decodeShareableToken(token);
      expect(payload, isNotNull);
      expect(payload!['title'], 'Yofukashi no Uta');
      expect(payload['source'], 'Themes');
      expect(payload['url'],
          'https://v.animethemes.moe/YofukashiNoUta-ED1-NCBD1080.webm');
      expect(payload['year'], 2024);
      expect(payload['season'], 1);
      expect(payload['episode'], 'ED');
      expect(payload['serverName'], 'Themes');
      expect(payload['episodeTitle'], 'Daten');
      expect(payload['posterUrl'], contains('poster.jpg'));
      expect(payload['bannerUrl'], contains('banner.jpg'));
      expect(payload['logoUrl'], contains('logo.png'));
      expect(payload['video720'], contains('ED1.webm'));
      expect(payload['video1080'], contains('NCBD1080.webm'));
      expect(payload['totalEpisodes'], '1');
      expect(payload['certification'], 'TV-14');
      expect(payload['contentId'], 'yofukashi-no-uta');
      expect(payload['skipResume'], true);
      expect(payload.containsKey('isLive'), isFalse);
    });

    test('token antiguo de 7 campos sigue decodificando', () {
      // Mismo empaquetado de antes de la extensión: 7 campos, sin recortar.
      final token = UrlUtils.encodeShareableToken(
        title: 'Naruto',
        source: 'JKAnime',
        url: 'https://jkanime.net/naruto/',
        category: 'anime',
      );

      final payload = UrlUtils.decodeShareableToken(token);
      expect(payload, isNotNull);
      expect(payload!['title'], 'Naruto');
      expect(payload['source'], 'JKAnime');
      expect(payload['url'], 'https://jkanime.net/naruto/');
      expect(payload['category'], 'anime');
      // Los campos nuevos no existen → el router cae a la query legacy.
      expect(payload.containsKey('episode'), isFalse);
      expect(payload.containsKey('contentId'), isFalse);
      expect(payload.containsKey('skipResume'), isFalse);
    });

    test('un valor con el delimitador interno no rompe el parseo', () {
      final token = UrlUtils.encodeShareableToken(
        title: 'Titulo\x1Fcon\x1Fseparadores',
        source: 'Themes',
        url: 'https://example.com/video.webm',
        episode: 'OP',
      );

      final payload = UrlUtils.decodeShareableToken(token);
      expect(payload, isNotNull);
      expect(payload!['episode'], 'OP');
      expect(payload['title'], isNot(contains('\x1F')));
    });

    test('los campos vacíos finales se recortan (token de ficha intacto)', () {
      final soloFicha = UrlUtils.encodeShareableToken(
        title: 'Jujutsu Kaisen',
        source: 'TMDB',
        url: 'tmdb://123',
        category: 'anime',
      );
      // Debe seguir siendo un token de 7 campos: sin datos de player no crece.
      final payload = UrlUtils.decodeShareableToken(soloFicha);
      expect(payload!['title'], 'Jujutsu Kaisen');
      expect(payload.containsKey('episode'), isFalse);
      expect(payload.containsKey('isLive'), isFalse);
    });
  });

  group('buildPlayerUri', () {
    test('query mínima con episode para contenido normal', () {
      final uri = UrlUtils.buildPlayerUri(
        title: 'Yofukashi no Uta',
        contentId: 'yofukashi-no-uta',
        episode: '5',
        source: 'JKAnime',
        url: 'https://jkanime.net/yofukashi/5',
        season: 1,
        serverName: 'JKAnime',
        category: 'anime',
        totalEpisodes: 13,
        posterUrl: 'https://image.tmdb.org/t/p/w1280/p.jpg',
        episodeTitle: 'Episodio 5',
        certification: 'TV-14',
        year: 2024,
      );

      final parsed = Uri.parse(uri);
      expect(parsed.queryParameters.keys.toList(), ['episode']);
      expect(parsed.queryParameters['episode'], '5');
      expect(parsed.path, contains('/watch/'));
      expect(parsed.path, endsWith('/yofukashi-no-uta'));

      // Todo viaja en el token.
      final token = parsed.pathSegments[1];
      final payload = UrlUtils.decodeShareableToken(token);
      expect(payload!['url'], 'https://jkanime.net/yofukashi/5');
      expect(payload['serverName'], 'JKAnime');
      expect(payload['episodeTitle'], 'Episodio 5');
      expect(payload['posterUrl'], contains('p.jpg'));
      expect(payload['totalEpisodes'], '13');
      expect(payload['certification'], 'TV-14');
      expect(payload['contentId'], 'yofukashi-no-uta');
      expect(payload['year'], 2024);
    });

    test('query usa themes= para OP/ED', () {
      final uri = UrlUtils.buildPlayerUri(
        title: 'Yofukashi no Uta',
        contentId: 'yofukashi-no-uta',
        episode: 'ED',
        source: 'Themes',
        url: 'https://v.animethemes.moe/YofukashiNoUta-ED1.webm',
        serverName: 'Themes',
        category: 'anime',
        episodeTitle: 'Daten',
        video720: 'https://v.animethemes.moe/YofukashiNoUta-ED1.webm',
        video1080: 'https://v.animethemes.moe/YofukashiNoUta-ED1-NCBD1080.webm',
      );

      final parsed = Uri.parse(uri);
      expect(parsed.queryParameters.keys.toList(), ['themes']);
      expect(parsed.queryParameters['themes'], 'ED');
      // Nada de URL del CDN ni source en la query.
      expect(parsed.query, isNot(contains('animethemes')));
      expect(parsed.query, isNot(contains('source')));

      final payload =
          UrlUtils.decodeShareableToken(parsed.pathSegments[1]);
      expect(payload!['episode'], 'ED');
      expect(payload['video720'], contains('ED1.webm'));
      expect(payload['video1080'], contains('NCBD1080.webm'));
    });

    test('OP usa themes=OP', () {
      final uri = UrlUtils.buildPlayerUri(
        title: 'Yofukashi no Uta',
        contentId: 'yofukashi-no-uta',
        episode: 'OP',
        source: 'Themes',
        url: 'https://v.animethemes.moe/YofukashiNoUta-OP1.webm',
      );
      final parsed = Uri.parse(uri);
      expect(parsed.queryParameters, {'themes': 'OP'});
    });
  });
}
