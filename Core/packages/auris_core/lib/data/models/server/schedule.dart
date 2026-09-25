import '../../../core/api/api_endpoints.dart';

class ScheduleResponse {
  final String season;
  final int year;
  final int total;
  final List<ScheduleDay> days;

  const ScheduleResponse({
    required this.season,
    required this.year,
    required this.total,
    required this.days,
  });

  factory ScheduleResponse.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> data = (json.containsKey('data') && json['data'] is Map)
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;
    return ScheduleResponse(
      season: data['season'] as String? ?? '',
      year: switch (data['year']) {
        num n => n.toInt(),
        String s => int.tryParse(s) ?? 0,
        _ => 0,
      },
      total: switch (data['total']) {
        num n => n.toInt(),
        String s => int.tryParse(s) ?? 0,
        _ => 0,
      },
      days: (data['days'] as List<dynamic>?)
              ?.map((e) => ScheduleDay.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  static const List<String> _canonicalDayNames = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];

  static int _localDayIndex(DateTime date) => (date.weekday + 6) % 7;

  /// Reagrupa el calendario usando la zona horaria local del dispositivo.
  ///
  /// El servidor etiqueta columnas e `isToday` en UTC, lo que desalinea el
  /// calendario con la realidad del usuario (y con AnimeAV1) fuera de UTC.
  /// Aquí cada item se coloca en el día local de su `airingAt` (instante
  /// absoluto, ya correcto) y `isToday` se calcula con la fecha local.
  /// Los items sin `airingAt` conservan su columna original.
  ScheduleResponse localize({DateTime? now}) {
    if (days.isEmpty) return this;

    final localNow = now ?? DateTime.now();
    final todayIndex = _localDayIndex(localNow);
    final buckets = List.generate(7, (_) => <ScheduleItem>[]);
    final names = List.filled(7, '');

    for (final day in days) {
      final originalIndex =
          day.dayIndex >= 0 && day.dayIndex <= 6 ? day.dayIndex : 0;
      if (names[originalIndex].isEmpty) names[originalIndex] = day.day;
      for (final item in day.items) {
        final airingAt = item.airingAt;
        if (airingAt != null && airingAt > 0) {
          final localAiring =
              DateTime.fromMillisecondsSinceEpoch(airingAt * 1000);
          buckets[_localDayIndex(localAiring)].add(item);
        } else {
          buckets[originalIndex].add(item);
        }
      }
    }

    int compareByAiringAt(ScheduleItem a, ScheduleItem b) {
      final x = a.airingAt;
      final y = b.airingAt;
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return x.compareTo(y);
    }

    return ScheduleResponse(
      season: season,
      year: year,
      total: total,
      days: [
        for (var i = 0; i < 7; i++)
          ScheduleDay(
            day: names[i].isNotEmpty ? names[i] : _canonicalDayNames[i],
            dayIndex: i,
            isToday: i == todayIndex,
            items: [...buckets[i]]..sort(compareByAiringAt),
          ),
      ],
    );
  }
}

class ScheduleDay {
  final String day;
  final int dayIndex;
  final bool isToday;
  final List<ScheduleItem> items;

  const ScheduleDay({
    required this.day,
    required this.dayIndex,
    this.isToday = false,
    required this.items,
  });

  factory ScheduleDay.fromJson(Map<String, dynamic> json) {
    return ScheduleDay(
      day: json['day'] as String? ?? '',
      dayIndex: switch (json['dayIndex']) {
        num n => n.toInt(),
        String s => int.tryParse(s) ?? 0,
        _ => 0,
      },
      isToday: json['isToday'] as bool? ?? false,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ScheduleItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ScheduleItem {
  final int id;
  final String title;
  final String? romaji;
  final String? english;
  final String? native_;
  final List<String> synonyms;
  final String? description;
  final String? coverImage;
  final String? banner;
  final List<String> genres;
  final String? studio;
  final int? episodes;
  final String? format;
  final String? status;
  final double? averageScore;
  final int? nextEpisode;
  final int? airingAt;
  final int? episode;
  final bool aired;
  final bool sourceAvailable;
  final int? year;

  // Etiqueta de estreno (premiere-ping AV1): 'delayed'/'advanced' con el
  // desvío en minutos respecto a la hora mostrada ("Retrasado +37m").
  final String? premiereStatus;
  final int? premiereDeltaMin;

  // Campos directos de fuente
  final String? url;
  final String? slug;
  final String? quality;
  final String? type;
  final String? source;
  final String? kind;
  final String? scrapedTitle;
  final int? totalSeasons;
  final String? season;
  final List<ScheduleSource> sources;
  final List<String> availableSources;

  const ScheduleItem({
    required this.id,
    required this.title,
    this.romaji,
    this.english,
    this.native_,
    this.synonyms = const [],
    this.description,
    this.coverImage,
    this.banner,
    this.genres = const [],
    this.studio,
    this.episodes,
    this.format,
    this.status,
    this.averageScore,
    this.nextEpisode,
    this.airingAt,
    this.episode,
    this.aired = false,
    this.sourceAvailable = true,
    this.year,
    this.premiereStatus,
    this.premiereDeltaMin,
    this.url,
    this.slug,
    this.quality,
    this.type,
    this.source,
    this.kind,
    this.scrapedTitle,
    this.totalSeasons,
    this.season,
    this.sources = const [],
    this.availableSources = const [],
  });

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    final sources = (json['sources'] as List<dynamic>?)
            ?.map((e) => ScheduleSource.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    // Inferencia Senior: Si el root no trae source/quality/type, 
    // los tomamos de la primera fuente disponible.
    final firstSource = sources.isNotEmpty ? sources.first : null;

    return ScheduleItem(
      id: switch (json['id']) {
        num n => n.toInt(),
        String s => int.tryParse(s) ?? 0,
        _ => 0,
      },
      title: json['title'] as String? ?? '',
      romaji: json['romaji'] as String?,
      english: json['english'] as String?,
      native_: json['native'] as String?,
      synonyms: (json['synonyms'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      description: json['description'] as String?,
      coverImage: ApiEndpoints.proxyImage(
        json['coverImage'] as String? ??
            json['poster'] as String? ??
            json['posterUrl'] as String? ??
            json['image'] as String? ??
            json['thumbnail'] as String?,
      ),
      banner: ApiEndpoints.proxyImage(
        json['banner'] as String? ??
            json['backdrop'] as String? ??
            json['bannerUrl'] as String?,
        highQuality: true,
      ),
      genres: (json['genres'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      studio: json['studio'] as String?,
      episodes: switch (json['episodes']) {
        num n => n.toInt(),
        String s => int.tryParse(s),
        _ => null,
      },
      format: json['format'] as String?,
      status: json['status'] as String?,
      averageScore: (json['averageScore'] as num?)?.toDouble(),
      nextEpisode: switch (json['nextEpisode']) {
        num n => n.toInt(),
        String s => int.tryParse(s),
        _ => null,
      },
      airingAt: switch (json['airingAt']) {
        num n => n.toInt(),
        String s => int.tryParse(s),
        _ => null,
      },
      episode: switch (json['episode']) {
        num n => n.toInt(),
        String s => int.tryParse(s),
        _ => null,
      },
      aired: json['aired'] as bool? ?? false,
      sourceAvailable: json['sourceAvailable'] as bool? ?? true,
      premiereStatus: json['premiereStatus'] as String?,
      premiereDeltaMin: switch (json['premiereDeltaMin']) {
        num n => n.toInt(),
        String s => int.tryParse(s),
        _ => null,
      },
      year: switch (json['year']) {
        num n => n.toInt(),
        String s => int.tryParse(s),
        _ => null,
      },
      url: json['url'] as String? ?? firstSource?.url,
      slug: json['slug'] as String? ?? firstSource?.slug,
      quality: json['quality'] as String? ?? firstSource?.quality,
      type: json['type'] as String? ?? firstSource?.type,
      source: json['source'] as String? ?? firstSource?.source,
      kind: json['kind'] as String? ?? json['categoria'] as String?,
      scrapedTitle: json['scrapedTitle'] as String?,
      totalSeasons: switch (json['totalSeasons']) {
        num n => n.toInt(),
        String s => int.tryParse(s),
        _ => null,
      },
      season: json['season']?.toString(),
      sources: sources,
      availableSources: (json['availableSources'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class ScheduleSource {
  final String source;
  final String url;
  final String quality;
  final String? slug;
  final String? type;

  const ScheduleSource({
    required this.source,
    required this.url,
    required this.quality,
    this.slug,
    this.type,
  });

  factory ScheduleSource.fromJson(Map<String, dynamic> json) {
    return ScheduleSource(
      source: json['source'] as String? ?? '',
      url: json['url'] as String? ?? '',
      quality: json['quality'] as String? ?? '',
      slug: json['slug'] as String?,
      type: json['type'] as String?,
    );
  }
}
