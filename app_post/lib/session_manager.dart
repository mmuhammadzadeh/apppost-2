import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'user.dart';

class SessionManager {
  static const String _keyUser = 'current_user_json';
  static Timer? _presenceTimer;

  static Future<void> saveSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUser, jsonEncode(user.toJson()));
    _startPresence(user);
  }

  static Future<User?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyUser);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final user = UserJson.fromJson(map);
      _startPresence(user);
      return user;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearSession(User user) async {
    _stopPresence();
    try {
      if (user.token != null) {
        await ApiService.logout(token: user.token!, userId: user.id);
      }
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUser);
  }

  static void _startPresence(User user) {
    _stopPresence();
    if (user.token == null) return;
    // First immediate ping
    ApiService.pingPresence(token: user.token!, userId: user.id)
        .catchError((e) => print('Initial pingPresence error: $e'));
    _presenceTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      ApiService.pingPresence(
        token: user.token!,
        userId: user.id,
      ).catchError((e) => print('Periodic pingPresence error: $e'));
    });
  }

  static void _stopPresence() {
    _presenceTimer?.cancel();
    _presenceTimer = null;
  }
}


