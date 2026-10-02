import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:go_router/go_router.dart';

class UserSession {
  static const String _keyEmail = "user_email";
  static const String _keyUsername = "user_username";

  static Future<void> saveUser({required String email, String? username}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEmail, email);
    if (username != null && username.isNotEmpty) {
      await prefs.setString(_keyUsername, username);
    }
  }

  static Future<void> updateUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUsername, username);
  }

  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail);
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUsername);
  }

  static Future<String?> getUserId() async {
    final email = await getEmail();
    if (email != null && email.isNotEmpty) return email;
    return null;
  }

  static Future<bool> isLoggedIn() async {
    final id = await getUserId();
    return id != null && id.isNotEmpty;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyUsername);
  }

  static Future<void> logout(BuildContext context) async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await clear();
    if (context.mounted) {
      context.go('/login');
    }
  }
}

