import 'search_result.dart';
import 'package:collection/collection.dart';

class UnifiedDetailParams {
  final String title;
  final String? metadataTitle;
  final String category;
  final String? kind;
  final int? year;
  final int? season;
  final String source;
  final String? url;
  final String? type;
  final List<SearchResult>? initialSources;

  const UnifiedDetailParams({
    required this.title,
    this.metadataTitle,
    required this.category,
    this.kind,
    this.year,
    this.season,
    this.source = '',
    this.url,
    this.type,
    this.initialSources,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnifiedDetailParams &&
          title == other.title &&
          metadataTitle == other.metadataTitle &&
          category == other.category &&
          kind == other.kind &&
          year == other.year &&
          season == other.season &&
          source == other.source &&
          url == other.url &&
          type == other.type &&
          const ListEquality().equals(initialSources, other.initialSources);

  @override
  int get hashCode => Object.hash(
      title,
      metadataTitle,
      category,
      kind,
      year,
      season,
      source,
      url,
      type,
      const ListEquality().hash(initialSources));
}

class AnimeDetailParams {
  final String title;
  final int? malId;
  final String? metadataTitle;
  final int? year;
  final int? season;
  final String? kind;
  final String? url;
  final String? type;

  const AnimeDetailParams({
    required this.title,
    this.malId,
    this.metadataTitle,
    this.year,
    this.season,
    this.kind,
    this.url,
    this.type,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnimeDetailParams &&
          title == other.title &&
          malId == other.malId &&
          metadataTitle == other.metadataTitle &&
          year == other.year &&
          season == other.season &&
          kind == other.kind &&
          url == other.url &&
          type == other.type;

  @override
  int get hashCode => Object.hash(
      title, malId, metadataTitle, year, season, kind, url, type);
}

class MovieDetailParams {
  final String title;
  final int? year;
  final String? metadataTitle;
  final String? url;
  final String? type;
  final String category;
  final String? server;
  final String? kind;

  const MovieDetailParams({
    required this.title,
    this.year,
    this.metadataTitle,
    this.url,
    this.type,
    this.category = 'movie',
    this.server,
    this.kind,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MovieDetailParams &&
          title == other.title &&
          year == other.year &&
          metadataTitle == other.metadataTitle &&
          url == other.url &&
          type == other.type &&
          category == other.category &&
          server == other.server &&
          kind == other.kind;

  @override
  int get hashCode => Object.hash(
      title, year, metadataTitle, url, type, category, server, kind);
}
