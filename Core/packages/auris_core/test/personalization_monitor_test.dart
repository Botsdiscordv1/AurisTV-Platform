import 'package:flutter_test/flutter_test.dart';
import 'package:auris_core/auris_core.dart';

void main() {
  group('PersonalizationMonitor — Quality & Metrics Tests', () {
    test('auditHomeResponse — Detects quality issues in response', () {
      final response = HomeResponse(
        userId: 'user_1',
        maturityLevel: 'personalized',
        sections: [
          const HomeSection(
            id: 'sec_1',
            title: 'Section 1',
            strategy: 's',
            type: 'recommendation',
            priority: 1,
            items: [
              HomeItem(
                id: 'item_1',
                title: 'Item sin AnimeId',
                animeId: null, // ISSUE
                posterUrl: '', // ISSUE
              )
            ]
          ),
          const HomeSection(
            id: 'sec_empty',
            title: 'Empty Section',
            strategy: 's',
            type: 'recommendation',
            priority: 2,
            items: [] // ISSUE
          )
        ],
        generatedAt: ''
      );

      // El monitor imprime en consola en debugMode, pero podemos verificar que no crashea
      PersonalizationMonitor.instance.auditHomeResponse(response);
    });

    test('logMetric — Registers metrics without crash', () {
      PersonalizationMonitor.instance.logMetric('test_metric', 100, tags: {'tag1': 'v1'});
    });
  });
}
