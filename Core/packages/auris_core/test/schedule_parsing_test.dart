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

  group('ScheduleResponse.localize Tests', () {
    Map<String, dynamic> serverPayload() => {
          "data": {
            "season": "SUMMER",
            "year": 2026,
            "total": 3,
            "days": [
              {
                "day": "lunes",
                "dayIndex": 0,
                "isToday": false,
                "items": <Map<String, dynamic>>[]
              },
              {
                "day": "martes",
                "dayIndex": 1,
                "isToday": false,
                "items": [
                  {
                    "id": 10,
                    "title": "Sin Airing At",
                    "sourceAvailable": false,
                  }
                ]
              },
              {
                "day": "jueves",
                "dayIndex": 3,
                "isToday": false,
                "items": <Map<String, dynamic>>[]
              },
              {
                "day": "viernes",
                "dayIndex": 4,
                "isToday": true,
                "items": [
                  {
                    "id": 1,
                    "title": "Shiguang Dailiren III",
                    "airingAt":
                        DateTime(2026, 9, 24, 22, 20).millisecondsSinceEpoch ~/
                            1000,
                    "sourceAvailable": true,
                  },
                  {
                    "id": 2,
                    "title": "Tarde",
                    "airingAt":
                        DateTime(2026, 9, 24, 23, 5).millisecondsSinceEpoch ~/
                            1000,
                    "sourceAvailable": true,
                  },
                ]
              },
              {
                "day": "sabado",
                "dayIndex": 5,
                "isToday": false,
                "items": <Map<String, dynamic>>[]
              },
              {
                "day": "domingo",
                "dayIndex": 6,
                "isToday": false,
                "items": <Map<String, dynamic>>[]
              },
              {
                "day": "miercoles",
                "dayIndex": 2,
                "isToday": false,
                "items": <Map<String, dynamic>>[]
              },
            ],
          },
        };

    test(
        'Moves items to the local weekday of airingAt and marks local today as isToday',
        () {
      final response =
          ScheduleResponse.fromJson(serverPayload()).localize(
        now: DateTime(2026, 9, 24, 22, 34),
      );

      expect(response.days.length, 7);
      for (var i = 0; i < 7; i++) {
        expect(response.days[i].dayIndex, i);
      }

      final jueves = response.days[3];
      expect(jueves.day, 'jueves');
      expect(jueves.isToday, true);
      expect(jueves.items.length, 2);
      expect(jueves.items.map((e) => e.title),
          ['Shiguang Dailiren III', 'Tarde']);

      final viernes = response.days[4];
      expect(viernes.isToday, false);
      expect(viernes.items, isEmpty);

      expect(response.days.where((d) => d.isToday).length, 1);
      expect(response.total, 3);
    });

    test('Items without airingAt keep their original server column', () {
      final response = ScheduleResponse.fromJson(serverPayload()).localize(
        now: DateTime(2026, 9, 24, 22, 34),
      );

      final martes = response.days[1];
      expect(martes.items.length, 1);
      expect(martes.items.first.title, 'Sin Airing At');
      expect(martes.isToday, false);
    });

    test('Item airing on a different local day lands on that day column', () {
      final json = {
        "days": [
          {
            "day": "lunes",
            "dayIndex": 0,
            "isToday": true,
            "items": [
              {
                "id": 5,
                "title": "Domingo Local",
                "airingAt":
                    DateTime(2026, 9, 27, 10, 0).millisecondsSinceEpoch ~/ 1000,
              }
            ]
          },
        ]
      };

      final response = ScheduleResponse.fromJson(json).localize(
        now: DateTime(2026, 9, 24, 12, 0),
      );

      final domingo = response.days[6];
      expect(domingo.day, 'domingo');
      expect(domingo.items.length, 1);
      expect(domingo.items.first.title, 'Domingo Local');
      expect(response.days[0].items, isEmpty);
      expect(response.days[0].isToday, false);
      expect(response.days[3].isToday, true);
    });

    test('Empty response is returned unchanged', () {
      final response = ScheduleResponse.fromJson({"days": []}).localize();
      expect(response.days, isEmpty);
    });
  });

  group('ScheduleItem premiere status (Retrasado/Adelantado)', () {
    test('Parses premiereStatus and premiereDeltaMin from JSON', () {
      final json = {
        "days": [
          {
            "day": "viernes",
            "dayIndex": 4,
            "isToday": true,
            "items": [
              {
                "id": 7,
                "title": "Shiguang Dailiren III",
                "airingAt": 1790306800,
                "premiereStatus": "delayed",
                "premiereDeltaMin": 37,
              }
            ]
          }
        ]
      };

      final item = ScheduleResponse.fromJson(json).days.first.items.first;
      expect(item.premiereStatus, 'delayed');
      expect(item.premiereDeltaMin, 37);
    });

    test('Missing premiere fields parse as null', () {
      final json = {
        "days": [
          {
            "day": "viernes",
            "dayIndex": 4,
            "isToday": true,
            "items": [
              {"id": 1, "title": "Sin Etiqueta"}
            ]
          }
        ]
      };

      final item = ScheduleResponse.fromJson(json).days.first.items.first;
      expect(item.premiereStatus, isNull);
      expect(item.premiereDeltaMin, isNull);
    });

    test('Premiere fields survive localize() (re-grupado de los mismos items)',
        () {
      final json = {
        "days": [
          {
            "day": "viernes",
            "dayIndex": 4,
            "isToday": true,
            "items": [
              {
                "id": 1,
                "title": "Shiguang Dailiren III",
                "airingAt":
                    DateTime(2026, 9, 24, 22, 20).millisecondsSinceEpoch ~/
                        1000,
                "premiereStatus": "advanced",
                "premiereDeltaMin": -12,
              }
            ]
          },
        ]
      };

      final response = ScheduleResponse.fromJson(json).localize(
        now: DateTime(2026, 9, 24, 22, 34),
      );

      final item = response.days[3].items.first;
      expect(item.title, 'Shiguang Dailiren III');
      expect(item.premiereStatus, 'advanced');
      expect(item.premiereDeltaMin, -12);
    });
  });
}
