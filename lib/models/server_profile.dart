import 'dart:convert';

enum AuthType { password, privateKey }

class ServerProfile {
  const ServerProfile({
    required this.id,
    required this.host,
    required this.port,
    required this.username,
    required this.authType,
    this.password,
    this.privateKey,
    this.favoritePaths = const [],
  });

  final String id;
  final String host;
  final int port;
  final String username;
  final AuthType authType;
  final String? password;
  final String? privateKey;
  final List<String> favoritePaths;

  String get title => '$username@$host';

  String get authLabel => switch (authType) {
    AuthType.password => 'Password',
    AuthType.privateKey => 'Private key',
  };

  ServerProfile copyWith({
    String? id,
    String? host,
    int? port,
    String? username,
    AuthType? authType,
    String? password,
    String? privateKey,
    List<String>? favoritePaths,
  }) {
    return ServerProfile(
      id: id ?? this.id,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      authType: authType ?? this.authType,
      password: password ?? this.password,
      privateKey: privateKey ?? this.privateKey,
      favoritePaths:
          favoritePaths == null
              ? this.favoritePaths
              : _sanitizeFavoritePaths(favoritePaths),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'host': host,
      'port': port,
      'username': username,
      'authType': authType.name,
      'password': password,
      'privateKey': privateKey,
      'favoritePaths': favoritePaths,
    };
  }

  factory ServerProfile.fromMap(Map<String, dynamic> map) {
    final authTypeName = map['authType'] as String? ?? AuthType.password.name;
    return ServerProfile(
      id:
          map['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      host: map['host'] as String? ?? '',
      port: (map['port'] as num?)?.toInt() ?? 22,
      username: map['username'] as String? ?? '',
      authType: AuthType.values.firstWhere(
        (value) => value.name == authTypeName,
        orElse: () => AuthType.password,
      ),
      password: map['password'] as String?,
      privateKey: map['privateKey'] as String?,
      favoritePaths: _sanitizeFavoritePaths(map['favoritePaths'] as List?),
    );
  }

  static String encodeList(List<ServerProfile> profiles) {
    return jsonEncode(profiles.map((profile) => profile.toMap()).toList());
  }

  static List<ServerProfile> decodeList(String? rawJson) {
    if (rawJson == null || rawJson.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(rawJson);
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map>()
        .map((item) => ServerProfile.fromMap(item.cast<String, dynamic>()))
        .toList();
  }

  static List<String> _sanitizeFavoritePaths(List? favoritePaths) {
    if (favoritePaths == null) {
      return const [];
    }

    final sanitized = <String>[];
    for (final rawPath in favoritePaths.whereType<String>()) {
      final path = rawPath.trim();
      if (path.isEmpty || sanitized.contains(path)) {
        continue;
      }
      sanitized.add(path);
    }
    return List<String>.unmodifiable(sanitized);
  }
}
