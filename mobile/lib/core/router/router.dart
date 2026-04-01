import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/booking/models/booking_model.dart';
import '../../features/booking/presentation/booking_confirmation_screen.dart';
import '../../features/booking/presentation/booking_status_screen.dart';
import '../../features/booking/presentation/home_screen.dart';
import '../../features/booking/presentation/service_selection_screen.dart';
import '../../features/operator/presentation/operator_home_screen.dart';
import '../../features/admin/presentation/admin_home_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final isOnSplash = loc == '/splash';
      final isOnLogin = loc == '/login';
      final isOnBookingFlow = loc.startsWith('/booking');

      if (authState is AuthInitial || authState is AuthLoading) {
        return isOnSplash ? null : '/splash';
      }
      if (authState is AuthUnauthenticated || authState is AuthError) {
        return isOnLogin ? null : '/login';
      }
      if (authState is AuthAuthenticated) {
        if (isOnSplash || isOnLogin) return _homeForRole(authState.user.role);
        if (isOnBookingFlow && authState.user.role != UserRole.customer) return _homeForRole(authState.user.role);
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/operator', builder: (_, __) => const OperatorHomeScreen()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminHomeScreen()),
      GoRoute(path: '/booking/services', builder: (_, __) => const ServiceSelectionScreen()),
      GoRoute(
        path: '/booking/confirm',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>;
          return BookingConfirmationScreen(
            service: extra['service'] as WashService,
            vehicleType: extra['vehicleType'] as VehicleType,
          );
        },
      ),
      GoRoute(path: '/booking/status', builder: (_, __) => const BookingStatusScreen()),
    ],
  );
});

String _homeForRole(UserRole role) {
  switch (role) {
    case UserRole.operator:
      return '/operator';
    case UserRole.admin:
      return '/admin';
    case UserRole.customer:
      return '/home';
  }
}
