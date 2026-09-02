import 'package:flutter/material.dart';
import '../../data/models/server/search_result.dart';
import 'category_utils.dart';

/// Encapsula los metadatos visuales de un contenido para mostrar en tarjetas o listas.
class ContentMetadata {
  final String? label;
  final Color labelColor;
  final String? status;
  final Color? statusColor;

  const ContentMetadata({
    this.label,
    required this.labelColor,
    this.status,
    this.statusColor,
  });
}

extension SearchResultMetadataExtension on SearchResult {
  /// Resuelve las etiquetas y colores de visualización basados en los metadatos del servidor.
  ContentMetadata resolveMetadata([String selectedCategory = 'all']) {
    // 1. Resolver Etiqueta (Label)
    String? typeLabel;
    final typeUp = (type ?? '').toUpperCase();
    final hasSpecificType = type != null &&
        type!.isNotEmpty &&
        !typeUp.contains('ANIME') &&
        !typeUp.contains('TV');

    if (hasSpecificType) {
      typeLabel = _labelFromType(type!, selectedCategory);
    } else if (kind != null && kind!.isNotEmpty) {
      typeLabel = _labelFromKind(kind!);
    } else if (quality != null && quality!.isNotEmpty) {
      typeLabel = _categoryFromQuality(quality!);
    } else if (type != null && type!.isNotEmpty) {
      typeLabel = _labelFromType(type!, selectedCategory);
    } else {
      typeLabel = _labelFromSearchCategory(selectedCategory);
    }

    // 2. Resolver Estado (Status)
    String? statusLabel;
    Color? statusColor;
    final s = (status ?? '').toLowerCase();
    if (s.contains('emisi')) {
      statusLabel = 'EN EMISIÓN';
      statusColor = const Color(0xFFEF7A1E); // AurisTV Brand Orange
    } else if (s.contains('finaliz') || s.contains('complet')) {
      statusLabel = 'FINALIZADO';
      statusColor = Colors.black.withOpacity(0.9);
    }

    return ContentMetadata(
      label: typeLabel,
      labelColor: const Color(0xFF1976D2), // Azul por defecto
      status: statusLabel,
      statusColor: statusColor,
    );
  }

  String? _categoryFromQuality(String quality) {
    final q = quality.toLowerCase();
    if (q.contains('pelicula') || q.contains('película') || q.contains('movie') || q.contains('film')) {
      return 'PELÍCULA';
    }
    if (q.contains('dorama') || q.contains('drama')) {
      return 'DORAMA';
    }
    if (q.contains('serie') || q.contains('series') || q.contains('tv')) {
      return 'SERIE';
    }
    if (q.contains('anime')) {
      return 'ANIME';
    }
    return null;
  }

  String _labelFromType(String type, String selectedCategory) {
    final up = type.toUpperCase();
    if (up.contains('MOVIE') || up.contains('FILM') || up.contains('PELICULA') || up.contains('PELÍCULA')) return 'PELÍCULA';
    if (up.contains('DORAMA') || up.contains('DRAMA')) return 'DORAMA';
    if (up.contains('SERIE') || up == 'TV' || up.contains('TV')) {
      return selectedCategory.toLowerCase() == 'anime' ? 'TV ANIME' : 'SERIE';
    }
    if (up.contains('ANIME')) return 'TV ANIME';
    return up;
  }

  String _labelFromKind(String kind) {
    final k = kind.toLowerCase();
    if (k.contains('movie') || k.contains('film')) return 'PELÍCULA';
    if (k.contains('drama') || k.contains('dorama')) return 'DORAMA';
    if (k.contains('anime')) return 'TV ANIME';
    if (k.contains('series') || k.contains('tv')) return 'SERIE';
    return 'SERIE';
  }

  String? _labelFromSearchCategory(String category) {
    switch (category.toLowerCase()) {
      case 'peliculas':
        return 'PELÍCULA';
      case 'series':
        return 'SERIE';
      case 'anime':
        return 'TV ANIME';
      default:
        return null;
    }
  }
}
