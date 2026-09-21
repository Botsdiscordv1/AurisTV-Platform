import 'search_result.dart';
import 'section_see_more.dart';
import '../../../core/api/api_endpoints.dart';

class HomeResponse {
  final String userId;
  final String maturityLevel;
  final List<HomeSection> sections;
  final String generatedAt;

  const HomeResponse({
    required this.userId,
    required this.maturityLevel,
    required this.sections,
    required this.generatedAt,
  });

  factory HomeResponse.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> data = (json.containsKey('data') && json['data'] is Map)
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    return HomeResponse(
      userId: data['userId'] as String? ?? '',
      maturityLevel: data['maturityLevel'] as String? ?? 'cold',
      sections: (data['sections'] as List<dynamic>?)
              ?.map((e) => HomeSection.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      generatedAt: data['generatedAt'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'maturityLevel': maturityLevel,
        'sections': sections.map((e) => e.toJson()).toList(),
        'generatedAt': generatedAt,
      };
}

class HomeSection {
  final String id;
  final String title;
  final String? subtitle;
  final String strategy;
  final String type;
  final int priority;
  final String? format; // Senior Fix: Soporte para Server-Driven UI (poster, wide, top10)
  final List<HomeItem> items;
  final List<String> reasonKeys;
  final SectionFilters? filters;
  final SectionSeeMore? verMas;

  const HomeSection({
    required this.id,
    required this.title,
    this.subtitle,
    required this.strategy,
    required this.type,
    required this.priority,
    this.format,
    required this.items,
    this.reasonKeys = const [],
    this.filters,
    this.verMas,
  });

  factory HomeSection.fromJson(Map<String, dynamic> json) {
    return HomeSection(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      strategy: json['strategy'] as String? ?? '',
      type: json['type'] as String? ?? '',
      priority: switch (json['priority']) {
        num n => n.toInt(),
        String s => int.tryParse(s) ?? 0,
        _ => 0,
      },
      format: json['format'] as String? ?? 
              json['layout'] as String? ?? 
              json['layoutType'] as String? ?? 
              json['carousel'] as String? ?? 
              json['displayMode'] as String? ?? 
              json['carouselType'] as String?,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => HomeItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      reasonKeys: (json['reasonKeys'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      filters: json['filters'] != null
          ? SectionFilters.fromJson(Map<String, dynamic>.from(json['filters'] as Map))
          : null,
      verMas: json['verMas'] != null
          ? SectionSeeMore.fromJson(Map<String, dynamic>.from(json['verMas'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'strategy': strategy,
        'type': type,
        'priority': priority,
        'format': format,
        'items': items.map((e) => e.toJson()).toList(),
        'reasonKeys': reasonKeys,
        if (filters != null) 'filters': filters!.toJson(),
        if (verMas != null) 'verMas': verMas!.toJson(),
      };
}

class HomeItem {
  final String id;
  final String? animeId;
  final String title;
  final String? posterUrl;
  final String? backdropUrl;
  final String? logoUrl; // Senior Fix: Soporte para logos en filas WIDE / Hero
  final dynamic progress;
  final String? detailUrl;
  final String? url;
  final String? source;
  final String? kind;
  final String? type;
  final double? rating;
  final int? year;
  final double? score;
  final List<String> reasonKeys;
  final List<SourceItem> sources;

  const HomeItem({
    required this.id,
    this.animeId,
    required this.title,
    this.posterUrl,
    this.backdropUrl,
    this.logoUrl,
    this.progress,
    this.detailUrl,
    this.url,
    this.source,
    this.kind,
    this.type,
    this.rating,
    this.year,
    this.score,
    this.reasonKeys = const [],
    this.sources = const [],
  });

  factory HomeItem.fromJson(Map<String, dynamic> json) {
    // Senior Fix: Resiliencia para ids numéricos y claves alternativas del backend (poster vs posterUrl, url vs id)
    final dynamic rawId = json['id'];
    final String resolvedId = switch (rawId) {
      String s when s.isNotEmpty => s,
      num n => n.toString(),
      _ => (json['url'] as String? ?? json['detailUrl'] as String? ?? json['playUrl'] as String? ?? ''),
    };
    return HomeItem(
      id: resolvedId,
      animeId: json['animeId'] as String? ?? json['anime_id'] as String?,
      title: json['title'] as String? ?? '',
      posterUrl: json['posterUrl'] as String? ??
          json['poster'] as String? ??
          json['thumbnail'] as String? ??
          json['poster_url'] as String? ??
          json['image'] as String?,
      backdropUrl: json['backdropUrl'] as String? ??
          json['backdrop'] as String? ??
          json['bannerUrl'] as String? ??
          json['banner'] as String? ??
          json['backdrop_url'] as String?,
      logoUrl: json['logoUrl'] as String? ?? json['logo'] as String?,
      progress: json['progress'],
      detailUrl: json['detailUrl'] as String? ?? json['url'] as String? ?? json['playUrl'] as String?,
      url: json['url'] as String? ?? json['detailUrl'] as String? ?? json['playUrl'] as String?,
      source: json['source'] as String?,
      kind: json['kind'] as String? ?? json['mediaType'] as String?,
      type: json['type'] as String?,
      rating: switch (json['rating']) {
        num value => value.toDouble(),
        _ => switch (json['score']) {
          num s => s.toDouble(),
          _ => null,
        },
      },
      year: switch (json['year']) {
        num value => value.toInt(),
        String s => int.tryParse(s),
        _ => null,
      },
      score: switch (json['score']) {
        num value => value.toDouble(),
        _ => switch (json['rating']) {
          num r => r.toDouble(),
          _ => null,
        },
      },
      reasonKeys: (json['reasonKeys'] as List<dynamic>? ?? json['reasonKey'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      sources: (json['sources'] as List<dynamic>?)
              ?.map((e) => SourceItem.fromJson(e as Map))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'animeId': animeId,
        'title': title,
        'posterUrl': posterUrl,
        'backdropUrl': backdropUrl,
        'logoUrl': logoUrl,
        'progress': progress,
        'detailUrl': detailUrl,
        'url': url,
        'source': source,
        'kind': kind,
        'type': type,
        'rating': rating,
        'year': year,
        'score': score,
        'reasonKeys': reasonKeys,
        'sources': sources.map((e) => e.toJson()).toList(),
      };
}
