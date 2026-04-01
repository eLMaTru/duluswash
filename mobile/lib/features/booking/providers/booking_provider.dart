import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/booking_repository.dart';
import '../models/booking_model.dart';
import '../../auth/providers/auth_provider.dart';

// Active booking id (persists during the session)
final activeBookingIdProvider = StateProvider<String?>((ref) => null);

// Watch active booking in real time
final activeBookingProvider = StreamProvider<BookingModel?>((ref) {
  final bookingId = ref.watch(activeBookingIdProvider);
  if (bookingId == null) return Stream.value(null);
  return ref.watch(bookingRepositoryProvider).watchBooking(bookingId);
});

// Create booking notifier
class BookingNotifier extends StateNotifier<AsyncValue<BookingModel?>> {
  final BookingRepository _repo;
  final Ref _ref;

  BookingNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<BookingModel?> createBooking({
    required WashService service,
    required VehicleType vehicleType,
    required double lat,
    required double lng,
    required String address,
  }) async {
    final authState = _ref.read(authProvider);
    if (authState is! AuthAuthenticated) return null;

    state = const AsyncValue.loading();
    try {
      final booking = BookingModel(
        id: '',
        customerId: authState.user.uid,
        customerName: authState.user.name,
        service: service,
        vehicleType: vehicleType,
        lat: lat,
        lng: lng,
        address: address,
        status: BookingStatus.pending,
        createdAt: DateTime.now(),
        totalPrice: service.price,
      );
      final created = await _repo.createBooking(booking);
      _ref.read(activeBookingIdProvider.notifier).state = created.id;
      state = AsyncValue.data(created);
      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<void> cancel(String bookingId) async {
    await _repo.cancelBooking(bookingId);
    _ref.read(activeBookingIdProvider.notifier).state = null;
    state = const AsyncValue.data(null);
  }
}

final bookingNotifierProvider =
    StateNotifierProvider<BookingNotifier, AsyncValue<BookingModel?>>((ref) {
  return BookingNotifier(ref.watch(bookingRepositoryProvider), ref);
});
