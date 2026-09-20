import 'package:flutter_test/flutter_test.dart';
import 'package:auris_core/auris_core.dart';

void main() {
  group('ScheduleResponse Parsing Tests', () {
    test('Should parse schedule with data wrapping envelope', () {
      final json = {
        "data": {
          "season": "WINTER",
          "year": 2026,
          "total": 1,
          "days": [
            {
              "day": "Lunes",
              "dayIndex": 0,
              "isToday": true,
              "items": [
                {
                  "id": 123,
                  "title": "Bleach",
                  "sourceAvailable": true
                }
              ]
            }
          ]
        }
      };

      final response = ScheduleResponse.fromJson(json);
      expect(response.season, "WINTER");
      expect(response.year, 2026);
      expect(response.total, 1);
      expect(response.days.length, 1);
      expect(response.days.first.day, "Lunes");
      expect(response.days.first.items.length, 1);
      expect(response.days.first.items.first.title, "Bleach");
    });

    test('Should parse schedule without data wrapping envelope', () {
      final json = {
        "season": "SUMMER",
        "year": 2025,
        "total": 0,
        "days": []
      };

      final response = ScheduleResponse.fromJson(json);
      expect(response.season, "SUMMER");
      expect(response.year, 2025);
      expect(response.days, isEmpty);
    });
  });
}
