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
  });

  final String id;
  final String host;
  final int port;
  final String username;
  final AuthType authType;
  final String? password;
  final String? privateKey;

  String get title => '$username@$host';

  String get authLabel => switch (authType) {
    AuthType.password => 'Password',
    AuthType.privateKey => 'Private key',
  };

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'host': host,
      'port': port,
      'username': username,
      'authType': authType.name,
      'password': password,
      'privateKey': privateKey,
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
}
