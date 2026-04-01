import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/theme/app_theme.dart';
import '../models/booking_model.dart';
import '../providers/booking_provider.dart';

class BookingConfirmationScreen extends ConsumerStatefulWidget {
  final WashService service;
  final VehicleType vehicleType;

  const BookingConfirmationScreen({
    super.key,
    required this.service,
    required this.vehicleType,
  });

  @override
  ConsumerState<BookingConfirmationScreen> createState() => _BookingConfirmationScreenState();
}

class _BookingConfirmationScreenState extends ConsumerState<BookingConfirmationScreen> {
  Position? _position;
  String _address = 'Obteniendo ubicación...';
  bool _loadingLocation = true;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() { _address = 'Permiso de ubicación denegado'; _loadingLocation = false; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      setState(() { _position = pos; _address = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}'; _loadingLocation = false; });
    } catch (e) {
      setState(() { _address = 'No se pudo obtener la ubicación'; _loadingLocation = false; });
    }
  }

  Future<void> _confirm() async {
    if (_position == null) return;
    final booking = await ref.read(bookingNotifierProvider.notifier).createBooking(
      service: widget.service,
      vehicleType: widget.vehicleType,
      lat: _position!.latitude,
      lng: _position!.longitude,
      address: _address,
    );
    if (booking != null && mounted) {
      context.go('/booking/status');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(bookingNotifierProvider);
    final isLoading = bookingState is AsyncLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar pedido')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryCard(
                    title: 'Servicio',
                    child: Row(
                      children: [
                        Text(widget.service.icon, style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.service.name,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                              Text(widget.service.description,
                                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SummaryCard(
                    title: 'Vehículo',
                    child: Row(
                      children: [
                        const Icon(Icons.directions_car, color: AppTheme.primary),
                        const SizedBox(width: 12),
                        Text(widget.vehicleType.name.toUpperCase(),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SummaryCard(
                    title: 'Ubicación',
                    child: Row(
                      children: [
                        _loadingLocation
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.location_on, color: AppTheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(_address,
                              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        Text(
                          'RD\$${widget.service.price.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: (isLoading || _loadingLocation || _position == null) ? null : _confirm,
              child: isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Confirmar pedido'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SummaryCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
