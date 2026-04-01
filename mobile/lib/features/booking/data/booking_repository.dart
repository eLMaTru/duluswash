import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/booking_model.dart';

class BookingRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<BookingModel> createBooking(BookingModel booking) async {
    final doc = await _db.collection('bookings').add(booking.toMap());
    return BookingModel.fromFirestore(doc.id, {
      ...booking.toMap(),
      'createdAt': Timestamp.now(),
    });
  }

  Stream<BookingModel?> watchBooking(String bookingId) {
    return _db.collection('bookings').doc(bookingId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return BookingModel.fromFirestore(snap.id, snap.data()!);
    });
  }

  Stream<List<BookingModel>> watchCustomerBookings(String customerId) {
    return _db
        .collection('bookings')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => BookingModel.fromFirestore(d.id, d.data()))
            .toList());
  }

  Future<void> cancelBooking(String bookingId) async {
    await _db.collection('bookings').doc(bookingId).update({'status': 'cancelled'});
  }
}

final bookingRepositoryProvider = Provider<BookingRepository>((ref) => BookingRepository());
