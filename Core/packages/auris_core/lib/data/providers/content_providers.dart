import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../auris_core.dart';
import '../../core/utils/content_logic.dart';
import '../../core/utils/source_utils.dart';

// --- Params Classes ---

class OmdbSeasonParams {
  final String title;
  final int? season;
  const OmdbSeasonParams({required this.title, this.season});
  @override bool operator ==(Object other) => identical(this, other) || other is OmdbSeasonParams && title == other.title && season == other.season;
  @override int get hashCode => Object.hash(title, season);
}

class ContentSearchParams {
  final String query; final String category; final int? year; final String? server;
  const ContentSearchParams({required this.query, required this.category, this.year, this.server});
  @override bool operator ==(Object other) => identical(this, other) || other is ContentSearchParams && query == other.query && category == other.category && year == other.year && server == other.server;
  @override int get hashCode => Object.hash(query, category, year, server);
}

class GalleryParams {
  final String kind;
  final String? title;
  final int? year;
  const GalleryParams({required this.kind, this.title, this.year});
  @override bool operator ==(Object other) => identical(this, other) || other is GalleryParams && kind == other.kind && title == other.title && year == other.year;
  @override int get hashCode => Object.hash(kind, title, year);
}

class DiscoveredSourcesParams {
  final String title;
  final String? metadataTitle;
  final String category;
  final int? year;
  final int? season;
  final String? server;
  final List<SearchResult>? initialSources;

  const DiscoveredSourcesParams({
    required this.title,
    this.metadataTitle,
    this.category = 'all',
    this.year,
    this.season,
    this.server,
    this.initialSources,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredSourcesParams &&
          title == other.title &&
          metadataTitle == other.metadataTitle &&
          category == other.category &&
          year == other.year &&
          season == other.season &&
          server == other.server &&
          const ListEquality<SearchResult>().equals(initialSources, other.initialSources);

  @override
  int get hashCode => Object.hash(title, metadataTitle, category, year, season, server, const ListEquality<SearchResult>().hash(initialSources));
}

class GroupedEpisodesParams {
  final String title;
  final String? metadataTitle;
  final String category;
  final int? year;
  final int? season;
  final int? tmdbId;
  final String familyKey;
  final String currentSourceUrl;
  final List<SearchResult> sources;

  const GroupedEpisodesParams({
    required this.title,
    this.metadataTitle,
    required this.category,
    this.year,
    this.season,
    this.tmdbId,
    required this.familyKey,
    required this.currentSourceUrl,
    required this.sources,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupedEpisodesParams &&
          title == other.title &&
          metadataTitle == other.metadataTitle &&
          category == other.category &&
          year == other.year &&
          season == other.season &&
          tmdbId == other.tmdbId &&
          familyKey == other.familyKey &&
          currentSourceUrl == other.currentSourceUrl &&
          _signature == other._signature;

  @override
  int get hashCode => Object.hash(title, metadataTitle, category, year, season, tmdbId, familyKey, currentSourceUrl, _signature);

  String get _signature => sources.map(sourceSignature).join('||');
}

class GroupedEpisodesResult {
  final EpisodesResponse response;
  final List<SearchResult?> sources;
  const GroupedEpisodesResult({required this.response, required this.sources});
  SearchResult? sourceForNumber(int number) {
    for (var i = 0; i < response.episodes.length; i++) {
      if (response.episodes[i].number == number) return sources[i];
    }
    return null;
  }
  SearchResult? sourceForIndex(int index) {
    if (index >= 0 && index < sources.length) return sources[index];
    return null;
  }
}

// --- Providers ---

final omdbSeasonProvider = FutureProvider.family<List<OmdbEpisode>, OmdbSeasonParams>((ref, params) async {
  final repo = ref.watch(aurisRepositoryProvider);
  final title = params.title;
  final season = params.season;
  if (season != null && season > 0) {
    return repo.getOmdbSeason(title: title, season: season);
  }
  final romanMap = {'i': 1, 'ii': 2, 'iii': 3, 'iv': 4, 'v': 5, 'vi': 6, 'vii': 7, 'viii': 8, 'ix': 9, 'x': 10};
  int detectedSeason = 1;
  final t = title.toLowerCase();
  final patterns = [
    RegExp(r'\s(\d+)(?:st|nd|rd|th)?\s+season'),
    RegExp(r'season\s+(\d+)'),
    RegExp(r'\bs(\d{1,2})\b'),
    RegExp(r'\s+(ii|iii|iv|v|vi|vii|viii|ix|x)(?:\s*[:\u2013\-]|\s*$)', caseSensitive: false),
    RegExp(r'\s+(\d+)(?:st|nd|rd|th)?$'),
  ];
  for (final p in patterns) {
    final m = p.firstMatch(t);
    if (m != null) {
      final raw = m.group(1)!.toLowerCase();
      final parsed = romanMap[raw] ?? int.tryParse(raw);
      if (parsed != null && parsed > 0 && parsed < 30) { detectedSeason = parsed; break; }
    }
  }
  return repo.getOmdbSeason(title: title, season: detectedSeason);
});

final contentSearchProvider = FutureProvider.family<SearchResponse, ContentSearchParams>((ref, params) async {
  final repo = ref.watch(aurisRepositoryProvider);
  return repo.search(params.category, params.query, year: params.year, server: params.server);
});

final galleryProvider = FutureProvider.family<GalleryResponse, GalleryParams>((ref, params) async {
  final repo = ref.watch(aurisRepositoryProvider);
  return repo.getGallery(kind: params.kind, title: params.title, year: params.year);
});

class EpisodesParams {
  final String url; 
  final String source; 
  final String? title; 
  final String? fullTitle; 
  final String? altTitle; 
  final int? tmdbId; 
  final int? season; 
  final int? year;

  const EpisodesParams({
    required this.url, 
    required this.source, 
    this.title, 
    this.fullTitle, 
    this.altTitle, 
    this.tmdbId, 
    this.season, 
    this.year,
  });

  @override 
  bool operator ==(Object other) => 
    identical(this, other) || 
    other is EpisodesParams && 
    url == other.url && 
    source == other.source && 
    title == other.title && 
    fullTitle == other.fullTitle && 
    altTitle == other.altTitle && 
    tmdbId == other.tmdbId && 
    season == other.season && 
    year == other.year;

  @override 
  int get hashCode => Object.hash(url, source, title, fullTitle, altTitle, tmdbId, season, year);
}

final episodesProvider = FutureProvider.family<EpisodesResponse?, EpisodesParams>((ref, params) async {
  if (params.url.isEmpty) return null;
  final repo = ref.watch(aurisRepositoryProvider);
  return repo.getEpisodes(
    params.url, 
    params.source, 
    title: params.title, 
    fullTitle: params.fullTitle, 
    altTitle: params.altTitle, 
    tmdbId: params.tmdbId, 
    season: params.season, 
    year: params.year,
  );
});

final unifiedRelationsProvider = FutureProvider.family<Map<String, List<RelatedInfo>>, List<SearchResult>>((ref, sources) async {
  if (sources.isEmpty) return {};
  final repo = ref.read(aurisRepositoryProvider);
  final results = await Future.wait(sources.map((src) => repo.getEpisodes(src.url, src.source, category: 'anime').then<EpisodesResponse?>((v) => v).catchError((_) => null)));
  final List<RelatedInfo> allRelations = [];
  for (var res in results) {
    if (res != null && res.relations.isNotEmpty) {
      allRelations.addAll(res.relations);
    }
  }
  final Map<String, RelatedInfo> franchiseMap = {};
  final Map<String, RelatedInfo> genreMap = {};
  final Map<String, RelatedInfo> recommendedMap = {};
  for (var rel in allRelations) {
    final cleanTitle = rel.title.replaceAll(RegExp(r'\s*\([Ss]erie\)'), '').trim();
    final key = cleanTitle.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final type = rel.relation.toLowerCase();
    if (type.contains('precuela') || type.contains('secuela') || type.contains('historia') || type.contains('ova') || type.contains('película')) {
      if (!franchiseMap.containsKey(key)) franchiseMap[key] = rel;
    } else if (type.contains('género') || type.contains('similar') || type.contains('relacionado') || rel.url.contains('aniyae')) {
      if (!genreMap.containsKey(key)) genreMap[key] = rel;
    } else {
      if (!recommendedMap.containsKey(key)) recommendedMap[key] = rel;
    }
  }
  for (final key in franchiseMap.keys) {
    recommendedMap.remove(key);
    genreMap.remove(key);
  }
  for (final key in recommendedMap.keys) {
    genreMap.remove(key);
  }
  return {
    'franchise': franchiseMap.values.toList(),
    'genre': genreMap.values.toList(),
    'recommended': recommendedMap.values.toList(),
  };
});

final groupedEpisodesProvider = FutureProvider.family<GroupedEpisodesResult?, GroupedEpisodesParams>((ref, params) async {
  if (params.sources.isEmpty) return null;
  final repo = ref.watch(aurisRepositoryProvider);
  final familySourcesRaw = params.sources.where((s) => simplifySourceName(s.source) == params.familyKey).toList();
  if (familySourcesRaw.isEmpty) return null;
  int? _seasonInUrl(String u) {
    final m = RegExp(r'[-/#](\d{1,2})(?:st|nd|rd|th)?-?(?:season|temporada)', caseSensitive: false).firstMatch(u) ??
        RegExp(r'[-/#](?:season|temporada)-(\d{1,2})', caseSensitive: false).firstMatch(u);
    return m != null ? int.tryParse(m.group(1)!) : null;
  }
  // Evitar mezclar temporadas distintas de la misma familia (p.ej. la URL base
  // de S1 y la de S2) que viajan juntas en activeSources: solo fusionamos las
  // fuentes que corresponden a la temporada solicitada.
  final familySources = (params.season == null || params.season! <= 1)
      ? familySourcesRaw
      : familySourcesRaw.where((s) {
          final su = _seasonInUrl(s.url);
          return su == null || su == params.season;
        }).toList();
  final hasDubVariant = familySources.any((s) => isDubQuality(s.quality));
  final hasSubVariant = familySources.any((s) => s.quality.isNotEmpty && !isDubQuality(s.quality));
  final hasVariants = hasDubVariant && hasSubVariant;
  // Se consultan TODAS las fuentes provistas para que la "Temporada 0"
  // (especiales/OVAs) se agregue de cualquier servidor, no solo de la familia
  // del seleccionado. Los episodios se siguen fusionando únicamente dentro de la
  // familia activa; los especiales se fusionan de todas las fuentes.
  final results = await Future.wait(params.sources.map((src) {
    return repo.getEpisodes(src.url, src.source, category: params.category, title: params.title, fullTitle: params.metadataTitle, tmdbId: params.tmdbId, season: params.season, year: params.year).then<EpisodesResponse?>((v) => v).catchError((_) => null);
  }));
  final resBySource = <String, EpisodesResponse?>{};
  for (var i = 0; i < params.sources.length; i++) {
    resBySource[params.sources[i].url] = results[i];
  }
  EpisodesResponse? primary;
  final mergedByNumber = <int, (EpisodeInfo, SearchResult?)>{};
  final mergedRelations = <RelatedInfo>[];
  for (final src in familySources) {
    final res = resBySource[src.url];
    if (res == null) continue;
    primary ??= res;
    if (mergedRelations.isEmpty && res.relations.isNotEmpty) {
      mergedRelations.addAll(res.relations);
    }
    for (final ep in res.episodes) {
      final epQuality = ep.quality ?? src.quality;
      final isDub = isDubQuality(epQuality);
      final existing = mergedByNumber[ep.number];
      if (existing == null) {
        mergedByNumber[ep.number] = (ep, src);
      } else if (hasVariants && isDub) {
        final existingEp = existing.$1;
        final existingQuality = existingEp.quality ?? existing.$2?.quality ?? '';
        if (!isDubQuality(existingQuality)) {
          mergedByNumber[ep.number] = (ep, src);
        }
      }
    }
  }
  if (primary == null) return null;
  // Fusion de especiales entre fuentes: se agrupan por identidad real
  // (tmdbSpecialNumber si existe, si no numero + titulo normalizado) para no
  // mostrar duplicados cuando varios servidores aportan el mismo especial.
  // Se conserva la entrada mas completa (url y descripcion) por si la primera
  // carece de ellos; al abrirse se reproduce la fuente conservada y el usuario
  // puede cambiar de servidor desde el reproductor.
  final mergedSpecials = <EpisodeInfo>[];
  String specialKey(EpisodeInfo e) {
    final t = e.tmdbSpecialNumber;
    if (t != null && t > 0) return 'tmdb$t';
    return '${e.number}:${(e.title ?? '').trim().toLowerCase()}';
  }

  for (final src in params.sources) {
    final res = resBySource[src.url];
    if (res == null) continue;
    for (final sp in res.specials) {
      final key = specialKey(sp);
      final idx = mergedSpecials.indexWhere((e) => specialKey(e) == key);
      if (idx < 0) {
        mergedSpecials.add(sp);
      } else {
        final cur = mergedSpecials[idx];
        final curComplete = cur.url.isNotEmpty && (cur.description?.isNotEmpty ?? false);
        final spComplete = sp.url.isNotEmpty && (sp.description?.isNotEmpty ?? false);
        if (!curComplete && spComplete) mergedSpecials[idx] = sp;
      }
    }
  }
  mergedSpecials.sort((a, b) => (a.number).compareTo(b.number));
  final entries = mergedByNumber.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  final mergedList = [for (final e in entries) e.value.$1];
  final mergedSources = [for (final e in entries) e.value.$2];
  return GroupedEpisodesResult(
    response: EpisodesResponse(
      source: primary.source,
      url: primary.url,
      slug: primary.slug,
      total: mergedList.length,
      episodes: mergedList,
      specials: mergedSpecials,
      relations: mergedRelations.isNotEmpty ? mergedRelations : primary.relations,
      tmdbId: primary.tmdbId,
      season: primary.season,
      seasonAirDate: primary.seasonAirDate,
    ),
    sources: mergedSources,
  );
});

final discoveredSourcesProvider = Provider.family<List<SearchResult>, DiscoveredSourcesParams>((ref, params) {
  final searchQuery = params.metadataTitle ?? params.title;
  final searchAsync = ref.watch(contentSearchProvider(ContentSearchParams(query: searchQuery, category: params.category, year: params.year, server: params.server)));
  final baseSearchQuery = stripSeasonSuffix(searchQuery);
  final baseSearchAsync = (baseSearchQuery.isNotEmpty && baseSearchQuery != searchQuery)
      ? ref.watch(contentSearchProvider(ContentSearchParams(query: baseSearchQuery, category: params.category, year: params.year, server: params.server)))
      : null;
  final romanQuery = (params.season != null && params.season! > 1) ? seasonTitleRoman(stripSeasonSuffix(searchQuery), params.season!) : null;
  final romanSearchAsync = (romanQuery != null && romanQuery.toLowerCase() != searchQuery.toLowerCase())
      ? ref.watch(contentSearchProvider(ContentSearchParams(query: romanQuery, category: params.category, year: params.year, server: params.server)))
      : null;
  final isMovieCategory = params.category == 'movie' || params.category == 'movie_anime';
  final detailAsync = isMovieCategory ? const AsyncValue<AnimeDetail?>.data(null) : ref.watch(animeDetailProvider(AnimeDetailParams(title: params.title, metadataTitle: params.metadataTitle, year: params.year, season: params.season)));
  final searchData = searchAsync.valueOrNull;
  final detail = detailAsync.valueOrNull;
  final qBase = cleanTitleForMatching(params.title);
  final metaBase = params.metadataTitle != null ? cleanTitleForMatching(params.metadataTitle!) : null;
  final targetSeason = params.season ?? extractSeason(params.title) ?? extractSeason(params.metadataTitle);
  String coreTitle(String cleaned) => cleaned.replaceAll(RegExp(r'\d+$'), '');
  final familyBases = <String>{
    if (qBase.isNotEmpty) coreTitle(qBase),
    if (metaBase != null && metaBase.isNotEmpty) coreTitle(metaBase),
    if (detail != null) ...{
      if (detail.title.isNotEmpty) coreTitle(cleanTitleForMatching(detail.title)),
      if ((detail.titleEnglish?.isNotEmpty ?? false)) coreTitle(cleanTitleForMatching(detail.titleEnglish!)),
      if ((detail.titleJapanese?.isNotEmpty ?? false)) cleanTitleForMatching(detail.titleJapanese!),
    },
  }..removeWhere((e) => e.isEmpty);
  final List<SearchResult> searchSources = [];
  bool seasonMatches(SearchResult r) {
    if (isSeasonUnified(r.source) || r.sources.any((s) => isSeasonUnified(s.source))) return true;
    final rSeason = extractSeason(r.title) ?? extractSeason(r.romaji) ?? extractSeason(r.english);
    if (targetSeason != null) {
      if ((rSeason ?? 1) == targetSeason) return true;
      if (rSeason == null && r.totalSeasons != null && r.totalSeasons! >= targetSeason) return true;
      return false;
    }
    if (rSeason == null || rSeason <= 1) return true;
    if (r.year == null) return false;
    if (params.year == null) return true;
    return params.year == r.year;
  }
  bool yearMatches(SearchResult r) {
    if (params.season != null) return true;
    if (params.year == null || r.year == null) return true;
    return (params.year! - r.year!).abs() <= 1;
  }
  bool strictMatch(SearchResult r) {
    if (isSeasonUnified(r.source)) {
      final baseTitleClean = cleanTitleForMatching(stripSeasonSuffix(params.title));
      final metaTitleClean = params.metadataTitle != null ? cleanTitleForMatching(stripSeasonSuffix(params.metadataTitle!)) : null;
      final rClean = cleanTitleForMatching(r.title);
      final rRomajiClean = cleanTitleForMatching(r.romaji ?? '');
      return rClean == baseTitleClean || rRomajiClean == baseTitleClean || (metaTitleClean != null && (rClean == metaTitleClean || rRomajiClean == metaTitleClean));
    }
    final rClean = cleanTitleForMatching(r.title);
    final rRomajiClean = cleanTitleForMatching(r.romaji ?? '');
    return (rClean == qBase || rClean == metaBase) || (rRomajiClean == qBase || rRomajiClean == metaBase);
  }
  bool isValidFamilyMatch(String candidate, String base) {
    if (base.contains(candidate) || candidate.contains(base)) {
      final shorter = candidate.length < base.length ? candidate.length : base.length;
      final longer  = candidate.length < base.length ? base.length   : candidate.length;
      return shorter / longer >= 0.5;
    }
    final minLen = candidate.length < base.length ? candidate.length : base.length;
    if (minLen < 8) return false;
    int commonLen = 0;
    for (int i = 0; i < minLen; i++) {
      if (candidate[i] == base[i]) commonLen++;
      else break;
    }
    return commonLen / minLen >= 0.6;
  }
  bool familyMatch(SearchResult r) {
    final rClean = cleanTitleForMatching(r.title);
    final rRomajiClean = cleanTitleForMatching(r.romaji ?? '');
    for (final b in familyBases) {
      if (b.length >= 4) {
        if (rClean.isNotEmpty && isValidFamilyMatch(rClean, b)) return true;
        if (rRomajiClean.isNotEmpty && isValidFamilyMatch(rRomajiClean, b)) return true;
      }
    }
    return false;
  }
  final seenSources = <String>{};
  bool isCastellano(SearchResult r, String quality) {
    final t = '${r.title} ${r.romaji ?? ''} ${r.english ?? ''}'.toLowerCase();
    final qLower = quality.toLowerCase();
    final mentionsCastellano = t.contains('castellano') || qLower.contains('castellano');
    if (!mentionsCastellano) return false;
    final hasSubOrLat = qLower.contains('sub') || qLower.contains('latino') || qLower.contains('dub');
    return !hasSubOrLat;
  }
  void addResult(SearchResult r, {bool ignoreSeason = false}) {
    final itemSources = r.sources.isNotEmpty ? r.sources : [SourceItem(source: r.source, url: r.url, quality: r.quality)];
    for (final s in itemSources) {
      final sName = s.source.toUpperCase();
      if (sName == 'TMDB' || sName == 'ANILIST' || sName == 'TRAKT') continue;
      if (isCastellano(r, s.quality)) continue;
      if (isMovieCategory != isMovieResult(r)) continue;
      final rSeason = r.season ?? extractSeason(r.title) ?? extractSeason(r.romaji) ?? extractSeason(r.english) ?? extractSeason(r.url) ?? extractSeason(r.slug) ?? 1;
      if (targetSeason != null && rSeason != targetSeason && !isSeasonUnified(s.source) && !ignoreSeason) continue;
      final qLower = s.quality.toLowerCase();
      final hasSub = qLower.contains('sub');
      final hasLat = qLower.contains('latino') || qLower.contains('dub');
      if (hasSub && hasLat) {
        for (final lang in ['SUB', 'LATINO']) {
          final uniqueKey = '${simplifySourceName(s.source)}_${lang}_${r.slug ?? s.url}'.toLowerCase();
          if (seenSources.add(uniqueKey)) {
            searchSources.add(SearchResult(title: r.title, url: s.url, quality: lang, thumbnail: r.thumbnail, banner: r.banner, source: s.source, slug: r.slug, romaji: r.romaji, english: r.english, year: r.year, score: r.score));
          }
        }
      } else {
        final displayQuality = cleanQuality(s.quality);
        final uniqueKey = '${simplifySourceName(s.source)}_${displayQuality}_${r.slug ?? s.url}'.toLowerCase();
        if (seenSources.add(uniqueKey)) {
          searchSources.add(SearchResult(title: r.title, url: s.url, quality: displayQuality, thumbnail: r.thumbnail, banner: r.banner, source: s.source, slug: r.slug, romaji: r.romaji, english: r.english, year: r.year, score: r.score));
        }
      }
    }
  }
  for (final r in (params.initialSources ?? const <SearchResult>[])) { addResult(r, ignoreSeason: true); }
  final isMovieCard = params.category == 'movie' || params.category == 'movie_anime' || RegExp(r'\b(movie|película|film)\b', caseSensitive: false).hasMatch(searchQuery);

  // Fuentes que no se descubren vía la búsqueda del server (p.ej. AnimeD23: no
  // tiene S1 y su búsqueda apunta a un espejo caído animed2023.com). Se sintetizan
  // derivando la URL desde el slug compartido de las fuentes ya conocidas.
  if (!isMovieCard && params.season != null && !searchSources.any((s) => s.source == 'AnimeD23')) {
    final seeds = params.initialSources ?? const <SearchResult>[];
    String? sharedSlug;
    for (final s in seeds) {
      if (s.slug != null && s.slug!.isNotEmpty) { sharedSlug = s.slug; break; }
    }
    if (sharedSlug == null) {
      for (final s in seeds) {
        final m = RegExp(r'/anime/([^/?#]+)').firstMatch(s.url) ?? RegExp(r'/([^/?#]+)/?$').firstMatch(s.url);
        if (m != null && (m.group(1)?.isNotEmpty ?? false)) { sharedSlug = m.group(1); break; }
      }
    }
    if (sharedSlug != null) {
      addResult(
        SearchResult(
          title: params.title.isNotEmpty ? params.title : (params.metadataTitle ?? ''),
          url: 'https://animed23.com/anime/$sharedSlug/',
          quality: '',
          thumbnail: seeds.firstWhereOrNull((s) => s.thumbnail.isNotEmpty)?.thumbnail ?? '',
          banner: seeds.firstWhereOrNull((s) => s.banner != null)?.banner,
          source: 'AnimeD23',
          slug: sharedSlug,
          year: params.year,
          season: params.season,
          fromDiscovery: true,
        ),
        ignoreSeason: true,
      );
    }
  }
  final movieMarker = RegExp(r'\b(movie|película|film)\b', caseSensitive: false);
  List<SearchResult> mergedResults = searchData?.results ?? const <SearchResult>[];
  final baseSearchData = baseSearchAsync?.valueOrNull;
  if (baseSearchData != null && baseSearchData.results.isNotEmpty) {
    final seenUrls = <String>{ for (final r in mergedResults) (r.url.isNotEmpty ? r.url : r.title).toLowerCase(), };
    final extras = <SearchResult>[];
    for (final r in baseSearchData.results) {
      final key = (r.url.isNotEmpty ? r.url : r.title).toLowerCase();
      final hasUnified = isSeasonUnified(r.source) || r.sources.any((s) => isSeasonUnified(s.source));
      if (seenUrls.add(key) && hasUnified && familyMatch(r) && (isMovieCard || !movieMarker.hasMatch(r.title))) {
        final unified = r.sources.where((s) => isSeasonUnified(s.source)).toList();
        if (unified.isNotEmpty) { extras.add(r.copyWith(source: unified.first.source, url: unified.first.url, quality: unified.first.quality, sources: unified)); }
      }
    }
    if (extras.isNotEmpty) mergedResults = [...mergedResults, ...extras];
  }
  final romanData = romanSearchAsync?.valueOrNull;
  if (romanData != null && romanData.results.isNotEmpty) {
    final seenUrls = <String>{ for (final r in mergedResults) (r.url.isNotEmpty ? r.url : r.title).toLowerCase(), };
    final romanExtras = <SearchResult>[];
    for (final r in romanData.results) {
      final key = (r.url.isNotEmpty ? r.url : r.title).toLowerCase();
      if (seenUrls.add(key)) romanExtras.add(r);
    }
    if (romanExtras.isNotEmpty) mergedResults = [...mergedResults, ...romanExtras];
  }
  if (mergedResults.isEmpty && searchSources.isEmpty) return [];
  final eligible = mergedResults.where((r) => seasonMatches(r) && yearMatches(r)).toList();
  if (params.category == 'movie_anime') {
    for (final r in eligible) { addResult(r); }
    return searchSources;
  }
  for (final r in eligible) {
    final isAjr = isSeasonUnified(r.source) || r.sources.any((s) => isSeasonUnified(s.source));
    if ((isAjr && familyMatch(r)) || strictMatch(r) || (r.kind?.toLowerCase() == 'movie' && familyMatch(r))) addResult(r);
  }
  if (searchSources.isEmpty) { for (final r in eligible) { if (familyMatch(r)) addResult(r); } }
  return searchSources;
});
