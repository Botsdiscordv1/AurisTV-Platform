import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/playback_history.dart';
import '../models/favorite_item.dart';
import '../models/media_item.dart';
import '../models/server/search_result.dart';
import '../../core/utils/category_utils.dart';
import '../../core/utils/string_utils.dart';
import '../../core/utils/source_utils.dart';
import 'playback_history_provider.dart';
import 'community_translation_provider.dart';

/// Lógica de Biblioteca centralizada (las 3 apps solo conectan UI).
///
/// - [contentHistoryProvider]: historial agrupado por CONTENIDO (una tarjeta
///   por obra: ver Dara-san ep7 guarda "Dara-san", no el episodio), ordenado
///   por último visionado. Incluye terminados (a diferencia de continuar viendo).
/// - Helpers puros de display (antes duplicados en Movil/TV/Web).
/// - [historyToSeed]: SearchResult seed para abrir el detalle desde historial
///   (antes duplicado 6× en los taps).
/// - [filterLibraryFavorites]: filtro por categoría de Mi Lista.

// ── Historial agrupado ──

/// Agrupa por contenido (contentId ya es por-obra; temporada/episodio van
/// aparte) quedándose con la entrada más reciente de cada obra.
List<PlaybackHistory> groupHistoryByContent(List<PlaybackHistory> histories) {
  final Map<String, PlaybackHistory> byContent = {};
  for (final h in histories) {
    final prev = byContent[h.contentId];
    if (prev == null || h.updatedAt.isAfter(prev.updatedAt)) {
      byContent[h.contentId] = h;
    }
  }
  final list = byContent.values.toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return list;
}

/// Todas las reproducciones agrupadas por contenido (incluye terminados).
final contentHistoryProvider =
    Provider<AsyncValue<List<PlaybackHistory>>>((ref) {
  return ref.watch(playbackHistoryStateProvider).whenData(groupHistoryByContent);
});

/// Entradas (por episodio) de un contenido dentro del historial completo.
List<PlaybackHistory> historyEntriesForContent(
    List<PlaybackHistory> histories, String contentId) {
  return histories.where((h) => h.contentId == contentId).toList();
}

// ── Display (antes inline en cada app) ──

bool libraryIsMovieish(PlaybackHistory h) =>
    isMovieLike(h.category, h.title, h.durationInMilliseconds);

/// Título para tarjeta: limpia "Ep N •" en pelis. En series NO se antepone
/// "Ep X" (ya va en el subtítulo "T1:E7 . Título" o "T2 E7 • ...").
String libraryDisplayTitle(PlaybackHistory h) {
  final displayTitle = h.title ?? 'Contenido';
  if (libraryIsMovieish(h)) {
    return displayTitle
        .replaceAll(RegExp(r'^[Ee]p\s*\d+\s*[\.\-\•]\s*'), '')
        .trim();
  }
  return displayTitle;
}

/// "Quedan X" o '' si no queda nada. Con [colon] → "Quedan: X"
/// (formato de la 2ª línea de Continuar Viendo).
String libraryRemainingText(PlaybackHistory h, {bool colon = false}) {
  final remainingMs = h.durationInMilliseconds - h.positionInMilliseconds;
  if (remainingMs <= 0) return '';
  final prefix = colon ? 'Quedan: ' : 'Quedan ';
  return '$prefix${AurisStringUtils.formatRemainingTime(remainingMs)}';
}

/// Subtítulo para la sección Historial: contexto del último visionado
/// (ej. "T2 E7 • Quedan 12 min", "Quedan 1 h", "Vista").
String libraryHistorySubtitle(PlaybackHistory h) {
  final parts = <String>[];
  if (!libraryIsMovieish(h) && h.episode != null && h.episode!.isNotEmpty) {
    final seasonPart =
        (h.season != null && h.season! > 1) ? 'T${h.season} ' : '';
    parts.add('$seasonPart E${h.episode}');
  }
  final remaining = libraryRemainingText(h);
  if (remaining.isNotEmpty) {
    parts.add(remaining);
  } else if (parts.isEmpty) {
    parts.add('Vista');
  }
  return parts.join(' • ');
}

/// Imagen para tarjeta wide (backdrop con fallback a poster).
String libraryCardImage(PlaybackHistory h) =>
    h.bannerUrl ?? h.posterUrl ?? '';

// ── Navegación (seed centralizado) ──

/// Seed para abrir el detalle desde una entrada del historial.
/// Retorna null si no hay URL http real (el llamador abre sin seed y el
/// discovery reconstruye las fuentes; sembrar un título rompería /episodes).
SearchResult? historyToSeed(PlaybackHistory h) {
  final p = h.toUnifiedDetailParams();
  final seedUrl = h.url ?? h.contentId;
  if (!isHttpUrl(seedUrl)) return null;
  return SearchResult(
    title: h.title ?? p.title,
    url: seedUrl,
    quality: '',
    thumbnail: h.posterUrl ?? '',
    source: h.source ?? p.source,
    kind: h.kind ?? p.kind,
    type: h.type ?? p.type,
    year: h.year ?? p.year,
    metadataTitle: h.metadataTitle ?? p.metadataTitle,
    season: h.season ?? p.season,
  );
}

/// Subtítulo de Continuar Viendo en 2 líneas (no-películas):
/// line1 = "T1:E7 . Título del episodio" (o "T1:E7" sin título / genérico),
/// line2 = "Quedan X" (o null). Películas y sin episodio → (remaining, null).
({String line1, String? line2}) continueCardSubtitle(PlaybackHistory h) {
  final remaining = libraryRemainingText(h);
  if (libraryIsMovieish(h)) return (line1: remaining, line2: null);
  if (h.episode == null || h.episode!.isEmpty) {
    return (line1: remaining, line2: null);
  }
  final season = h.season ?? 1;
  final ep = h.episode!;
  final rawTitle = (h.episodeTitle ?? '').trim();
  // Un genérico guardado ("Episodio 1") equivale a sin título.
  final epTitle = CommunityTranslationManager.isGenericTitle(rawTitle) ? '' : rawTitle;
  final line1 =
      epTitle.isNotEmpty ? 'T$season:E$ep . $epTitle' : 'T$season:E$ep';
  final remaining2 = libraryRemainingText(h, colon: true);
  return (line1: line1, line2: remaining2.isNotEmpty ? remaining2 : null);
}

// ── Mi Lista ──

/// Aplana SearchResults (con `sources` anidadas o simples) a SourceItems
/// únicos. Para guardar en favoritos lo que search/home ya traían.
List<SourceItem> flattenSources(List<SearchResult> results) {
  final out = <SourceItem>[];
  final seen = <String>{};
  for (final r in results) {
    final items = r.sources.isNotEmpty
        ? r.sources
        : [
            SourceItem(
                source: r.source,
                url: r.url,
                quality: r.quality,
                slug: r.slug,
                type: r.type)
          ];
    for (final s in items) {
      if (s.source.isEmpty || s.url.isEmpty) continue;
      if (seen.add('${s.source}|${s.url}')) out.add(s);
    }
  }
  return out;
}

/// Constructor centralizado de FavoriteItem (antes copiado en cada detalle).
FavoriteItem buildFavoriteItem({
  required String id,
  required String title,
  String posterUrl = '',
  String bannerUrl = '',
  String category = '',
  String source = '',
  String url = '',
  String? kind,
  int? year,
  String? type,
  int? season,
  List<SourceItem> sources = const [],
  required String profileId,
}) =>
    FavoriteItem(
      id: id,
      title: title,
      posterUrl: posterUrl,
      bannerUrl: bannerUrl,
      category: category,
      source: source,
      url: url,
      addedAt: DateTime.now(),
      profileId: profileId,
      kind: kind,
      year: year,
      type: type,
      season: season,
      sources: sources,
    );

/// FavoriteItem desde una entrada del historial.
FavoriteItem favoriteFromHistory(PlaybackHistory h, String profileId) =>
    buildFavoriteItem(
      id: h.contentId,
      title: h.title ?? 'Contenido',
      posterUrl: h.posterUrl ?? '',
      bannerUrl: h.bannerUrl ?? '',
      category: h.category ?? '',
      source: h.source ?? '',
      url: h.url ?? h.contentId,
      kind: h.kind,
      year: h.year,
      type: h.type,
      season: h.season,
      sources: flattenSources(h.alternativeSources ?? const []),
      profileId: profileId,
    );

/// FavoriteItem desde un MediaItem (top10, secciones, etc.).
FavoriteItem favoriteFromMedia(MediaItem m, String profileId) =>
    buildFavoriteItem(
      id: m.id,
      title: m.title,
      posterUrl: m.posterUrl,
      bannerUrl: m.bannerUrl ?? '',
      category: m.type.name,
      source: m.source,
      url: m.detailUrl ?? m.id,
      kind: m.card?.kind ?? m.type.name,
      year: m.year,
      type: m.card?.type ?? m.type.name,
      sources: m.card != null ? flattenSources([m.card!]) : const [],
      profileId: profileId,
    );

/// Seed para abrir el detalle desde un favorito (null si no hay URL http).
/// Lleva la lista completa guardada → paridad con abrir desde search/home.
SearchResult? seedFromFavorite(FavoriteItem f) {
  if (!isHttpUrl(f.url)) return null;
  return SearchResult(
    title: f.title,
    url: f.url,
    quality: '',
    thumbnail: f.posterUrl,
    source: f.source,
    kind: f.kind,
    type: f.type,
    year: f.year,
    season: f.season,
    sources: f.sources,
  );
}

/// Filtro por categoría de favoritos (hints antes duplicados por app).
List<FavoriteItem> filterLibraryFavorites(
    List<FavoriteItem> favorites, String filter) {
  if (filter == 'todos') return favorites;
  const kdramaHints = ['tudorama', 'doramasyt', 'doramasmp4', 'pandrama'];
  const animeHints = [
    'jkanime',
    'animeav1',
    'aniyae',
    'animelatino',
    'fiuzidragon',
    'animed23',
    'animejara',
    'katanime',
    'animegratis'
  ];
  const movieHints = ['gnula', 'gnulahd'];
  return favorites.where((f) {
    final source = f.source.toLowerCase();
    final cat = f.category.toLowerCase();
    if (filter == 'kdrama') return kdramaHints.any(source.contains);
    if (filter == 'anime') {
      return animeHints.any(source.contains) ||
          (movieHints.any(source.contains) && cat.contains('anime'));
    }
    if (filter == 'peliculas') {
      return (cat.contains('movie') ||
              cat.contains('pelicula') ||
              movieHints.any(source.contains)) &&
          !cat.contains('anime');
    }
    if (filter == 'series') return cat.contains('serie') || cat.contains('tv');
    return false;
  }).toList();
}
