import 'package:flutter_test/flutter_test.dart';
import 'package:auris_core/auris_core.dart';

void main() {
  group('SectionPresentationResolver', () {
    test('resolve maps strings with top10 to top10', () {
      expect(
        SectionPresentationResolver.resolve('Top 10 Global'),
        SectionPresentation.top10,
      );
    });

    test('resolve maps trending strings to wide', () {
      expect(
        SectionPresentationResolver.resolve('Trending Now'),
        SectionPresentation.wide,
      );
    });

    test('resolve prioritizes serverFormat over type heuristics', () {
      // 'Top 10 Global' normally maps to top10, but we force 'wide'
      expect(
        SectionPresentationResolver.resolve('Top 10 Global', serverFormat: 'wide'),
        SectionPresentation.wide,
      );

      // 'Unknown' normally maps to poster, but we force 'top10'
      expect(
        SectionPresentationResolver.resolve('Unknown', serverFormat: 'top10'),
        SectionPresentation.top10,
      );
    });
  });

  group('SectionComposer', () {
    test('integrity: preserves all MediaItem data', () {
      final items = [
        const MediaItem(
          id: '1',
          title: 'Title',
          posterUrl: 'poster',
          type: MediaType.anime,
          animeId: 'anime_123',
          score: 8.5,
          reasonKeys: ['reason_1'],
        ),
      ];

      final raw = [
        HomeLayoutSection(
          type: HomeSectionType.trendingAnime,
          title: 'Trending',
          data: items,
        ),
      ];

      final composed = SectionComposer.compose(raw);

      expect(composed.length, 1);
      final item = composed[0].items.first;
      expect(item.id, '1');
      expect(item.title, 'Title');
      expect(item.animeId, 'anime_123');
      expect(item.score, 8.5);
      expect(item.reasonKeys, ['reason_1']);
    });

    test('no item deletion: count stays identical', () {
      final items = List.generate(5, (i) => MediaItem(id: '$i', title: 'T', posterUrl: '', type: MediaType.anime));
      final raw = [
        HomeLayoutSection(type: HomeSectionType.editorial, data: EditorialRow(badge: EditorialBadge.essential, title: 'E', items: items)),
      ];

      final composed = SectionComposer.compose(raw);
      expect(composed[0].items.length, 5);
    });

    test('unknown sections survive with poster fallback', () {
      final raw = [
        const HomeLayoutSection(
          type: HomeSectionType.editorial,
          title: 'Unknown Title',
          data: EditorialRow(badge: EditorialBadge.essential, title: 'Unknown', items: [
            MediaItem(id: '1', title: 'T', posterUrl: '', type: MediaType.anime),
          ]),
        ),
      ];

      final composed = SectionComposer.compose(raw);
      expect(composed.length, 1);
      expect(composed[0].presentation, SectionPresentation.poster);
    });

    test('empty sections are correctly removed', () {
      final raw = [
        const HomeLayoutSection(
          type: HomeSectionType.editorial,
          data: EditorialRow(badge: EditorialBadge.essential, title: 'Empty', items: []),
        ),
      ];

      final composed = SectionComposer.compose(raw);
      expect(composed, isEmpty);
    });

    test('visual rhythm: PRESERVES server-driven order (WIDE + WIDE + POSTER)', () {
      final raw = [
        const HomeLayoutSection(type: HomeSectionType.continueWatching, title: 'CW'), // WIDE
        const HomeLayoutSection(type: HomeSectionType.editorial, title: 'Novedades'), // WIDE
        const HomeLayoutSection(type: HomeSectionType.editorial, title: 'Catalog'),   // POSTER
      ];

      final composed = SectionComposer.compose(raw);

      // Senior Logic: La app ya no reordena para romper monotonía, confía en el server.
      expect(composed[0].title, 'CW');
      expect(composed[1].title, 'Novedades');
      expect(composed[2].title, 'Catalog');
      
      expect(composed[0].presentation, SectionPresentation.wide);
      expect(composed[1].presentation, SectionPresentation.wide);
      expect(composed[2].presentation, SectionPresentation.poster);
    });

    test('visual rhythm: keeps WIDE + WIDE if no alternative exists', () {
      final raw = [
        const HomeLayoutSection(type: HomeSectionType.continueWatching, title: 'CW'),
        const HomeLayoutSection(type: HomeSectionType.recentEpisodes, title: 'RE'),
      ];

      final composed = SectionComposer.compose(raw);

      expect(composed.length, 2);
      expect(composed[0].presentation, SectionPresentation.wide);
      expect(composed[1].presentation, SectionPresentation.wide);
    });

    test('Top10 remains Top10', () {
      final raw = [
        const HomeLayoutSection(type: HomeSectionType.top10Global, title: 'Ranking'),
      ];

      final composed = SectionComposer.compose(raw);
      expect(composed[0].presentation, SectionPresentation.top10);
    });

    test('respects serverFormat from HomeLayoutSection', () {
      final raw = [
        const HomeLayoutSection(
          type: HomeSectionType.editorial,
          title: 'Section with Server Format',
          serverFormat: 'wide',
          data: EditorialRow(badge: EditorialBadge.essential, title: 'E', items: [
            MediaItem(id: '1', title: 'T', posterUrl: '', type: MediaType.anime, bannerUrl: 'banner'),
          ]),
        ),
      ];

      final composed = SectionComposer.compose(raw);
      expect(composed[0].presentation, SectionPresentation.wide);
    });

    test('category layout preserves input order (functional priority disabled)', () {
      final raw = [
        const HomeLayoutSection(type: HomeSectionType.trendingAnime, title: 'Trending'), 
        const HomeLayoutSection(type: HomeSectionType.recentEpisodes, title: 'Recent'),   
      ];

      final composed = SectionComposer.compose(raw);

      // Ahora se mantiene el orden de entrada, ignorando prioridades funcionales locales.
      expect(composed[0].type, HomeSectionType.trendingAnime);
      expect(composed[1].type, HomeSectionType.recentEpisodes);
    });
  });
}
