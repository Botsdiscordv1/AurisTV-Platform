import 'avatar_character.dart';

/// Una franquicia del catálogo de avatares (sección del carrusel).
class AvatarFranchise {
  final String id;
  final String name;
  final String category;
  final List<AvatarCharacter> characters;

  const AvatarFranchise({
    required this.id,
    required this.name,
    required this.category,
    required this.characters,
  });

  factory AvatarFranchise.fromJson(Map<String, dynamic> json) {
    return AvatarFranchise(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'anime',
      characters: (json['characters'] as List<dynamic>? ?? [])
          .map((e) => AvatarCharacter.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
