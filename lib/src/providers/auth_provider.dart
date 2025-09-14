import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';


class AuthProvider extends ChangeNotifier {
  final AuthService _auth = AuthService();
  User? user;

  AuthProvider() {
    _auth.authStateChanges().listen((u) {
      user = u;
      notifyListeners();
    });
  }

  Future<void> signIn(String email, String pass) async {
    await _auth.signIn(email, pass);
  }

  Future<void> signUp(String email, String pass) async {
    await _auth.signUp(email, pass);
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
