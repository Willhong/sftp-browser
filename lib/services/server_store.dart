import 'package:shared_preferences/shared_preferences.dart';

import '../models/server_profile.dart';

class ServerStore {
  static const _profilesKey = 'server_profiles';

  Future<List<ServerProfile>> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    return ServerProfile.decodeList(prefs.getString(_profilesKey));
  }

  Future<void> saveProfiles(List<ServerProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profilesKey, ServerProfile.encodeList(profiles));
  }
}
