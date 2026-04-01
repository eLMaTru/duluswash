import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../booking/models/booking_model.dart';

class OperatorRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<BookingModel>> watchPendingBookings() {
    return _db
        .collection('bookings')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => BookingModel.fromFirestore(d.id, d.data()))
            .toList());
  }

  Stream<BookingModel?> watchActiveBooking(String operatorId) {
    return _db
        .collection('bookings')
        .where('operatorId', isEqualTo: operatorId)
        .where('status', whereIn: ['accepted', 'inProgress'])
        .limit(1)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          return BookingModel.fromFirestore(snap.docs.first.id, snap.docs.first.data());
        });
  }

  Future<void> acceptBooking(String bookingId, String operatorId, String operatorName) async {
    await _db.collection('bookings').doc(bookingId).update({
      'status': 'accepted',
      'operatorId': operatorId,
      'operatorName': operatorName,
    });
  }

  Future<void> startBooking(String bookingId) async {
    await _db.collection('bookings').doc(bookingId).update({'status': 'inProgress'});
  }

  Future<void> completeBooking(String bookingId) async {
    await _db.collection('bookings').doc(bookingId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
  }
}

final operatorRepositoryProvider = Provider<OperatorRepository>((ref) => OperatorRepository());
