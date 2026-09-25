import '../../data/models/server/episodes_response.dart';

enum ReleaseState {
  available,
  upcoming,
  releasingToday,
  releasedWithoutEpisodes,
  noReleaseDate,
}

class ReleaseCountdownLogic {
  /// Parsea la fecha u hora de estreno desde un timestamp ISO o formato de fecha.
  static DateTime? parseReleaseDateTime(String? timestamp, String? date) {
    if (timestamp != null && timestamp.isNotEmpty) {
      final dt = DateTime.tryParse(timestamp);
      if (dt != null) return dt;
    }
    if (date != null && date.isNotEmpty) {
      final dt = DateTime.tryParse(date);
      if (dt != null) return dt;
    }
    return null;
  }

  /// Evalúa el estado actual de estreno basándose en los episodios disponibles y las fechas de lanzamiento.
  static ReleaseState evaluate({
    required List<EpisodeInfo> episodes,
    String? releaseStatus,
    String? releaseDate,
    String? releaseTimestamp,
    DateTime? now,
  }) {
    // Regla E: Si existen episodios disponibles, tienen prioridad absoluta.
    if (episodes.isNotEmpty) {
      return ReleaseState.available;
    }

    final currentTime = now ?? DateTime.now();
    final targetDt = parseReleaseDateTime(releaseTimestamp, releaseDate);

    // Regla D: Si no existe fecha o timestamp conocido
    if (targetDt == null) {
      return ReleaseState.noReleaseDate;
    }

    final isSameDay = targetDt.year == currentTime.year &&
        targetDt.month == currentTime.month &&
        targetDt.day == currentTime.day;

    if (targetDt.isAfter(currentTime)) {
      if (isSameDay) {
        return ReleaseState.releasingToday;
      }
      return ReleaseState.upcoming;
    } else {
      // El timestamp ya pasó
      if (isSameDay) {
        return ReleaseState.releasingToday;
      }
      // Regla C: Fecha alcanzada pero sin episodios
      return ReleaseState.releasedWithoutEpisodes;
    }
  }

  /// Calcula el tiempo restante hasta la fecha objetivo de forma absoluta.
  static Duration calculateTimeRemaining(DateTime targetDateTime, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    final diff = targetDateTime.difference(currentTime);
    if (diff.isNegative) {
      return Duration.zero;
    }
    return diff;
  }

  /// Formatea la fecha en español (ej. "7 de octubre de 2026").
  static String formatDate(DateTime dt) {
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    final day = dt.day;
    final month = months[dt.month - 1];
    final year = dt.year;
    return '$day de $month de $year';
  }
}
