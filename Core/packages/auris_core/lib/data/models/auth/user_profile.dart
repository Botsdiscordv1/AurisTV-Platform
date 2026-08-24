import 'package:uuid/uuid.dart';
import 'external_connection.dart';

class UserProfile {
  final String id;
  final String name;
  final String? photoUrl;
  final bool isMain;
  final Map<ConnectionType, ExternalConnection> connections;

  UserProfile({
    required this.id,
    required this.name,
    this.photoUrl,
    this.isMain = false,
    this.connections = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'photoUrl': photoUrl,
      'isMain': isMain,
      'connections': connections.map((key, value) => MapEntry(key.name, value.toJson())),
    };
  }

  factory UserProfile.fromJson(Map<dynamic, dynamic> json) {
    final Map<dynamic, dynamic> connMap = json['connections'] ?? {};
    final connections = connMap.map((key, value) {
      final type = ConnectionType.values.byName(key as String);
      return MapEntry(type, ExternalConnection.fromJson(value as Map));
    });

    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      photoUrl: json['photoUrl'] as String?,
      isMain: json['isMain'] as bool? ?? false,
      connections: connections,
    );
  }

  UserProfile copyWith({
    String? name,
    String? photoUrl,
    bool? isMain,
    Map<ConnectionType, ExternalConnection>? connections,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      isMain: isMain ?? this.isMain,
      connections: connections ?? this.connections,
    );
  }

  factory UserProfile.createDefault({String? name, String? photoUrl}) {
    return UserProfile(
      id: const Uuid().v4(),
      name: name ?? 'Nuevo Perfil',
      photoUrl: photoUrl,
      isMain: false,
    );
  }
}
