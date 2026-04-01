import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_repository.dart';
import '../../booking/models/booking_model.dart';
import '../../auth/data/auth_repository.dart';

final adminStatsProvider = StreamProvider<AdminStats>((ref) {
  return ref.watch(adminRepositoryProvider).watchStats();
});

final allBookingsProvider = StreamProvider<List<BookingModel>>((ref) {
  return ref.watch(adminRepositoryProvider).watchAllBookings();
});

final operatorsListProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(adminRepositoryProvider).watchOperators();
});
