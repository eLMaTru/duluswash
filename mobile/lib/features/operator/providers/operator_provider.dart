import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/operator_repository.dart';
import '../../booking/models/booking_model.dart';
import '../../auth/providers/auth_provider.dart';

final pendingBookingsProvider = StreamProvider<List<BookingModel>>((ref) {
  return ref.watch(operatorRepositoryProvider).watchPendingBookings();
});

final operatorActiveBookingProvider = StreamProvider<BookingModel?>((ref) {
  final authState = ref.watch(authProvider);
  if (authState is! AuthAuthenticated) return Stream.value(null);
  return ref.watch(operatorRepositoryProvider).watchActiveBooking(authState.user.uid);
});

class OperatorActionNotifier extends StateNotifier<AsyncValue<void>> {
  final OperatorRepository _repo;
  final Ref _ref;

  OperatorActionNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<void> accept(String bookingId) async {
    final authState = _ref.read(authProvider);
    if (authState is! AuthAuthenticated) return;
    state = const AsyncValue.loading();
    try {
      await _repo.acceptBooking(bookingId, authState.user.uid, authState.user.name);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> start(String bookingId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.startBooking(bookingId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> complete(String bookingId) async {
    state = const AsyncValue.loading();
    try {
      await _repo.completeBooking(bookingId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final operatorActionProvider =
    StateNotifierProvider<OperatorActionNotifier, AsyncValue<void>>((ref) {
  return OperatorActionNotifier(ref.watch(operatorRepositoryProvider), ref);
});
