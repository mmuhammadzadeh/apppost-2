import 'dart:async';
import 'dart:convert';

import 'api_service.dart';
import 'user.dart';

class SessionManager {
  static const String _keyUser = 'current_user_json';
  static Timer? _presenceTimer;
  static User? _currentUser;

  static Future<void> saveSession(User user) async {
    _currentUser = user;
    _startPresence(user);
  }

  static Future<User?> restoreSession() async {
    if (_currentUser != null) {
      _startPresence(_currentUser!);
      return _currentUser;
    }
    return null;
  }

  static Future<void> clearSession(User user) async {
    _stopPresence();
    try {
      if (user.token != null) {
        await ApiService.logout(token: user.token!, userId: user.id);
      }
    } catch (_) {}
    _currentUser = null;
  }

  static void _startPresence(User user) {
    _stopPresence();
    if (user.token == null) return;
    // First immediate ping
    ApiService.pingPresence(
      token: user.token!,
      userId: user.id,
    ).catchError((e) => print('Initial pingPresence error: $e'));
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
