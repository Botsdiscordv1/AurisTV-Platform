import 'package:flutter_test/flutter_test.dart';
import 'package:auris_core/data/providers/active_player_provider.dart';
import 'package:auris_core/data/providers/library_providers.dart';
import 'package:auris_core/data/models/playback_history.dart';

PlaybackHistory _history({String? episodeTitle}) => PlaybackHistory(
      contentId: 'Tonikaku Kawaii',
      season: 1,
      episode: '1',
      positionInMilliseconds: 60000,
      durationInMilliseconds: 600000,
      updatedAt: DateTime.now(),
      title: 'Tonikaku Kawaii',
      category: 'anime',
      episodeTitle: episodeTitle,
    );

void main() {
  group('episodeDisplayLabel', () {
    test('real -> T1:E1 "Titulo"', () {
      expect(episodeDisplayLabel('1', season: 1, title: 'Matrimonio'),
          'T1:E1 "Matrimonio"');
    });
    test('genérico cuenta como ausente', () {
      expect(episodeDisplayLabel('1', season: 1, title: 'Episodio 1'), 'T1:E1');
      expect(episodeDisplayLabel('1', season: 1, title: ''), 'T1:E1');
      expect(episodeDisplayLabel('1', season: 1), 'T1:E1');
    });
    test('no numérico pasa tal cual', () {
      expect(episodeDisplayLabel('OP', title: 'Koi no Uta'), 'OP "Koi no Uta"');
    });
  });

  group('continueCardSubtitle', () {
    test('real -> T1:E1 . Titulo', () {
      final s = continueCardSubtitle(_history(episodeTitle: 'Matrimonio'));
      expect(s.line1, 'T1:E1 . Matrimonio');
    });
    test('genérico guardado -> bare T1:E1', () {
      final s = continueCardSubtitle(_history(episodeTitle: 'Episodio 1'));
      expect(s.line1, 'T1:E1');
    });
    test('null -> bare T1:E1', () {
      final s = continueCardSubtitle(_history());
      expect(s.line1, 'T1:E1');
    });
  });
}
