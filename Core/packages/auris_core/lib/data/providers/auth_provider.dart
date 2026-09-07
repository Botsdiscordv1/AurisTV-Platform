import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../../auris_core.dart';

final authProvider = StateNotifierProvider<AuthNotifier, UserAccount?>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<UserAccount?> {
  final Box _userBox = Hive.box('user_data');

  // Senior Fix: Inicializar con una cuenta de invitado por defecto 
  // para estabilizar el profileId durante el arranque de la app.
  static final UserAccount _defaultGuest = UserAccount(
    id: 'guest_user',
    profiles: [
      UserProfile(id: 'guest_profile', name: 'Invitado', isMain: true)
    ],
    activeProfileId: 'guest_profile',
    email: null,
  );

  AuthNotifier() : super(_defaultGuest) {
    _init();
  }

  void _init() {
    final savedUserData = _userBox.get('profile');
    if (savedUserData != null) {
      try {
        final map = savedUserData is String ? jsonDecode(savedUserData) : Map<String, dynamic>.from(savedUserData);
        state = UserAccount.fromJson(map);
      } catch (e) {
        debugPrint('Error cargando perfil local: $e');
      }
    } else {
      // Si no hay datos guardados, nos aseguramos de estar en modo invitado limpio
      state = _defaultGuest;
    }

    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final user = data.session?.user;
      final bool shouldSyncFromCloud = 
          data.event == AuthChangeEvent.signedIn || 
          data.event == AuthChangeEvent.initialSession ||
          state == null;

      if (user != null && shouldSyncFromCloud) {
        final List<dynamic>? cloudProfilesRaw = user.userMetadata?['profiles'];
        List<UserProfile> profiles = [];
        String? activeId;

        if (cloudProfilesRaw != null && cloudProfilesRaw.isNotEmpty) {
          profiles = cloudProfilesRaw
              .map((p) => UserProfile.fromJson(p as Map<String, dynamic>))
              .toList();
          activeId = user.userMetadata?['active_profile_id'];
        } else {
          final String profileName = user.userMetadata?['full_name'] ?? 'Usuario';
          final String? photoUrl = user.userMetadata?['custom_avatar_url'] ?? user.userMetadata?['avatar_url'];
          
          final mainProfile = UserProfile(
            id: user.id,
            name: profileName,
            photoUrl: photoUrl,
            isMain: true,
          );
          profiles = [mainProfile];
          activeId = mainProfile.id;
        }

        final newUser = UserAccount(
          id: user.id,
          email: user.email,
          profiles: profiles,
          activeProfileId: activeId,
        );

        state = newUser;
        _saveLocally(newUser);
        
        if (cloudProfilesRaw == null) {
          _syncToCloud(newUser);
        }
      } else if (user == null && data.event == AuthChangeEvent.signedOut) {
        state = null;
        _userBox.delete('profile');
      }
    });
  }

  Future<void> _syncToCloud(UserAccount user) async {
    if (user.email == null) return;
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            'profiles': user.profiles.map((p) => p.toJson()).toList(),
            'active_profile_id': user.activeProfileId,
          },
        ),
      );
    } catch (e) {
      // ignore: avoid_print
      print('Error sincronizando con Supabase: $e');
    }
  }

  void updateConnections(Map<ConnectionType, ExternalConnection> connections) {
    if (state == null) return;
    final active = state!.activeProfile;
    if (active == null) return;
    final updatedProfile = active.copyWith(connections: connections);
    final updatedProfiles = state!.profiles
        .map((p) => p.id == updatedProfile.id ? updatedProfile : p)
        .toList();
    final updated = state!.copyWith(profiles: updatedProfiles);
    state = updated;
    _saveLocally(updated);
    _syncToCloud(updated);
  }

  void updateAvatar(String newUrl) async {
    final current = state ??
        UserAccount(
          id: 'guest_user',
          profiles: [
            UserProfile(id: 'guest_profile', name: 'Invitado', isMain: true)
          ],
          activeProfileId: 'guest_profile',
          email: null,
        );
    final activeProfile = current.activeProfile;
    if (activeProfile == null) return;
    final updatedProfile = activeProfile.copyWith(photoUrl: newUrl);
    final updatedProfiles = current.profiles
        .map((p) => p.id == updatedProfile.id ? updatedProfile : p)
        .toList();
    final updated = current.copyWith(profiles: updatedProfiles);
    state = updated;
    _saveLocally(updated);
    _syncToCloud(updated);
  }

  void updateProfileName(String newName) {
    if (state == null) return;
    final active = state!.activeProfile;
    if (active == null) return;
    final updatedProfile = active.copyWith(name: newName);
    final updatedProfiles = state!.profiles
        .map((p) => p.id == updatedProfile.id ? updatedProfile : p)
        .toList();
    final updated = state!.copyWith(profiles: updatedProfiles);
    state = updated;
    _saveLocally(updated);
    _syncToCloud(updated);
  }

  void switchProfile(String profileId) {
    if (state == null) return;
    final updated = state!.copyWith(activeProfileId: profileId);
    state = updated;
    _saveLocally(updated);
    _syncToCloud(updated);
  }

  void addProfile(String name, String? avatarUrl) {
    if (state == null) return;
    final newProfile = UserProfile.createDefault(name: name, photoUrl: avatarUrl);
    final updatedProfiles = [...state!.profiles, newProfile];
    final updated = state!.copyWith(profiles: updatedProfiles);
    state = updated;
    _saveLocally(updated);
    _syncToCloud(updated);
  }

  void deleteProfile(String profileId) {
    if (state == null) return;
    final profile = state!.profiles.firstWhereOrNull((p) => p.id == profileId);
    if (profile == null || profile.isMain) return;
    final updatedProfiles = state!.profiles.where((p) => p.id != profileId).toList();
    String? nextActiveId = state!.activeProfileId;
    if (nextActiveId == profileId) {
      nextActiveId = state!.profiles.firstWhere((p) => p.isMain).id;
    }
    final updated = state!.copyWith(profiles: updatedProfiles, activeProfileId: nextActiveId);
    state = updated;
    _saveLocally(updated);
    _syncToCloud(updated);
  }

  void _saveLocally(UserAccount user) {
    _userBox.put('profile', user.toJson());
  }

  Future<void> signInWithGoogle() async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'io.supabase.flutter://callback',
      );
    } catch (e) {
      // ignore: avoid_print
      print('Error en Google Sign In: $e');
    }
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    await _userBox.delete('profile');
    state = _defaultGuest; // Volver a invitado en lugar de null
  }
}
