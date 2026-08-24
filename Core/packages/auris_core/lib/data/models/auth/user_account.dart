import 'external_connection.dart';
import 'user_profile.dart';

class UserAccount {
  final String id;
  final String? email;
  final List<UserProfile> profiles;
  final String? activeProfileId;

  UserAccount({
    required this.id,
    this.email,
    this.profiles = const [],
    this.activeProfileId,
  });

  UserProfile? get activeProfile {
    if (activeProfileId == null || profiles.isEmpty) return null;
    return profiles.firstWhere((p) => p.id == activeProfileId, orElse: () => profiles.first);
  }

  String? get displayName => activeProfile?.name;
  String? get photoUrl => activeProfile?.photoUrl;

  bool get isAnilistConnected => activeProfile?.connections.containsKey(ConnectionType.anilist) ?? false;
  bool get isTraktConnected => activeProfile?.connections.containsKey(ConnectionType.trakt) ?? false;
  
  ExternalConnection? get anilistConnection => activeProfile?.connections[ConnectionType.anilist];
  ExternalConnection? get traktConnection => activeProfile?.connections[ConnectionType.trakt];
  
  Map<ConnectionType, ExternalConnection> get connections => activeProfile?.connections ?? {};

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'profiles': profiles.map((p) => p.toJson()).toList(),
      'activeProfileId': activeProfileId,
    };
  }

  factory UserAccount.fromJson(Map<dynamic, dynamic> json) {
    final profilesList = (json['profiles'] as List<dynamic>?)
            ?.map((p) => UserProfile.fromJson(p as Map))
            .toList() ??
        [];

    return UserAccount(
      id: json['id'] as String,
      email: json['email'] as String?,
      profiles: profilesList,
      activeProfileId: json['activeProfileId'] as String?,
    );
  }

  UserAccount copyWith({
    List<UserProfile>? profiles,
    String? activeProfileId,
  }) {
    return UserAccount(
      id: id,
      email: email,
      profiles: profiles ?? this.profiles,
      activeProfileId: activeProfileId ?? this.activeProfileId,
    );
  }
}
