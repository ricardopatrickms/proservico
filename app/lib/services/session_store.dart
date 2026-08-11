import 'package:shared_preferences/shared_preferences.dart';

import '../data/mock_store.dart';
import '../models/user.dart';

class SessionStore {
  SessionStore._();
  static final SessionStore instance = SessionStore._();

  static const _tokenKey = 'access_token';

  String? accessToken;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString(_tokenKey);
  }

  Future<void> saveSession({
    required String token,
    required AppUser user,
  }) async {
    accessToken = token;
    MockStore.instance.currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clear() async {
    accessToken = null;
    MockStore.instance.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}
