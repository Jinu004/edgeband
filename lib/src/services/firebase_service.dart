import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  static Future<void> init() async {
    await Firebase.initializeApp();
    // Optionally: FirebaseDatabase.instance.setPersistenceEnabled(true);
  }

  static FirebaseAuth auth() => FirebaseAuth.instance;
}
