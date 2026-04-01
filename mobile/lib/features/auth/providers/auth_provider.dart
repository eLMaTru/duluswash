import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_repository.dart';

// Auth state
sealed class AuthState {}
class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthAuthenticated extends AuthState {
  final AppUser user;
  AuthAuthenticated(this.user);
}
class AuthUnauthenticated extends AuthState {}
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(AuthInitial()) {
    _init();
  }

  Future<void> _init() async {
    state = AuthLoading();
    try {
      final user = await _repo.getCurrentUser();
      state = user != null ? AuthAuthenticated(user) : AuthUnauthenticated();
    } catch (_) {
      state = AuthUnauthenticated();
    }
  }

  Future<void> signIn(String email, String password) async {
    state = AuthLoading();
    try {
      final user = await _repo.signIn(email, password);
      state = AuthAuthenticated(user);
    } on Exception catch (e) {
      state = AuthError(_mapError(e.toString()));
    }
  }

  Future<void> signInWithGoogle() async {
    state = AuthLoading();
    try {
      final user = await _repo.signInWithGoogle();
      state = AuthAuthenticated(user);
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('cancelled')) {
        state = AuthUnauthenticated();
      } else {
        state = AuthError(_mapError(msg));
      }
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = AuthUnauthenticated();
  }

  String _mapError(String e) {
    if (e.contains('user-not-found') || e.contains('wrong-password') || e.contains('invalid-credential')) {
      return 'Correo o contraseña incorrectos';
    }
    if (e.contains('too-many-requests')) {
      return 'Demasiados intentos. Intenta más tarde';
    }
    if (e.contains('network')) {
      return 'Sin conexión a internet';
    }
    return 'Error al iniciar sesión';
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
