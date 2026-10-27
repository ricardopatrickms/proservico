import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';

class SessionStore {
  SessionStore._();
  static final SessionStore instance = SessionStore._();

  static const _tokenKey = 'access_token';
  static const _userKey = 'current_user';

  String? accessToken;
  AppUser? currentUser;

  bool get isLoggedIn => accessToken != null && accessToken!.isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString(_tokenKey);

    final userJson = prefs.getString(_userKey);
    if (userJson == null || userJson.isEmpty) return;

    try {
      final decoded = jsonDecode(userJson);
      if (decoded is Map<String, dynamic>) {
        currentUser = AppUser.fromCache(decoded);
      }
    } catch (_) {
      await prefs.remove(_userKey);
    }
  }

  Future<void> saveSession({
    required String token,
    required AppUser user,
  }) async {
    accessToken = token;
    currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user.toCacheJson()));
  }

  Future<void> updateToken(String token) async {
    accessToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clear() async {
    accessToken = null;
    currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}
