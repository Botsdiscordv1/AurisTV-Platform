import '../../data/models/playlist_channel.dart';

/// Parser M3U/M3U8 mínimo y tolerante para listas de canales IPTV.
///
/// Acepta el formato `#EXTM3U` + `#EXTINF:<dur> attr="valor",Nombre` seguido
/// de la URL del stream. Ignora comentarios y directivas desconocidas
/// (`#EXTVLCOPT`, `#KODIPROP`, ...); `#EXTGRP` se usa como grupo de reserva.
class M3uParser {
  M3uParser._();

  static final RegExp _attrPattern =
      RegExp(r'([A-Za-z0-9_-]+)\s*=\s*"([^"]*)"');

  /// Extrae los canales de [content]. Nunca lanza: las líneas mal formadas se
  /// descartan. Devuelve una lista vacía si no hay ni una URL válida.
  static List<PlaylistChannel> parse(String content) {
    final channels = <PlaylistChannel>[];

    String? title;
    String? logo;
    String? group;
    String? tvgId;

    for (final rawLine in content.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF')) {
        // Reset de metadatos de la entrada anterior.
        title = null;
        logo = null;
        group = null;
        tvgId = null;

        final attributes = _splitAttributesAndTitle(line);
        title = attributes.$2;
        for (final match in _attrPattern.allMatches(attributes.$1)) {
          final key = match.group(1)!.toLowerCase();
          final value = match.group(2) ?? '';
          if (value.isEmpty) continue;
          switch (key) {
            case 'tvg-logo':
              logo = value;
            case 'group-title':
              group = value;
            case 'tvg-id':
              tvgId = value;
            case 'tvg-name':
              title ??= value;
          }
        }
        continue;
      }

      if (line.startsWith('#EXTGRP:')) {
        group = line.substring('#EXTGRP:'.length).trim();
        continue;
      }

      if (line.startsWith('#')) continue;

      // Línea de URL: cierra la entrada en curso (si la hay).
      if (_isHttpUrl(line)) {
        final name = (title ?? '').trim();
        channels.add(PlaylistChannel(
          title: name.isEmpty ? 'Canal ${channels.length + 1}' : name,
          url: line,
          logo: logo,
          group: (group ?? '').trim().isEmpty ? null : group!.trim(),
          tvgId: (tvgId ?? '').trim().isEmpty ? null : tvgId!.trim(),
        ));
      }
      title = null;
      logo = null;
      group = null;
      tvgId = null;
    }

    return channels;
  }

  /// Identificador estable, corto y URI-safe de una URL de stream (djb2 hex).
  ///
  /// Se usa como `contentId` del player: mismo canal => mismo id en cualquier
  /// plataforma (no depende de `String.hashCode`, que no es portable).
  static String stableId(String input) {
    var hash = 5381;
    for (final unit in input.codeUnits) {
      hash = ((hash << 5) + hash + unit) & 0x7fffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static bool _isHttpUrl(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  /// Divide una línea `#EXTINF:... ,Nombre` respetando las comillas.
  ///
  /// Devuelve (parte de atributos, nombre). El nombre es todo lo que va
  /// después de la primera coma fuera de comillas.
  static (String, String?) _splitAttributesAndTitle(String line) {
    bool inQuote = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuote = !inQuote;
      } else if (ch == ',' && !inQuote) {
        final attributes = line.substring(0, i);
        final name = line.substring(i + 1).trim();
        return (attributes, name.isEmpty ? null : name);
      }
    }
    // Sin coma: solo atributos (nombre ausente).
    return (line, null);
  }
}
