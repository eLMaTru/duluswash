import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus {
  pending,
  accepted,
  inProgress,
  completed,
  cancelled,
}

enum VehicleType { sedan, suv, truck, van }

class WashService {
  final String id;
  final String name;
  final String description;
  final double price;
  final int durationMinutes;
  final String icon;

  const WashService({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.durationMinutes,
    required this.icon,
  });

  static const List<WashService> catalog = [
    WashService(
      id: 'basic',
      name: 'Lavado Básico',
      description: 'Exterior + llantas + secado',
      price: 500,
      durationMinutes: 30,
      icon: '🚿',
    ),
    WashService(
      id: 'premium',
      name: 'Lavado Premium',
      description: 'Exterior + interior + llantas + secado + aspirado',
      price: 900,
      durationMinutes: 60,
      icon: '✨',
    ),
    WashService(
      id: 'full_detail',
      name: 'Full Detail',
      description: 'Premium + encerado + limpieza profunda de interior',
      price: 1800,
      durationMinutes: 120,
      icon: '💎',
    ),
  ];
}

class BookingModel {
  final String id;
  final String customerId;
  final String customerName;
  final WashService service;
  final VehicleType vehicleType;
  final double lat;
  final double lng;
  final String address;
  final BookingStatus status;
  final String? operatorId;
  final String? operatorName;
  final DateTime createdAt;
  final double totalPrice;

  const BookingModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.service,
    required this.vehicleType,
    required this.lat,
    required this.lng,
    required this.address,
    required this.status,
    required this.createdAt,
    required this.totalPrice,
    this.operatorId,
    this.operatorName,
  });

  factory BookingModel.fromFirestore(String id, Map<String, dynamic> d) {
    final serviceId = d['serviceId'] as String;
    final service = WashService.catalog.firstWhere(
      (s) => s.id == serviceId,
      orElse: () => WashService.catalog.first,
    );
    return BookingModel(
      id: id,
      customerId: d['customerId'] ?? '',
      customerName: d['customerName'] ?? '',
      service: service,
      vehicleType: VehicleType.values.firstWhere(
        (v) => v.name == d['vehicleType'],
        orElse: () => VehicleType.sedan,
      ),
      lat: (d['lat'] as num).toDouble(),
      lng: (d['lng'] as num).toDouble(),
      address: d['address'] ?? '',
      status: BookingStatus.values.firstWhere(
        (s) => s.name == d['status'],
        orElse: () => BookingStatus.pending,
      ),
      operatorId: d['operatorId'],
      operatorName: d['operatorName'],
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      totalPrice: (d['totalPrice'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'customerId': customerId,
        'customerName': customerName,
        'serviceId': service.id,
        'serviceName': service.name,
        'vehicleType': vehicleType.name,
        'lat': lat,
        'lng': lng,
        'address': address,
        'status': status.name,
        'operatorId': operatorId,
        'operatorName': operatorName,
        'createdAt': FieldValue.serverTimestamp(),
        'totalPrice': totalPrice,
      };
}
