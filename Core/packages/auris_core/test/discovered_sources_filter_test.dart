import 'package:auris_core/core/utils/content_logic.dart';
import 'package:auris_core/data/models/server/search_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('discoveredSources filters', () {
    test('isListingUrl detecta URLs de catálogo y listado', () {
      expect(isListingUrl('https://onlypelis.com/pelicula/?orden=semana'), isTrue);
      expect(isListingUrl('https://onlypelis.com/pelicula/'), isTrue);
      expect(isListingUrl('https://onlypelis.com/serie/'), isTrue);
      expect(isListingUrl('https://onlypelis.com/genero/accion'), isTrue);
      expect(isListingUrl('https://onlypelis.com/serie/?page=2'), isTrue);
      
      // URLs legítimas de contenido
      expect(isListingUrl('https://onlypelis.com/serie/doctor-x-mafia-in-white/'), isFalse);
      expect(isListingUrl('https://onlypelis.com/pelicula/interstellar-2014/'), isFalse);
      expect(isListingUrl('https://repelishd.pics/serie/doctor-x/'), isFalse);
    });

    test('isNavTitle detecta enlaces de navegación', () {
      expect(isNavTitle('Más vistas'), isTrue);
      expect(isNavTitle('mas vistas'), isTrue);
      expect(isNavTitle('Lo más visto'), isTrue);
      expect(isNavTitle('Películas'), isTrue);
      expect(isNavTitle('Series'), isTrue);
      expect(isNavTitle('Populares'), isTrue);
      expect(isNavTitle('Estrenos'), isTrue);
      
      // Títulos legítimos
      expect(isNavTitle('Doctor X: Mafia in White'), isFalse);
      expect(isNavTitle('The Good Doctor'), isFalse);
      expect(isNavTitle('House'), isFalse);
    });

    test('isTitleCompatible compara títulos correctamente', () {
      const target = 'Doctor X: Mafia in White';
      
      // Coincidencias válidas
      expect(isTitleCompatible(target, 'Doctor X: Mafia in White'), isTrue);
      expect(isTitleCompatible(target, 'Doctor X: Mafia in White (Audio Latino)'), isTrue);
      expect(isTitleCompatible(target, 'Doctor X: Mafia in White Season 1'), isTrue);
      expect(isTitleCompatible(target, 'Doctor X'), isTrue);
      
      // Títulos no relacionados o navegación
      expect(isTitleCompatible(target, 'Más vistas'), isFalse);
      expect(isTitleCompatible(target, 'The Good Doctor'), isFalse);
      expect(isTitleCompatible(target, 'Titanic'), isFalse);
      expect(isTitleCompatible(target, 'Películas 2026'), isFalse);
    });

    test('isMovieResult identifica películas vs series', () {
      const movieResult = SearchResult(
        title: 'Más vistas',
        url: 'https://onlypelis.com/pelicula/?orden=semana',
        quality: 'Película',
        source: 'OnlyPelis',
        kind: 'movie',
        thumbnail: '',
      );
      expect(isMovieResult(movieResult), isTrue);

      const seriesResult = SearchResult(
        title: 'Doctor X: Mafia in White',
        url: 'https://onlypelis.com/serie/doctor-x-mafia-in-white/',
        quality: 'Serie',
        source: 'OnlyPelis',
        kind: 'series',
        thumbnail: '',
      );
      expect(isMovieResult(seriesResult), isFalse);
    });
  });
}
