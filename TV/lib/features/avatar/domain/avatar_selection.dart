/// Referencia persistida del avatar seleccionado por el usuario.
///
/// Solo guarda la referencia (characterId + variante), NO la imagen.
/// La app resuelve la referencia contra el catálogo local.
class AvatarSelection {
  final int? characterId;
  final int variantIndex;

  const AvatarSelection({
    this.characterId,
    this.variantIndex = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'characterId': characterId,
      'variantIndex': variantIndex,
    };
  }

  factory AvatarSelection.fromJson(Map<String, dynamic> json) {
    return AvatarSelection(
      characterId: json['characterId'] as int?,
      variantIndex: json['variantIndex'] as int? ?? 0,
    );
  }

  AvatarSelection copyWith({int? characterId, int? variantIndex}) {
    return AvatarSelection(
      characterId: characterId ?? this.characterId,
      variantIndex: variantIndex ?? this.variantIndex,
    );
  }
}