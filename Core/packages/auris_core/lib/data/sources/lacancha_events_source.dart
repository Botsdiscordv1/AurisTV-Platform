import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/content_sports.dart';

/// Fuente de eventos deportivos en vivo de **lacancha.tv**.
///
/// La app de lacancha (`lacancha-1.0.2.apk`) es un shell WebView que carga el
/// sitio `https://lacancha.tv`. Los eventos en vivo NO viven en el APK: se
/// sirven desde el HTML público del home (`/es/en-vivo`), que embebe el
/// catálogo como tarjetas (`hub-card`) renderizadas por Next.js. No requiere
/// clave, login ni servidor propio.
///
/// Cada tarjeta aporta: id (ruta `/es/ver/<id>`), nombre, liga, deporte,
/// miniatura, estado EN VIVO y número de servidores. Los streams concretos
/// (embeds) se resuelven aparte en la fase de reproducción (ver Fase 2).
class LacanchaEventsSource {
  LacanchaEventsSource([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              headers: const {
                'User-Agent':
                    'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
                'Accept-Language': 'es-MX,es;q=0.9',
              },
            ));

  static const String baseUrl = 'https://lacancha.tv';
  static const String _livePath = '/es/en-vivo';

  final Dio _dio;

  /// Descarga el home de eventos en vivo y los convierte en [ContentSports].
  ///
  /// Devuelve la lista tal cual la sirve lacancha (solo EN VIVO). Si la
  /// petición falla o el HTML cambia de estructura, devuelve lista vacía en
  /// vez de lanzar, para no tumbar el Home.
  Future<List<ContentSports>> fetchLiveEvents() async {
    try {
      final res = await _dio.get<String>('$baseUrl$_livePath');
      final html = res.data ?? '';
      if (html.isEmpty) return const [];
      return parseLiveEventsHtml(html);
    } catch (e) {
      debugPrint('[LacanchaEvents] fetchLiveEvents error: $e');
      return const [];
    }
  }

  /// Parsea el HTML del home de eventos en vivo a [ContentSports].
  ///
  /// Es una función pura (sin red) para poder testearla con un HTML fijo.
  /// Cada tarjeta `hub-card` enlaza a `/es/ver/<id>` y trae su metadata.
  static List<ContentSports> parseLiveEventsHtml(String html) {
    final events = <ContentSports>[];

    // Límite del bloque de eventos: tras las tarjetas de eventos viene la
    // sección "Canales 24/7", cuyas tarjetas NO son eventos.
    final cutoff = html.indexOf('Canales 24/7');
    final limit = cutoff > 0 ? cutoff : html.length;

    // Segmentar por posición de cada tarjeta: desde cada `hub-card` que
    // enlaza a `/es/ver/<id>` hasta la siguiente (o hasta el límite).
    final startRe = RegExp(r'class="hub-card"\s+href="/es/ver/(\d+)"');
    final starts = startRe.allMatches(html).where((m) => m.start < limit).toList();

    for (var i = 0; i < starts.length; i++) {
      final id = starts[i].group(1)!;
      final blockStart = starts[i].end;
      final nextStart =
          (i + 1 < starts.length) ? starts[i + 1].start : limit;
      final blockEnd = nextStart > blockStart
          ? (nextStart < limit ? nextStart : limit)
          : limit;
      final block = html.substring(blockStart, blockEnd);

      final title = _firstMatch(block, r'class="hub-name"[^>]*>([^<]+)<');
      if (title == null || title.trim().isEmpty) continue;

      final league = _firstMatch(block, r'class="hub-league"[^>]*>([^<]+)<');
      final sportLabel = _extractSport(block);
      final thumb = _firstMatch(
          block, r'background-image:url\(&quot;(https://[^&]+)&quot;\)');
      final serversText = _firstMatch(block, r'class="hub-servers"[^>]*>([^<]+)');
      final isLive = block.contains('class="hub-live"');
      final servers = _parseInt(serversText);

      // Colores de acento del gradiente del fondo (equipo/home-away).
      final colors = _extractColors(block);

      final teams = _splitTeams(title);

      events.add(ContentSports(
        id: id,
        title: _cleanText(title),
        sport: _sportKey(sportLabel),
        sportLabel: sportLabel,
        league: league != null ? _cleanText(league) : null,
        teams: teams,
        // Los streams concretos se resuelven en la fase de reproducción; aquí
        // dejamos un canal marcador con el id para saber cuántos hay.
        channels: List.generate(
          servers ?? 0,
          (i) => <String, dynamic>{'name': 'Servidor ${i + 1}', 'url': ''},
        ),
        posterUrl: thumb ?? '',
        bannerUrl: thumb ?? '',
        colors: colors,
        viewers: 0,
        isLive: isLive,
        alwaysLive: false,
        status: isLive ? 'EN VIVO' : 'PRÓXIMO',
        source: 'ppv',
      ));
    }

    return events;
  }

  // ---------------------------------------------------------------------------
  // Detalle de evento (`/es/ver/<id>`): servidores reales (embed_url)
  // ---------------------------------------------------------------------------

  /// Descarga la página de detalle de un evento y extrae sus servidores.
  ///
  /// La página `/es/ver/<id>` embebe en el payload RSC de Next.js el objeto
  /// del partido con `streams[]` (cada uno con `embed_url`, el iframe del
  /// stream de terceros). Devuelve el [ContentSports] con `channels` reales,
  /// o `null` si falla la red o el HTML no tiene el objeto.
  Future<ContentSports?> fetchEventDetail(String id) async {
    try {
      final res = await _dio.get<String>('$baseUrl/es/ver/$id');
      final html = res.data ?? '';
      if (html.isEmpty) return null;
      return parseEventDetailHtml(html, id);
    } catch (e) {
      debugPrint('[LacanchaEvents] fetchEventDetail($id) error: $e');
      return null;
    }
  }

  /// Extrae el objeto de evento del payload RSC de la página de detalle.
  ///
  /// Función pura (sin red) para testear con HTML fijo. El objeto se ancla en
  /// `{"match":…}` (props del componente del partido) y de ahí salen `title`,
  /// `league`, `match.home_team/away_team/kickoff_at/status` y `streams[]`.
  static ContentSports? parseEventDetailHtml(String html, String id) {
    final flight = _concatFlightStrings(html);
    final props = _extractEventProps(flight);
    if (props == null) return null;

    final match = props['match'] is Map
        ? Map<String, dynamic>.from(props['match'] as Map)
        : <String, dynamic>{};
    final rawStreams = props['streams'];
    final streams = rawStreams is List ? rawStreams.whereType<Map>().toList() : <Map>[];

    // Servidores reales: embed_url + el origen del embed (Referer necesario
    // para que el CDN del m3u8 acepte la petición del reproductor).
    final channels = streams.map((s) {
      final embedUrl = s['embed_url']?.toString() ?? '';
      return <String, dynamic>{
        'name': s['embed_name']?.toString() ??
            s['channel']?['name']?.toString() ??
            'Servidor',
        'url': embedUrl,
        'embed_url': embedUrl,
        'referer': _originOf(embedUrl),
      };
    }).toList();

    final homeTeam = match['home_team']?.toString();
    final awayTeam = match['away_team']?.toString();
    final title = props['title']?.toString() ??
        ((homeTeam != null && awayTeam != null) ? '$homeTeam vs. $awayTeam' : null);
    final league = props['league']?.toString() ?? match['competition']?.toString();
    final isLive = match['status']?.toString() == 'live';

    return ContentSports(
      id: id,
      title: title ?? 'Evento deportivo',
      sportLabel: league,
      league: league,
      teams: [
        if (homeTeam != null) homeTeam,
        if (awayTeam != null) awayTeam,
      ],
      channels: channels,
      posterUrl: '',
      bannerUrl: '',
      viewers: 0,
      isLive: isLive,
      alwaysLive: false,
      status: isLive ? 'EN VIVO' : 'PRÓXIMO',
      startsAt: match['kickoff_at']?.toString(),
      source: 'ppv',
    );
  }

  /// Concatena los strings del flight data de Next.js (`self.__next_f.push`)
  /// en un solo texto, des escapando los caracteres de cadena JS.
  static String _concatFlightStrings(String html) {
    const marker = 'self.__next_f.push([1,"';
    final out = StringBuffer();
    var idx = html.indexOf(marker);
    while (idx != -1) {
      var i = idx + marker.length;
      final chunk = StringBuffer();
      while (i < html.length) {
        final c = html[i];
        if (c == '\\' && i + 1 < html.length) {
          chunk.write(c);
          chunk.write(html[i + 1]);
          i += 2;
          continue;
        }
        if (c == '"') break; // fin del string JS
        chunk.write(c);
        i++;
      }
      out.write(_unescapeJs(chunk.toString()));
      idx = html.indexOf(marker, i);
    }
    return out.toString();
  }

  /// Des-escapa un string JS (`\"`, `\\`, `\n`, `\u00xx`, …) una sola vez.
  static String _unescapeJs(String s) {
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c != '\\' || i + 1 >= s.length) {
        b.write(c);
        continue;
      }
      final n = s[++i];
      switch (n) {
        case 'n':
          b.write('\n');
          break;
        case 'r':
          b.write('\r');
          break;
        case 't':
          b.write('\t');
          break;
        case 'b':
          b.write('\b');
          break;
        case 'f':
          b.write('\f');
          break;
        case 'u':
          if (i + 4 < s.length) {
            final code = int.tryParse(s.substring(i + 1, i + 5), radix: 16);
            if (code != null) {
              b.writeCharCode(code);
              i += 4;
              break;
            }
          }
          b.write(n);
          break;
        default:
          b.write(n); // \" \\ \/ etc.
      }
    }
    return b.toString();
  }

  /// Localiza el objeto `{"match":…}` en el flight data y lo devuelve parseado.
  static Map<String, dynamic>? _extractEventProps(String flight) {
    const anchor = '{"match":';
    final start = flight.indexOf(anchor);
    if (start < 0) return null;
    final obj = _balancedSubstring(flight, start, '{', '}');
    if (obj == null) return null;
    try {
      final decoded = jsonDecode(obj);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Subcadena balanceada respetando strings y escapes desde `start`.
  static String? _balancedSubstring(String s, int start, String open, String close) {
    var depth = 0;
    var inStr = false;
    var esc = false;
    for (var i = start; i < s.length; i++) {
      final c = s[i];
      if (inStr) {
        if (esc) {
          esc = false;
        } else if (c == '\\') {
          esc = true;
        } else if (c == '"') {
          inStr = false;
        }
        continue;
      }
      if (c == '"') {
        inStr = true;
      } else if (c == open) {
        depth++;
      } else if (c == close) {
        depth--;
        if (depth == 0) return s.substring(start, i + 1);
      }
    }
    return null;
  }

  /// Origen (esquema+host[+puerto]) de una URL, para usar como Referer.
  static String _originOf(String url) {
    try {
      final u = Uri.parse(url);
      return u.origin;
    } catch (_) {
      return '';
    }
  }

  static String? _firstMatch(String input, String pattern) {
    final m = RegExp(pattern).firstMatch(input);
    return m?.group(1);
  }

  /// El bloque `hub-sport` contiene un `<svg>…</svg>` seguido del label.
  static String? _extractSport(String block) {
    final m = RegExp(r'class="hub-sport"[^>]*>(.*?)</span>', dotAll: true)
        .firstMatch(block);
    if (m == null) return null;
    final inner = m.group(1)!;
    // Quitar el SVG y quedarse con el texto final.
    final text = inner.replaceAll(RegExp(r'<svg.*?</svg>', dotAll: true), '');
    final cleaned = _cleanText(text);
    return cleaned.isEmpty ? null : cleaned;
  }

  /// Extrae los colores `#rrggbb` del gradiente de fondo de la tarjeta.
  static List<String>? _extractColors(String block) {
    final matches =
        RegExp(r'linear-gradient\(135deg,\s*(#[0-9a-fA-F]{6}),\s*(#[0-9a-fA-F]{6})\)')
            .firstMatch(block);
    if (matches == null) return null;
    return [matches.group(1)!, matches.group(2)!];
  }

  /// "A vs. B" -> ["A", "B"]. Si no hay "vs", devuelve lista vacía.
  static List<String> _splitTeams(String title) {
    final parts = title.split(RegExp(r'\s+vs\.?\s+', caseSensitive: false));
    if (parts.length >= 2) {
      return [parts[0].trim(), parts.sublist(1).join(' vs ').trim()];
    }
    return const [];
  }

  /// Etiqueta visible -> key normalizada ('futbol', 'basket', …).
  static String? _sportKey(String? label) {
    if (label == null) return null;
    final l = label.toLowerCase();
    if (l.contains('futbol') || l.contains('fútbol') || l.contains('soccer')) {
      return 'futbol';
    }
    if (l.contains('basket')) return 'basket';
    if (l.contains('nfl') || l.contains('fútbol am') || l.contains('american')) {
      return 'nfl';
    }
    if (l.contains('beisbol') || l.contains('béisbol') || l.contains('mlb')) {
      return 'beisbol';
    }
    if (l.contains('hockey') || l.contains('nhl')) return 'hockey';
    if (l.contains('tenis')) return 'tenis';
    return l;
  }

  static int? _parseInt(String? raw) {
    if (raw == null) return null;
    final m = RegExp(r'(\d+)').firstMatch(raw);
    return m != null ? int.tryParse(m.group(1)!) : null;
  }

  /// Normaliza entidades HTML, comentarios y espacios sobrantes del texto.
  static String _cleanText(String s) {
    return s
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&#x27;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
