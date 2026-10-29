import 'package:auris_core/data/models/content_sports.dart';
import 'package:auris_core/data/sources/lacancha_events_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fragmento que replica la estructura real del HTML del home de eventos en
/// vivo de lacancha.tv (`/es/en-vivo`), tal como se observó en la extracción:
/// tarjetas `hub-card` que enlazan a `/es/ver/<id>` con metadata renderizada.
const String _sampleHtml = '''
<div class="events-grid">
<a class="hub-card" href="/es/ver/31300"><div class="hub-card-media" style="background-image:url(&quot;https://static.ppvservices.st/assets/thumb/46d2ce9890062a6a8db4cc892f071d5c-thumbnail.jpg&quot;), linear-gradient(135deg, #003e7e, #000d33)"><span class="hub-card-grad"></span><div class="hub-card-top"><span class="hub-live"><span class="dot"></span>EN VIVO</span></div></div><div class="hub-card-body"><span class="hub-meta"><span class="hub-sport"><svg viewBox="0 0 256 256"></svg>Fútbol</span><span class="hub-league">Liga MX</span></span><span class="hub-name">América vs. Tijuana</span><span class="hub-servers">5 servidores</span></div></a>
<a class="hub-card" href="/es/ver/31284"><div class="hub-card-media" style="background-image:url(&quot;https://static.ppvservices.st/assets/thumb/2c0db52c807e3e12fa4ea02c95180f43-thumbnail.jpg&quot;), linear-gradient(135deg, #552583, #12173f)"><div class="hub-card-top"><span class="hub-live"><span class="dot"></span>EN VIVO</span></div></div><div class="hub-card-body"><span class="hub-meta"><span class="hub-sport"><svg viewBox="0 0 256 256"></svg>Basket</span><span class="hub-league">NBA</span></span><span class="hub-name">Los Angeles Lakers vs. LA Clippers</span><span class="hub-servers">1 servidor</span></div></a>
</div>
''';

void main() {
  group('LacanchaEventsSource.parseLiveEventsHtml', () {
    test('extrae los eventos del HTML con su metadata', () {
      final events = LacanchaEventsSource.parseLiveEventsHtml(_sampleHtml);

      expect(events, hasLength(2));

      // Evento 1: América vs. Tijuana (Liga MX, 5 servidores)
      final e1 = events[0];
      expect(e1.id, '31300');
      expect(e1.title, 'América vs. Tijuana');
      expect(e1.league, 'Liga MX');
      expect(e1.sportLabel, 'Fútbol');
      expect(e1.sport, 'futbol');
      expect(e1.isLive, isTrue);
      expect(e1.status, 'EN VIVO');
      expect(e1.channels, hasLength(5));
      expect(e1.posterUrl, contains('46d2ce9890062a6a8db4cc892f071d5c'));
      expect(e1.colors, ['#003e7e', '#000d33']);
      expect(e1.teams, ['América', 'Tijuana']);

      // Evento 2: Lakers vs. Clippers (NBA, 1 servidor)
      final e2 = events[1];
      expect(e2.id, '31284');
      expect(e2.title, 'Los Angeles Lakers vs. LA Clippers');
      expect(e2.league, 'NBA');
      expect(e2.sport, 'basket');
      expect(e2.channels, hasLength(1));
      expect(e2.teams, ['Los Angeles Lakers', 'LA Clippers']);
    });

    test('devuelve lista vacía con HTML sin tarjetas', () {
      expect(LacanchaEventsSource.parseLiveEventsHtml('<html></html>'), isEmpty);
    });

    test('ContentSports.fromJson parsea el shape de lacancha', () {
      // Shape observado en /es/ver/<id> (options -> channels).
      final json = {
        'id': '31284',
        'name': 'Los Angeles Lakers vs. LA Clippers',
        'ppvCategory': 'Basketball',
        'league': 'NBA',
        'posterUrl': 'https://static.ppvservices.st/assets/thumb/x.jpg',
        'colors': ['#552583', '#12173f'],
        'startsAtMs': 1793241000000,
        'endsAtMs': 1793251800000,
        'isLive': true,
        'alwaysLive': false,
        'viewers': 729,
        'source': 'ppv',
      };
      final e = ContentSports.fromJson(json);
      expect(e.id, '31284');
      expect(e.title, 'Los Angeles Lakers vs. LA Clippers');
      expect(e.sportLabel, 'Basketball');
      expect(e.league, 'NBA');
      expect(e.viewers, 729);
      expect(e.isLive, isTrue);
      expect(e.startsAtMs, 1793241000000);
    });

    test('parseEventDetailHtml extrae streams[] reales e ignora more[]', () {
      // Payload RSC de la página de detalle, replicando la estructura real:
      // el objeto del partido (`{"match":…}`) con sus `streams[]`, más eventos
      // relacionados en `more[]` (con `options[]`) que NO deben contar como
      // canales de este evento.
      final decoded =
          '5:["\$","div",null,{"className":"doble-root ver-root","children":['
          '["\$","\$L1c",null,{}],'
          '["\$","\$L1d",null,{"match":{"id":"hub-31300","home_team":"América",'
          '"away_team":"Tijuana","kickoff_at":"2026-10-29T02:00:00.000Z",'
          '"status":"live"},'
          '"streams":[{"id":"hub:31300","embed_name":"Liga MX",'
          '"embed_url":"https://taifood-blog.asia/embed/liga-mx/2026-10-28/ame-tij",'
          '"channel":{"name":"Liga MX","slug":"hub-31300"},"direct":true}],'
          '"locale":"es","title":"América vs. Tijuana","league":"Liga MX",'
          '"more":[{"id":"31284","name":"Otro","options":[{"embed_name":"X",'
          '"embed_url":"https://taifood-blog.asia/embed/nba/2026-10-28/otro"}]}]'
          '}]]}]';
      final escaped = decoded
          .replaceAll(r'\', r'\\')
          .replaceAll('"', r'\"');
      final html = '<script>self.__next_f.push([1,"$escaped"])</script>';

      final e = LacanchaEventsSource.parseEventDetailHtml(html, '31300');
      expect(e, isNotNull);
      expect(e!.title, 'América vs. Tijuana');
      expect(e.league, 'Liga MX');
      expect(e.isLive, isTrue);
      expect(e.teams, ['América', 'Tijuana']);
      // Solo el stream del evento principal (no el de more[]).
      expect(e.channels, hasLength(1));
      expect(e.channels.first['name'], 'Liga MX');
      expect(e.channels.first['url'],
          'https://taifood-blog.asia/embed/liga-mx/2026-10-28/ame-tij');
      expect(e.channels.first['referer'], 'https://taifood-blog.asia');
    });

    test('parseEventDetailHtml devuelve null sin el objeto del partido', () {
      expect(
        LacanchaEventsSource.parseEventDetailHtml('<html></html>', '1'),
        isNull,
      );
    });
  });
}
