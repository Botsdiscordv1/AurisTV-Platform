import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';

import '../../data/avatar_catalog_repository.dart';
import '../../domain/avatar_catalog.dart';
import '../../domain/avatar_selection.dart';

/// Repositorio del catálogo local de avatares.
final avatarCatalogRepositoryProvider = Provider<AvatarCatalogRepository>((ref) {
  return AvatarCatalogRepository();
});

/// Catálogo de avatares cargado desde los assets de la app (offline).
final avatarCatalogProvider = FutureProvider<AvatarCatalog>((ref) {
  return ref.watch(avatarCatalogRepositoryProvider).loadCatalog();
});

/// Box de Hive donde se persiste la selección de avatar.
final avatarSelectionBoxProvider = Provider<Box>((ref) {
  return Hive.box('user_data');
});

class AvatarSelectionNotifier extends StateNotifier<AvatarSelection> {
  final Box _box;

  AvatarSelectionNotifier(this._box) : super(const AvatarSelection()) {
    final saved = _box.get('avatar_selection');
    if (saved != null) {
      try {
        final map = saved is String
            ? Map<String, dynamic>.from(jsonDecode(saved) as Map)
            : Map<String, dynamic>.from(saved as Map);
        state = AvatarSelection.fromJson(map);
      } catch (_) {
        // Selección corrupta: se ignora.
      }
    }
  }

  /// Guarda una selección y, si el usuario tiene sesión, actualiza su
  /// `photoUrl` local para que el resto de la app la use.
  void select(int? characterId, {int variantIndex = 0}) {
    final next = AvatarSelection(characterId: characterId, variantIndex: variantIndex);
    state = next;
    _box.put('avatar_selection', next.toJson());
  }

  void reset() {
    state = const AvatarSelection();
    _box.delete('avatar_selection');
  }
}

final avatarSelectionProvider =
    StateNotifierProvider<AvatarSelectionNotifier, AvatarSelection>((ref) {
  return AvatarSelectionNotifier(ref.watch(avatarSelectionBoxProvider));
});

/// Ruta de asset del avatar seleccionado (o null si no hay selección válida).
final selectedAvatarPathProvider = Provider<String?>((ref) {
  final selection = ref.watch(avatarSelectionProvider);
  final catalogAsync = ref.watch(avatarCatalogProvider);
  final catalog = catalogAsync.valueOrNull;
  if (catalog == null || selection.characterId == null) return null;
  for (final franchise in catalog.franchises) {
    for (final character in franchise.characters) {
      if (character.characterId == selection.characterId) {
        return character.variantAt(selection.variantIndex);
      }
    }
  }
  return null;
});

/// Categoría de avatares seleccionada en la UI de selección.
final avatarCategoryProvider = StateProvider<String>((ref) => 'anime');
