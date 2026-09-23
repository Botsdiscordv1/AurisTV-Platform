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
