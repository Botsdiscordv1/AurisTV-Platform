import 'package:auris_core/data/models/server/search_result.dart';
import 'package:auris_core/data/providers/content_providers.dart';
import 'package:flutter_test/flutter_test.dart';

SearchResult curatedAv1() => const SearchResult(
      title: 'Super no Ura de Yani Suu Futari',
      url: 'https://animeav1.com/media/super-no-ura-de-yani-suu-futari',
      source: 'AnimeAV1',
      quality: 'ANIME • Sub Español',
      thumbnail: '',
      slug: 'super-no-ura-de-yani-suu-futari',
    );

void main() {
  group('isRogueVariant', () {
    test('mini con distinto slug+url se descarta', () {
      const mini = SourceItem(
        source: 'AnimeAV1',
        url: 'https://animeav1.com/media/super-no-ura-de-yani-suu-futari-mini',
        quality: 'ANIME • Sub Español',
        slug: 'super-no-ura-de-yani-suu-futari-mini',
      );
      expect(isRogueVariant(mini, [curatedAv1()]), true);
    });

    test('mismo slug se conserva (split SUB/LATINO)', () {
      const latino = SourceItem(
        source: 'AnimeAV1',
        url: 'https://animeav1.com/media/super-no-ura-de-yani-suu-futari',
        quality: 'LATINO',
        slug: 'super-no-ura-de-yani-suu-futari',
      );
      expect(isRogueVariant(latino, [curatedAv1()]), false);
    });

    test('misma url se conserva', () {
      const same = SourceItem(
        source: 'AnimeAV1',
        url: 'https://animeav1.com/media/super-no-ura-de-yani-suu-futari',
        quality: 'HD',
      );
      expect(isRogueVariant(same, [curatedAv1()]), false);
    });

    test('familia no curada se conserva', () {
      const d23 = SourceItem(
        source: 'AnimeD23',
        url: 'https://animed23.com/anime/super-no-ura-de-yani-suu-futari/',
        quality: 'ANIME • Sub Español',
        slug: 'super-no-ura-de-yani-suu-futari',
      );
      expect(isRogueVariant(d23, [curatedAv1()]), false);
    });

    test('sin curadas no se descarta nada', () {
      const mini = SourceItem(
        source: 'AnimeAV1',
        url: 'https://animeav1.com/media/super-no-ura-de-yani-suu-futari-mini',
        quality: 'ANIME • Sub Español',
        slug: 'super-no-ura-de-yani-suu-futari-mini',
      );
      expect(isRogueVariant(mini, null), false);
      expect(isRogueVariant(mini, const []), false);
    });

    test('url vacía nunca es rogue', () {
      const empty = SourceItem(source: 'AnimeAV1', url: '', quality: 'HD');
      expect(isRogueVariant(empty, [curatedAv1()]), false);
    });
  });
}
