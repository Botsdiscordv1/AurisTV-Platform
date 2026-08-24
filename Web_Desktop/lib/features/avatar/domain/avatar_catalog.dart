import 'avatar_franchise.dart';

/// Catálogo local de avatares cargado desde `assets/data/avatar_catalog.json`.
class AvatarCatalog {
  final int version;
  final List<AvatarFranchise> franchises;

  const AvatarCatalog({
    required this.version,
    required this.franchises,
  });

  factory AvatarCatalog.fromJson(Map<String, dynamic> json) {
    return AvatarCatalog(
      version: json['version'] as int? ?? 1,
      franchises: (json['franchises'] as List<dynamic>? ?? [])
          .map((e) => AvatarFranchise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}