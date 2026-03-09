import 'dart:convert';
import 'dart:io';

class SharedPreferences {
  SharedPreferences._(this._file, this._values);

  static SharedPreferences? _instance;

  final File _file;
  final Map<String, Object?> _values;

  static Future<SharedPreferences> getInstance() async {
    if (_instance != null) {
      return _instance!;
    }

    final directory = Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}sftp_browser_prefs',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final file = File(
      '${directory.path}${Platform.pathSeparator}shared_preferences.json',
    );

    Map<String, Object?> values = <String, Object?>{};
    if (await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) {
          values = decoded;
        }
      } catch (_) {
        values = <String, Object?>{};
      }
    }

    _instance = SharedPreferences._(file, values);
    return _instance!;
  }

  String? getString(String key) => _values[key] as String?;

  Future<bool> setString(String key, String value) async {
    _values[key] = value;
    await _flush();
    return true;
  }

  Future<void> _flush() async {
    await _file.writeAsString(jsonEncode(_values), flush: true);
  }
}
