import 'package:flutter/material.dart';
import 'package:attendance/services/local_storage_service.dart';

class UserProvider extends ChangeNotifier {
  Map<String, dynamic>? _userData;

  // ============================================================
  // GETTERS
  // ============================================================

  Map<String, dynamic>? get userData => _userData;

  bool get isLoggedIn => _userData != null;

  String get role {
    return (_userData?['role'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
  }

  String get uid {
    return (_userData?['uid'] ?? '').toString();
  }

  String get email {
    return (_userData?['email'] ?? '').toString();
  }

  String get fullName {
    return (_userData?['fullName'] ?? '').toString();
  }

  // ============================================================
  // SET USER
  // ============================================================

  void setUser(Map<String, dynamic> data) {
    _userData = Map<String, dynamic>.from(data);

    notifyListeners();
  }

  // ============================================================
  // SAVE USER LOCALLY
  // ============================================================

  Future<void> saveUser(Map<String, dynamic> data) async {
    _userData = Map<String, dynamic>.from(data);

    await LocalStorageService.saveUserSession(_userData!);

    notifyListeners();
  }

  // ============================================================
  // LOAD CACHED USER
  // ============================================================

  void loadCachedUser() {
    final cachedUser =
    LocalStorageService.getUserSession();

    if (cachedUser == null) {
      return;
    }

    _userData = cachedUser;

    notifyListeners();
  }

  // ============================================================
  // CLEAR USER
  // ============================================================

  Future<void> clearUser() async {
    _userData = null;

    await LocalStorageService.clearUserSession();

    notifyListeners();
  }
}