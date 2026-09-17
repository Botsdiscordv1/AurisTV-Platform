import 'package:auris_core/data/models/server/movie_detail.dart';
import 'package:auris_core/data/models/server/anime_detail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MovieDetail genres', () {
    test('prefiere genresTranslated cuando existe', () {
      final d = MovieDetail.fromJson({
        'tmdbId': '129',
        'title': 'El viaje de Chihiro',
        'genres': ['Animacion', 'Familia', 'Fantasia'],
        'genresTranslated': ['Animacion', 'Familia', 'Fantasia', 'Brujas', 'Magia'],
      });
      expect(d.genres, ['Animacion', 'Familia', 'Fantasia', 'Brujas', 'Magia']);
    });

    test('fallback a genres si no hay genresTranslated (respuestas viejas)', () {
      final d = MovieDetail.fromJson({
        'tmdbId': '129',
        'title': 'El viaje de Chihiro',
        'genres': ['Animación', 'Familia'],
      });
      expect(d.genres, ['Animación', 'Familia']);
    });

    test('lista vacía si no hay ninguno', () {
      final d = MovieDetail.fromJson({'tmdbId': '129', 'title': 'X'});
      expect(d.genres, isEmpty);
    });

    test('acepta envelope data (respuesta API real)', () {
      final d = MovieDetail.fromJson({
        'success': true,
        'data': {
          'tmdbId': '129',
          'title': 'El viaje de Chihiro',
          'genresTranslated': ['Animacion', 'Brujas'],
        },
      });
      expect(d.genres, ['Animacion', 'Brujas']);
    });
  });

  group('AnimeDetail genres', () {
    test('prefiere genresTranslated dentro de anime', () {
      final d = AnimeDetail.fromJson({
        'anime': {'id': '21', 'title': 'Jujutsu Kaisen', 'genres': ['Accion'],
          'genresTranslated': ['Accion', 'Sobrenatural', 'Demonios', 'Maldiciones']},
        'visuals': {'genres': ['Animacion']},
      });
      expect(d.genres, ['Accion', 'Sobrenatural', 'Demonios', 'Maldiciones']);
    });

    test('compat con genresTranslated a nivel root', () {
      final d = AnimeDetail.fromJson({
        'anime': {'id': '21', 'title': 'Jujutsu Kaisen', 'genres': ['Accion']},
        'genresTranslated': ['Accion', 'Sobrenatural'],
      });
      expect(d.genres, ['Accion', 'Sobrenatural']);
    });

    test('fallback al merge legacy sin genresTranslated', () {
      final d = AnimeDetail.fromJson({
        'genres': ['Animacion'],
        'anime': {'id': '21', 'title': 'Jujutsu Kaisen', 'genres': ['Accion']},
      });
      expect(d.genres, containsAll(['Accion', 'Animacion']));
    });
  });
}
