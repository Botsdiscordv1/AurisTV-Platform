import 'package:flutter_test/flutter_test.dart';
import 'package:auris_core/auris_core.dart';

void main() {
  group('ReleaseCountdownLogic', () {
    final now = DateTime(2026, 10, 7, 12, 0, 0);

    test('episodes available -> AVAILABLE (takes precedence)', () {
      final state = ReleaseCountdownLogic.evaluate(
        episodes: [
          const EpisodeInfo(number: 1, id: 1, title: 'Ep 1')
        ],
        releaseTimestamp: '2026-10-10T00:00:00Z',
        now: now,
      );
      expect(state, ReleaseState.available);
    });

    test('future date -> UPCOMING', () {
      final state = ReleaseCountdownLogic.evaluate(
        episodes: [],
        releaseTimestamp: '2026-10-10T15:30:00Z',
        now: now,
      );
      expect(state, ReleaseState.upcoming);
    });

    test('today before release -> RELEASING_TODAY', () {
      final state = ReleaseCountdownLogic.evaluate(
        episodes: [],
        releaseTimestamp: '2026-10-07T18:00:00Z',
        now: now,
      );
      expect(state, ReleaseState.releasingToday);
    });

    test('past date + no episodes -> RELEASED_WITHOUT_EPISODES', () {
      final state = ReleaseCountdownLogic.evaluate(
        episodes: [],
        releaseTimestamp: '2026-10-01T00:00:00Z',
        now: now,
      );
      expect(state, ReleaseState.releasedWithoutEpisodes);
    });

    test('null date -> NO_RELEASE_DATE', () {
      final state = ReleaseCountdownLogic.evaluate(
        episodes: [],
        releaseTimestamp: null,
        releaseDate: null,
        now: now,
      );
      expect(state, ReleaseState.noReleaseDate);
    });

    test('invalid timestamp falls back correctly without crash', () {
      final dt = ReleaseCountdownLogic.parseReleaseDateTime('invalid-timestamp-xyz', null);
      expect(dt, isNull);

      final state = ReleaseCountdownLogic.evaluate(
        episodes: [],
        releaseTimestamp: 'invalid-timestamp-xyz',
        now: now,
      );
      expect(state, ReleaseState.noReleaseDate);
    });

    test('timezone conversion with offset handling (-05:00)', () {
      // 2026-10-07T14:00:00-05:00 is 19:00:00 UTC
      final dt = ReleaseCountdownLogic.parseReleaseDateTime('2026-10-07T14:00:00-05:00', null);
      expect(dt, isNotNull);
      expect(dt!.toUtc().hour, 19);
    });
  });
}
