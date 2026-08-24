import 'avatar_role.dart';

/// Un personaje dentro de una franquicia del catálogo de avatares.
///
/// Todas sus variantes comparten el mismo `characterId` de AniList.
class AvatarCharacter {
  final int? characterId;
  final String name;
  final AvatarRole role;
  final List<String> variants;

  const AvatarCharacter({
    this.characterId,
    required this.name,
    this.role = AvatarRole.supporting,
    required this.variants,
  });

  factory AvatarCharacter.fromJson(Map<String, dynamic> json) {
    return AvatarCharacter(
      characterId: json['characterId'] as int?,
      name: json['name'] as String? ?? '',
      role: AvatarRole.fromJson(json['role'] as String?),
      variants: (json['variants'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  /// Ruta del asset de la variante principal (primera del catálogo).
  String get primaryVariant => variants.isNotEmpty ? variants.first : '';

  /// Ruta del asset de una variante concreta (si el índice es válido).
  String variantAt(int index) {
    if (index < 0 || index >= variants.length) return primaryVariant;
    return variants[index];
  }
}