import 'package:flutter_test/flutter_test.dart';
import 'package:auris_core/data/models/server/anime_detail.dart';

void main() {
  group('AnimeThemesData.fromJson', () {
    // Forma real de /api/themes (envelope {success,data:{themes:[...]}}).
    Map<String, dynamic> envelope() => {
      'success': true,
      'message': null,
      'data': {
        'themes': [
          {
            'type': 'OPENING',
            'title': 'Koi no Uta',
            'artist': 'Akari Kitou',
            'video': 'https://v.animethemes.moe/Tonikawa-OP1.webm',
            'video_720': 'https://v.animethemes.moe/Tonikawa-OP1.webm',
            'video_1080': null,
            'audio': null,
            'sequence': 0,
          },
          {
            'type': 'ENDING',
            'title': 'Tsuki to Hoshizora',
            'artist': 'KanoeRana',
            'video': 'https://v.animethemes.moe/Tonikawa-ED1-NCBD1080.webm',
            'video_720': 'https://v.animethemes.moe/Tonikawa-ED1.webm',
            'video_1080': 'https://v.animethemes.moe/Tonikawa-ED1-NCBD1080.webm',
            'audio': null,
            'sequence': 0,
          },
        ],
      },
      'error': null,
    };

    test('desenvuelve data.themes del envelope (bug: tab Extras vacío)', () {
      final parsed = AnimeThemesData.fromJson(envelope());
      expect(parsed.openings, hasLength(1));
      expect(parsed.endings, hasLength(1));
      expect(parsed.openings.first.title, 'Koi no Uta');
      expect(parsed.endings.first.videoUrl,
          'https://v.animethemes.moe/Tonikawa-ED1-NCBD1080.webm');
    });

    test('acepta mapa plano sin envelope', () {
      final flat = Map<String, dynamic>.from(
          (envelope()['data'] as Map<String, dynamic>));
      final parsed = AnimeThemesData.fromJson(flat);
      expect(parsed.openings, hasLength(1));
      expect(parsed.endings, hasLength(1));
    });

    test('envelope sin themes devuelve vacío sin romper', () {
      final parsed =
          AnimeThemesData.fromJson({'success': true, 'data': {}});
      expect(parsed.openings, isEmpty);
      expect(parsed.endings, isEmpty);
    });
  });
}
