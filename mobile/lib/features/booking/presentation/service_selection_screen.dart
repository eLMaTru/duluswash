import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../models/booking_model.dart';

class ServiceSelectionScreen extends StatefulWidget {
  const ServiceSelectionScreen({super.key});

  @override
  State<ServiceSelectionScreen> createState() => _ServiceSelectionScreenState();
}

class _ServiceSelectionScreenState extends State<ServiceSelectionScreen> {
  WashService? _selectedService;
  VehicleType _vehicleType = VehicleType.sedan;

  static const _vehicleLabels = {
    VehicleType.sedan: 'Sedan',
    VehicleType.suv: 'SUV',
    VehicleType.truck: 'Pickup',
    VehicleType.van: 'Van',
  };

  static const _vehicleIcons = {
    VehicleType.sedan: Icons.directions_car,
    VehicleType.suv: Icons.directions_car_filled,
    VehicleType.truck: Icons.local_shipping,
    VehicleType.van: Icons.airport_shuttle,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seleccionar servicio')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tipo de vehículo',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 12),
                  Row(
                    children: VehicleType.values.map((v) {
                      final selected = _vehicleType == v;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _vehicleType = v),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: selected ? AppTheme.primary : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: selected ? Border.all(color: AppTheme.primary, width: 2) : null,
                            ),
                            child: Column(
                              children: [
                                Icon(_vehicleIcons[v], color: selected ? Colors.white : AppTheme.textSecondary, size: 22),
                                const SizedBox(height: 4),
                                Text(
                                  _vehicleLabels[v]!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: selected ? Colors.white : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),
                  const Text('Servicio',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 12),
                  ...WashService.catalog.map((s) => _ServiceCard(
                        service: s,
                        selected: _selectedService?.id == s.id,
                        onTap: () => setState(() => _selectedService = s),
                      )),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: _selectedService == null
                  ? null
                  : () => context.push('/booking/confirm', extra: {
                        'service': _selectedService,
                        'vehicleType': _vehicleType,
                      }),
              child: const Text('Continuar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final WashService service;
  final bool selected;
  final VoidCallback onTap;

  const _ServiceCard({required this.service, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.primary : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(service.icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(service.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(service.description,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Text('~${service.durationMinutes} min',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('RD\$${service.price.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                if (selected)
                  const Icon(Icons.check_circle, color: AppTheme.primary, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
