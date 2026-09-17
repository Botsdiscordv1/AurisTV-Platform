import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../../auris_core.dart';
import 'auth_provider.dart';

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, List<FavoriteItem>>((ref) {
  final box = Hive.box('favorites');
  final user = ref.watch(authProvider);
  final profileId = user?.activeProfileId ?? 'guest_profile';
  return FavoritesNotifier(box, profileId, ref);
});

class FavoritesNotifier extends StateNotifier<List<FavoriteItem>> {
  final Box _box;
  final String _profileId;
  final Ref ref;

  FavoritesNotifier(this._box, this._profileId, this.ref) : super([]) {
    _loadFavorites();
  }

  void _loadFavorites() {
    state = _box.values
        .map((e) => FavoriteItem.fromJson(e as Map))
        .where((f) => f.profileId == _profileId)
        .toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  }

  bool isFavorite(String id) {
    return state.any((f) => f.id == id);
  }

  Future<void> toggleFavorite(FavoriteItem item) async {
    final key = '${_profileId}_${item.id}';
    if (isFavorite(item.id)) {
      await _box.delete(key);
      state = state.where((f) => f.id != item.id).toList();
    } else {
      await _box.put(key, item.toJson());
      state = [item, ...state];

      // [Intelligence] Reportar favorito al motor de personalización
      final user = ref.read(authProvider);
      final String? animeId = item.id.contains('/') ? null : item.id; // Heurística: si es URL no es animeId canónico
      
      ref.read(userEventTrackerProvider).record(
        userId: user?.activeProfileId ?? user?.id,
        animeId: animeId, // Solo si es canónico
        event: 'favorite',
      );
    }
  }
}
