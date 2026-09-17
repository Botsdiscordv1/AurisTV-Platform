import 'package:flutter_test/flutter_test.dart';
import 'package:auris_core/auris_core.dart';

void main() {
  group('Personalized Home Contract & Processing Tests', () {
    test('1. Parsing - Valid HomeResponse, HomeSection, HomeItem with Null fields', () {
      final json = {
        "userId": "user_123",
        "maturityLevel": "personalized",
        "generatedAt": "2026-03-30T12:00:00Z",
        "sections": [
          {
            "id": "sec_for_you",
            "title": "Para ti",
            "subtitle": "Basado en tus gustos",
            "strategy": "recommendation_strategy",
            "type": "recommendation",
            "priority": 1,
            "reasonKeys": ["MATCH_GENRE"],
            "items": [
              {
                "id": "item_01",
                "animeId": "anime_abc",
                "title": "Chainsaw Man",
                "posterUrl": "https://images.com/poster.jpg",
                "backdropUrl": "https://images.com/backdrop.jpg",
                "progress": null,
                "detailUrl": "https://auristv.com/detail/anime_abc",
                "kind": "anime",
                "type": "TV",
                "rating": 9.5,
                "year": 2022,
                "score": 95.0,
                "reasonKeys": ["STRONG_TASTE_MATCH"]
              },
              {
                "id": "item_02",
                "animeId": null,
                "title": "Contenido sin Catálogo",
                "posterUrl": null,
                "backdropUrl": null,
                "progress": null,
                "detailUrl": null,
                "kind": "movie",
                "type": "Movie",
                "rating": null,
                "year": null,
                "score": null,
                "reasonKeys": ["UNKNOWN_KEY"]
              }
            ]
          }
        ]
      };

      final response = HomeResponse.fromJson(json);

      expect(response.userId, "user_123");
      expect(response.maturityLevel, "personalized");
      expect(response.sections.length, 1);

      final section = response.sections.first;
      expect(section.id, "sec_for_you");
      expect(section.type, "recommendation");
      expect(section.items.length, 2);

      final item1 = section.items[0];
      expect(item1.animeId, "anime_abc");
      expect(item1.title, "Chainsaw Man");
      expect(item1.score, 95.0);

      final item2 = section.items[1];
      expect(item2.animeId, isNull);
      expect(item2.posterUrl, isNull);
      expect(item2.score, isNull);
    });

    test('2. Cold Start - Handles maturityLevel = cold with 6 sections normally', () {
      final json = {
        "userId": "guest_user",
        "maturityLevel": "cold",
        "generatedAt": "2026-03-30T12:00:00Z",
        "sections": List.generate(6, (index) => {
          "id": "editorial_$index",
          "title": "Sección Editorial $index",
          "strategy": "static",
          "type": "editorial",
          "priority": index,
          "items": []
        })
      };

      final response = HomeResponse.fromJson(json);
      expect(response.maturityLevel, "cold");
      expect(response.sections.length, 6);
      for (int i = 0; i < 6; i++) {
        expect(response.sections[i].type, "editorial");
      }
    });

    test('3. Personalized - Mapping items and reasonKeys correctly', () {
      final itemJson = {
        "id": "item_test",
        "animeId": "anime_123",
        "title": "Attack on Titan",
        "posterUrl": "https://images.com/a.jpg",
        "backdropUrl": "https://images.com/b.jpg",
        "progress": {"position": 5000, "duration": 10000},
        "detailUrl": "https://auristv.com/detail/123",
        "kind": "anime",
        "type": "TV",
        "rating": 9.8,
        "year": 2013,
        "score": 99.0,
        "reasonKeys": ["STRONG_TASTE_MATCH"]
      };

      final homeItem = HomeItem.fromJson(itemJson);
      
      final resolvedSubtitle = PersonalizedHomeHelper.getContextSubtitle(homeItem.reasonKeys);

      expect(resolvedSubtitle, "Muy recomendado para ti");
      expect(homeItem.progress, isNotNull);
      expect(homeItem.progress['position'], 5000);
    });

    test('4. reasonKeys - Unknown key must be silenced / ignored', () {
      final itemJson = {
        "id": "item_unknown_reason",
        "title": "Desconocido",
        "reasonKeys": ["COMPLETELY_NEW_ALGORITHM_KEY"]
      };

      final homeItem = HomeItem.fromJson(itemJson);
      final resolvedSubtitle = PersonalizedHomeHelper.getContextSubtitle(homeItem.reasonKeys);

      // No debe ser mapeado a texto técnico ni romper
      expect(resolvedSubtitle, isNull);
    });

    test('5. Determinismo Visual - Items and sections maintain original backend order', () {
      final json = {
        "userId": "user_456",
        "maturityLevel": "personalized",
        "generatedAt": "2026-03-30T12:00:00Z",
        "sections": [
          {
            "id": "sec_b",
            "title": "Segunda Sección en Backend",
            "strategy": "strat",
            "type": "recommendation",
            "priority": 10,
            "items": []
          },
          {
            "id": "sec_a",
            "title": "Primera Sección en Backend",
            "strategy": "strat",
            "type": "editorial",
            "priority": 5,
            "items": []
          }
        ]
      };

      final response = HomeResponse.fromJson(json);
      // Flutter NO debe reordenar por prioridad, el orden recibido es el definitivo.
      expect(response.sections[0].id, "sec_b");
      expect(response.sections[1].id, "sec_a");
    });
  });
}
