import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../data/models/server/extract_result.dart';

/// Servicio de utilidad para parsear y resolver variantes de calidad
/// directamente desde un manifiesto HLS (.m3u8).
///
/// Permite que el frontend sea el encargado de extraer y ofrecer las variantes
/// de calidad (1080p, 720p, 480p, 360p, etc.) sin que el backend tenga que
/// realizar llamadas lentas para inspeccionar el archivo.
class HlsVariantParser {
  HlsVariantParser._();

  static final RegExp _streamInfRegex = RegExp(r'#EXT-X-STREAM-INF:(.*)', caseSensitive: false);
  static final RegExp _resolutionRegex = RegExp(r'RESOLUTION=(\d+)x(\d+)', caseSensitive: false);
  static final RegExp _bandwidthRegex = RegExp(r'BANDWIDTH=(\d+)', caseSensitive: false);
  static final RegExp _nameQualityRegex = RegExp(r'(?:NAME|QUALITY)="?([^",]+)"?', caseSensitive: false);

  /// Comprueba si la URL apunta a un stream HLS.
  static bool isHlsUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final clean = url.toLowerCase();
    return clean.contains('.m3u8') || clean.contains('/api/hls/');
  }

  /// Descarga y parsea un archivo master .m3u8 extrayendo la lista de [QualityOption].
  ///
  /// Retorna una lista vacía si el archivo no es un master multibitrate
  /// (por ejemplo, si es una media playlist con sólo segmentos .ts).
  static Future<List<QualityOption>> parseFromUrl(
    String masterUrl, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (!isHlsUrl(masterUrl)) return const [];

    try {
      final uri = Uri.parse(masterUrl);
      final response = await http.get(uri, headers: headers).timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return parse(response.body, masterUrl: masterUrl, headers: headers);
      }
    } catch (_) {
      // Ignorar errores de red y continuar con fallback
    }

    return const [];
  }

  /// Parsea el contenido en texto de un master playlist HLS.
  static List<QualityOption> parse(
    String manifestContent, {
    required String masterUrl,
    Map<String, String>? headers,
  }) {
    if (!manifestContent.contains('#EXT-X-STREAM-INF')) {
      return const [];
    }

    final lines = LineSplitter.split(manifestContent).toList();
    final List<QualityOption> variants = [];
    final Uri masterUri = Uri.parse(masterUrl);

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final streamMatch = _streamInfRegex.firstMatch(line);
      if (streamMatch == null) continue;

      final meta = streamMatch.group(1) ?? '';

      // Extraer RESOLUTION
      int? height;
      final resMatch = _resolutionRegex.firstMatch(meta);
      if (resMatch != null) {
        height = int.tryParse(resMatch.group(2) ?? '');
      }

      // Extraer BANDWIDTH
      int? bandwidth;
      final bwMatch = _bandwidthRegex.firstMatch(meta);
      if (bwMatch != null) {
        bandwidth = int.tryParse(bwMatch.group(1) ?? '');
      }

      // Extraer nombre de calidad o generar a partir de la resolución
      String label = '';
      final nameMatch = _nameQualityRegex.firstMatch(meta);
      if (nameMatch != null) {
        label = nameMatch.group(1) ?? '';
      }

      // La siguiente línea no comentada ni vacía es la URL relativa o absoluta
      String variantUri = '';
      for (int j = i + 1; j < lines.length; j++) {
        final nextLine = lines[j].trim();
        if (nextLine.isNotEmpty && !nextLine.startsWith('#')) {
          variantUri = nextLine;
          i = j; // Avanzar el cursor
          break;
        }
      }

      if (variantUri.isEmpty) continue;

      // Resolver URL absoluta respecto al masterUrl
      final resolvedUrl = masterUri.resolve(variantUri).toString();

      // Formatear label adecuada si no vino en el manifiesto
      if (height != null && height > 0) {
        label = '${height}p';
      } else if (label.isEmpty) {
        if (bandwidth != null) {
          final kbps = (bandwidth / 1000).round();
          label = '$kbps Kbps';
        } else {
          label = 'Calidad ${variants.length + 1}';
        }
      } else if (!label.toLowerCase().endsWith('p') && int.tryParse(label) != null) {
        label = '${label}p';
      }

      final key = height != null && height > 0 ? height.toString() : label.toLowerCase().replaceAll(' ', '_');

      variants.add(
        QualityOption(
          key: key,
          label: label,
          url: resolvedUrl,
          height: height,
          bandwidth: bandwidth,
          headers: headers ?? const {},
        ),
      );
    }

    // Ordenar de mayor a menor calidad (1080p -> 720p -> 480p...)
    variants.sort((a, b) {
      final hA = a.height ?? 0;
      final hB = b.height ?? 0;
      if (hA != hB) return hB.compareTo(hA);
      return (b.bandwidth ?? 0).compareTo(a.bandwidth ?? 0);
    });

    // Deduplicar por key si hubieran variantes idénticas
    final unique = <String, QualityOption>{};
    for (final v in variants) {
      if (!unique.containsKey(v.key)) {
        unique[v.key] = v;
      }
    }

    return unique.values.toList();
  }
}
