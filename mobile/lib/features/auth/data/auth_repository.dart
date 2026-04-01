import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

// TODO: replace with real API URL when deployed
const String _apiBaseUrl = 'http://localhost:3000';

enum UserRole { customer, operator, admin }

class AppUser {
  final String id;
  final String uid;
  final String email;
  final String name;
  final UserRole role;

  const AppUser({
    required this.id,
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
  });

  factory AppUser.fromJson(String firebaseUid, Map<String, dynamic> data) {
    return AppUser(
      id: data['id'] ?? '',
      uid: firebaseUid,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: _parseRole(data['role']),
    );
  }

  static UserRole _parseRole(String? role) {
    switch (role) {
      case 'operator': return UserRole.operator;
      case 'admin':    return UserRole.admin;
      default:         return UserRole.customer;
    }
  }
}

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _google = GoogleSignIn();

  Future<AppUser> _syncWithBackend(User firebaseUser) async {
    final token = await firebaseUser.getIdToken();
    final res = await http.post(
      Uri.parse('$_apiBaseUrl/api/v1/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) throw Exception('Error al sincronizar usuario');
    final data = jsonDecode(res.body)['user'];
    return AppUser.fromJson(firebaseUser.uid, data);
  }

  Future<AppUser> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email, password: password,
    );
    return _syncWithBackend(credential.user!);
  }

  Future<AppUser> signInWithGoogle() async {
    final googleUser = await _google.signIn();
    if (googleUser == null) throw Exception('cancelled');

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    return _syncWithBackend(userCredential.user!);
  }

  Future<AppUser?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      return await _syncWithBackend(user);
    } catch (_) {
      return null;
    }
  }

  Future<void> signOut() async {
    await _google.signOut();
    await _auth.signOut();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());
