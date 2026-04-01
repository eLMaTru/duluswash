import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum UserRole { customer, operator, admin }

class AppUser {
  final String uid;
  final String email;
  final String name;
  final UserRole role;

  const AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
  });

  factory AppUser.fromFirestore(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: _parseRole(data['role']),
    );
  }

  static UserRole _parseRole(String? role) {
    switch (role) {
      case 'operator':
        return UserRole.operator;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.customer;
    }
  }
}

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<AppUser> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _fetchUser(credential.user!.uid);
  }

  Future<AppUser> signUp({
    required String email,
    required String password,
    required String name,
    UserRole role = UserRole.customer,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;
    await _db.collection('users').doc(uid).set({
      'email': email,
      'name': name,
      'role': role.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return AppUser(uid: uid, email: email, name: name, role: role);
  }

  Future<AppUser> _fetchUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) throw Exception('Usuario no encontrado');
    return AppUser.fromFirestore(uid, doc.data()!);
  }

  Future<AppUser?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _fetchUser(user.uid);
  }

  Future<void> signOut() => _auth.signOut();
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());
