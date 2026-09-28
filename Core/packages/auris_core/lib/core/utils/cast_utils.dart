import '../../data/models/server/episodes_response.dart';
import '../../data/models/server/anime_detail.dart';
import '../../data/models/server/movie_detail.dart';

/// Mezcla el cast del servidor (/api/cast, TMDB) con el del detalle:
/// - Primero el del servidor y MovieDetail (traen ID de TMDB).
/// - Luego personajes de AnimeDetail (seiyuu + best-effort sin seiyuu).
/// En duplicado por nombre gana el que tenga ID (TMDB). Antes se
/// reemplazaba: si el servidor traía algo, los characters se perdían.
String _normName(String s) => s.toLowerCase().trim();

List<CastInfo> mergeDetailCast(dynamic detailData, List<CastInfo> serverCast) {
  final Map<String, CastInfo> merged = {};

  void put(CastInfo c) {
    final key = _normName(c.name);
    if (key.isEmpty) return;
    final prev = merged[key];
    if (prev == null) {
      merged[key] = c;
    } else if (prev.id == null && c.id != null) {
      merged[key] = c;
    }
  }

  for (final c in serverCast) {
    put(c);
  }

  // 1. Cast de Películas/Series (TMDB) del propio detalle.
  if (detailData is MovieDetail) {
    for (final c in detailData.cast) {
      put(CastInfo(
        id: c.id,
        name: c.name,
        character: c.character,
        profile: c.profile,
      ));
    }
  }

  // 2. Anime (AniList): los seiyuu son las personas del cast; sin seiyuu se
  // muestra el personaje (best-effort por nombre).
  if (detailData is AnimeDetail) {
    for (final ch in detailData.characters) {
      if (ch.voiceActors.isNotEmpty) {
        for (final va in ch.voiceActors) {
          if (va.name.isEmpty) continue;
          put(CastInfo(
            name: va.name,
            character: ch.name,
            profile: va.image ?? ch.image,
          ));
        }
      } else {
        put(CastInfo(
          name: ch.name,
          character: ch.role,
          profile: ch.image,
        ));
      }
    }
  }

  return merged.values.toList();
}
