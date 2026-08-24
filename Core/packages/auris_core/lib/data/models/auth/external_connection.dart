enum ConnectionType {
  anilist,
  trakt,
  simkl,
}

class ExternalConnection {
  final ConnectionType type;
  final String accessToken;
  final String? refreshToken;
  final String username;
  final DateTime? lastSynced;
  final String? externalUserId;

  ExternalConnection({
    required this.type,
    required this.accessToken,
    this.refreshToken,
    required this.username,
    this.lastSynced,
    this.externalUserId,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'username': username,
      'lastSynced': lastSynced?.toIso8601String(),
      'externalUserId': externalUserId,
    };
  }

  factory ExternalConnection.fromJson(Map<dynamic, dynamic> json) {
    return ExternalConnection(
      type: ConnectionType.values.byName(json['type']),
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
      username: json['username'] as String,
      lastSynced: json['lastSynced'] != null ? DateTime.parse(json['lastSynced'] as String) : null,
      externalUserId: json['externalUserId'] as String?,
    );
  }

  ExternalConnection copyWith({
    String? accessToken,
    String? refreshToken,
    String? username,
    DateTime? lastSynced,
  }) {
    return ExternalConnection(
      type: type,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      username: username ?? this.username,
      lastSynced: lastSynced ?? this.lastSynced,
      externalUserId: externalUserId,
    );
  }
}
