import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auris_core.dart';

final animeDetailProvider =
    FutureProvider.family<AnimeDetail?, AnimeDetailParams>((ref, params) async {
  final repo = ref.watch(aurisRepositoryProvider);
  return repo.getAnimeDetail(
    title: params.title,
    malId: params.malId,
    metadataTitle: params.metadataTitle,
    year: params.year,
    season: params.season,
  );
});

final movieDetailProvider =
    FutureProvider.family<MovieDetail?, MovieDetailParams>((ref, params) async {
  final repo = ref.watch(aurisRepositoryProvider);
  return repo.getMovieDetail(
    title: params.title,
    year: params.year,
    metadataTitle: params.metadataTitle,
    url: params.url,
    quality: params.quality,
    category: params.category,
    server: params.server,
  );
});

class AnimeDetailParams {
  final String title;
  final int? malId;
  final String? metadataTitle;
  final int? year;
  final int? season;

  const AnimeDetailParams({
    required this.title,
    this.malId,
    this.metadataTitle,
    this.year,
    this.season,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnimeDetailParams &&
          title == other.title &&
          malId == other.malId &&
          metadataTitle == other.metadataTitle &&
          year == other.year &&
          season == other.season;

  @override
  int get hashCode => Object.hash(title, malId, metadataTitle, year, season);
}

class MovieDetailParams {
  final String title;
  final int? year;
  final String? metadataTitle;
  final String? url;
  final String? quality;
  final String category;
  final String? server;

  const MovieDetailParams({
    required this.title,
    this.year,
    this.metadataTitle,
    this.url,
    this.quality,
    this.category = 'movie',
    this.server,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MovieDetailParams &&
          title == other.title &&
          year == other.year &&
          metadataTitle == other.metadataTitle &&
          url == other.url &&
          quality == other.quality &&
          category == other.category &&
          server == other.server;

  @override
  int get hashCode =>
      Object.hash(title, year, metadataTitle, url, quality, category, server);
}

final activeContentSourcesProvider = StateProvider<List<SearchResult>>((ref) => []);

class ExtractParams {
  final String url;
  final String source;
  final String? category;
  const ExtractParams({required this.url, required this.source, this.category});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExtractParams && url == other.url && source == other.source && category == other.category;

  @override
  int get hashCode => Object.hash(url, source, category);
}

final extractProvider =
    FutureProvider.family<ExtractResult, ExtractParams>((ref, params) async {
  final repo = ref.watch(aurisRepositoryProvider);
  return repo.extractVideo(params.url, params.source, category: params.category, direct: !kIsWeb);
});
