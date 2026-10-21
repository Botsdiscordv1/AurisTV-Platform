import 'package:auris_core/data/models/server/episodes_response.dart';
import 'package:auris_core/data/providers/community_translation_provider.dart';
import 'package:flutter_test/flutter_test.dart';

EpisodeInfo _ep(Map<String, dynamic> json) =>
    EpisodeInfo.fromJson({'number': 10, 'id': 1, ...json});

void main() {
  group('EpisodeInfo.needsTranslation', () {
    test('parses true', () {
      expect(_ep({'needsTranslation': true}).needsTranslation, true);
    });
    test('parses false', () {
      expect(_ep({'needsTranslation': false}).needsTranslation, false);
    });
    test('defaults false when absent (old servers)', () {
      expect(_ep({}).needsTranslation, false);
    });
  });

  group('CommunityTranslationManager.shouldAttempt', () {
    test('false when nothing to translate', () {
      expect(
          CommunityTranslationManager.shouldAttempt(title: null, overview: null),
          false);
      expect(CommunityTranslationManager.shouldAttempt(title: '  ', overview: ''),
          false);
    });
    test('false for generic title + empty overview', () {
      expect(
          CommunityTranslationManager.shouldAttempt(
              title: 'Episode 10', overview: null),
          false);
      expect(
          CommunityTranslationManager.shouldAttempt(
              title: 'Episodio 3', overview: '  '),
          false);
    });
    test('true with real source text', () {
      expect(
          CommunityTranslationManager.shouldAttempt(
              title: 'ニャーもイベントを楽しむにゃ', overview: null),
          true);
      expect(
          CommunityTranslationManager.shouldAttempt(
              title: 'Episode 10', overview: 'Yani heads out.'),
          true);
    });
    test('false for scraper promo overview (not a synopsis)', () {
      expect(
          CommunityTranslationManager.shouldAttempt(
              title: 'Episodio 1',
              overview: 'Disfruta del capitulo 1 de La chispa del amor con '
                  'subtítulos y con doblaje al Español Latino. Elige uno de '
                  'los servidores que están disponibles.'),
          false);
    });
  });

  group('scraper promo', () {
    const promo = 'Disfruta del capitulo 1 de La chispa del amor con '
        'subtítulos y con doblaje al Español Latino. Elige uno de los '
        'servidores que están disponibles y navega fácilmente entre los '
        'episodios';
    test('detects promo texts', () {
      expect(CommunityTranslationManager.isScraperPromo(promo), true);
      expect(
          CommunityTranslationManager.isScraperPromo(
              'Disfruta del capítulo 7 de otra serie'),
          true);
      expect(
          CommunityTranslationManager.isScraperPromo(
              'Elige uno de los servidores disponibles'),
          true);
    });
    test('does not flag real synopses', () {
      expect(
          CommunityTranslationManager.isScraperPromo(
              'Na Bo-bae is a struggling writer — and human electrical '
              'conductor. She meets a man who changes her life.'),
          false);
      expect(
          CommunityTranslationManager.isScraperPromo(
              'Una escritora con problemas conoce a un hombre que cambiará '
              'su vida para siempre.'),
          false);
      expect(CommunityTranslationManager.isScraperPromo(null), false);
      expect(CommunityTranslationManager.isScraperPromo('  '), false);
    });
  });

  group('helpers', () {
    test('isGenericTitle variants', () {
      expect(CommunityTranslationManager.isGenericTitle('Episode 10'), true);
      expect(CommunityTranslationManager.isGenericTitle('Episodio 3'), true);
      expect(CommunityTranslationManager.isGenericTitle('EP 12'), true);
      expect(CommunityTranslationManager.isGenericTitle('Nya también'), false);
    });
    test('containsCjk', () {
      expect(CommunityTranslationManager.containsCjk('ニャー'), true);
      expect(CommunityTranslationManager.containsCjk('Hello'), false);
    });
    test('detectSourceLanguage', () {
      expect(
          CommunityTranslationManager.detectSourceLanguage('ニャーも'), 'ja');
      expect(CommunityTranslationManager.detectSourceLanguage('Hello'), 'en');
    });
    test('detectSourceLanguage detects Spanish (never sends es as en)', () {
      expect(
          CommunityTranslationManager.detectSourceLanguage(
              'Disfruta del capitulo de la serie y elige uno de los servidores'),
          'es');
      expect(
          CommunityTranslationManager.detectSourceLanguage(
              'Una escritora con problemas conoce a un hombre'),
          'es');
      // Inglés real no debe clasificarse como español.
      expect(
          CommunityTranslationManager.detectSourceLanguage(
              'Na Bo-bae is a struggling writer and human electrical conductor'),
          'en');
      expect(
          CommunityTranslationManager.detectSourceLanguage(
              'La La Land is a 2016 American musical romantic comedy film '
              'directed by Damien Chazelle. The con artist lives in Los '
              'Angeles and wants a fresh start.'),
          'en');
    });
  });

  group('polishSpanishTitle / capitalizeTitle', () {
    test('fixes wrong accent + capitalizes (solá → Sola)', () {
      expect(CommunityTranslationManager.polishSpanishTitle('solá'), 'Sola');
      expect(CommunityTranslationManager.capitalizeTitle('solá'), 'Sola');
      expect(CommunityTranslationManager.polishSpanishTitle('sola'), 'Sola');
    });
    test('missing accents on invariant words', () {
      expect(CommunityTranslationManager.polishSpanishTitle('tambien'),
          'También');
      expect(CommunityTranslationManager.polishSpanishTitle('ultimo acto'),
          'Último acto');
      expect(CommunityTranslationManager.polishSpanishTitle('la musica'),
          'La música');
    });
    test('already correct is unchanged', () {
      expect(CommunityTranslationManager.polishSpanishTitle('Sola'), 'Sola');
      expect(CommunityTranslationManager.polishSpanishTitle('También'), 'También');
    });
    test('preserves capitalization pattern of fixed word', () {
      expect(CommunityTranslationManager.polishSpanishTitle('solá noche'),
          'Sola noche');
      expect(CommunityTranslationManager.polishSpanishTitle('Tambien'), 'También');
    });
    test('skips leading digits/symbols to first letter', () {
      expect(CommunityTranslationManager.polishSpanishTitle('7. transparencia'),
          '7. Transparencia');
      expect(CommunityTranslationManager.polishSpanishTitle('...hola'), '...Hola');
    });
    test('empty / whitespace / non-letters', () {
      expect(CommunityTranslationManager.polishSpanishTitle(''), '');
      expect(CommunityTranslationManager.polishSpanishTitle('   '), '');
      expect(CommunityTranslationManager.polishSpanishTitle('123'), '123');
    });
    test('does not touch ambiguous monosyllables', () {
      expect(CommunityTranslationManager.polishSpanishTitle('si no vuelvo'),
          'Si no vuelvo');
      expect(CommunityTranslationManager.polishSpanishTitle('el lago'),
          'El lago');
    });
  });
}
