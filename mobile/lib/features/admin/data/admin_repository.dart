import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../booking/models/booking_model.dart';
import '../../auth/data/auth_repository.dart';

class AdminStats {
  final int totalBookings;
  final int pendingBookings;
  final int completedBookings;
  final int cancelledBookings;
  final double totalRevenue;
  final int totalOperators;
  final int totalCustomers;

  const AdminStats({
    required this.totalBookings,
    required this.pendingBookings,
    required this.completedBookings,
    required this.cancelledBookings,
    required this.totalRevenue,
    required this.totalOperators,
    required this.totalCustomers,
  });
}

class AdminRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<BookingModel>> watchAllBookings() {
    return _db
        .collection('bookings')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map((d) => BookingModel.fromFirestore(d.id, d.data())).toList());
  }

  Stream<AdminStats> watchStats() {
    return _db.collection('bookings').snapshots().asyncMap((snap) async {
      final bookings = snap.docs.map((d) => d.data()).toList();

      final usersSnap = await _db.collection('users').get();
      final operators = usersSnap.docs.where((d) => d.data()['role'] == 'operator').length;
      final customers = usersSnap.docs.where((d) => d.data()['role'] == 'customer').length;

      return AdminStats(
        totalBookings: bookings.length,
        pendingBookings: bookings.where((b) => b['status'] == 'pending').length,
        completedBookings: bookings.where((b) => b['status'] == 'completed').length,
        cancelledBookings: bookings.where((b) => b['status'] == 'cancelled').length,
        totalRevenue: bookings
            .where((b) => b['status'] == 'completed')
            .fold(0.0, (sum, b) => sum + ((b['totalPrice'] as num?)?.toDouble() ?? 0)),
        totalOperators: operators,
        totalCustomers: customers,
      );
    });
  }

  Stream<List<AppUser>> watchOperators() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'operator')
        .snapshots()
        .map((s) => s.docs.map((d) => AppUser.fromFirestore(d.id, d.data())).toList());
  }

  Future<void> updateBookingStatus(String bookingId, BookingStatus status) async {
    await _db.collection('bookings').doc(bookingId).update({'status': status.name});
  }
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) => AdminRepository());
