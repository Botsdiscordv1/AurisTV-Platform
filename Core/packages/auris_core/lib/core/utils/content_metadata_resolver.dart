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
    // 1. Clasificación base (Inferencia)
    final inferred = inferOpenCategory(this, selectedCategory);

    // 2. Resolver Etiqueta (Label)
    String? typeLabel;
    final typeUp = (type ?? '').toUpperCase().trim();
    final kindUp = (kind ?? '').toUpperCase().trim();

    // Filtro anti-ALL: Ignoramos placeholders genéricos del servidor.
    final cleanType = (typeUp == 'ALL' || typeUp.isEmpty) ? null : type;
    final cleanKind = (kindUp == 'ALL' || kindUp.isEmpty) ? null : kind;

    // Prioridad 1: Tipo específico (OVA, Especial, ONA, Película...) 
    // pero evitamos etiquetas redundantes como "TV" o "ANIME" crudo.
    if (cleanType != null && 
        !typeUp.contains('ANIME') && 
        !typeUp.contains('TV') && 
        !typeUp.contains('SERIE')) {
      typeLabel = _labelFromType(cleanType, inferred);
    } 
    
    // Prioridad 2: El 'kind' explícito del servidor.
    else if (cleanKind != null) {
      typeLabel = _labelFromKind(cleanKind);
    } 
    
    // Prioridad 3: Metadata en la calidad (p.ej. "Serie", "Película")
    else if (quality.isNotEmpty && 
             quality.toLowerCase() != 'all' && 
             quality.toLowerCase() != 'hd') {
      typeLabel = _categoryFromQuality(quality);
    }

    // Fallback Final: Si no hay nada claro, usamos la categoría del filtro o la inferida.
    if (typeLabel == null || typeLabel.toUpperCase() == 'ALL') {
      typeLabel = _labelFromSearchCategory(inferred != 'all' ? inferred : selectedCategory);
    }

    // 3. Resolver Estado (Status)
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
      labelColor: const Color(0xFF1976D2), // Azul AurisTV
      status: statusLabel,
      statusColor: statusColor,
    );
  }

  String? _categoryFromQuality(String quality) {
    final q = quality.toLowerCase();
    if (q.contains('pelicula') || q.contains('película') || q.contains('movie')) return 'PELÍCULA';
    if (q.contains('serie') || q.contains('series') || q.contains('tv')) return 'SERIE';
    if (q.contains('dorama') || q.contains('drama')) return 'DORAMA';
    if (q.contains('anime')) return 'TV ANIME';
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
    if (up == 'ALL') return '';
    return up;
  }

  String _labelFromKind(String kind) {
    final k = kind.toLowerCase();
    if (k.contains('movie')) return 'PELÍCULA';
    if (k.contains('drama')) return 'DORAMA';
    if (k.contains('anime')) return 'TV ANIME';
    if (k.contains('series') || k.contains('tv')) return 'SERIE';
    return 'SERIE';
  }

  String? _labelFromSearchCategory(String category) {
    final c = category.toLowerCase();
    if (c == 'peliculas' || c == 'movie') return 'PELÍCULA';
    if (c == 'series' || c == 'serie') return 'SERIE';
    if (c == 'anime') return 'TV ANIME';
    return null;
  }
}
