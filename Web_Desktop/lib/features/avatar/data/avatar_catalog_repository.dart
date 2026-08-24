import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import '../domain/avatar_catalog.dart';

/// Repositorio del catálogo local de avatares.
///
/// Carga el JSON incluido en los assets de la app (sin red, sin AniList).
class AvatarCatalogRepository {
  static const String _catalogAssetPath = 'assets/data/avatar_catalog.json';

  Future<AvatarCatalog> loadCatalog() async {
    final raw = await rootBundle.loadString(_catalogAssetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return AvatarCatalog.fromJson(json);
  }
}