import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../models/booking_model.dart';
import '../providers/booking_provider.dart';

class BookingStatusScreen extends ConsumerWidget {
  const BookingStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingAsync = ref.watch(activeBookingProvider);

    return bookingAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (booking) {
        if (booking == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: AppTheme.primary, size: 64),
                  const SizedBox(height: 16),
                  const Text('¡Listo!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  ElevatedButton(onPressed: () => context.go('/home'), child: const Text('Volver al inicio')),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Estado del pedido'),
            automaticallyImplyLeading: false,
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _StatusStepper(status: booking.status),
                const SizedBox(height: 32),
                _StatusInfo(booking: booking),
                const Spacer(),
                if (booking.status == BookingStatus.pending)
                  OutlinedButton(
                    onPressed: () async {
                      await ref.read(bookingNotifierProvider.notifier).cancel(booking.id);
                      if (context.mounted) context.go('/home');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.error),
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancelar pedido'),
                  ),
                if (booking.status == BookingStatus.completed) ...[
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context.go('/home'),
                    child: const Text('Volver al inicio'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusStepper extends StatelessWidget {
  final BookingStatus status;
  const _StatusStepper({required this.status});

  static const _steps = [
    (BookingStatus.pending, 'Buscando operador', Icons.search),
    (BookingStatus.accepted, 'Operador en camino', Icons.directions_bike),
    (BookingStatus.inProgress, 'Lavando tu vehículo', Icons.local_car_wash),
    (BookingStatus.completed, 'Completado', Icons.check_circle),
  ];

  int get _currentIndex => _steps.indexWhere((s) => s.$1 == status);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: List.generate(_steps.length, (i) {
          final step = _steps[i];
          final done = i < _currentIndex;
          final active = i == _currentIndex;
          final color = done || active ? AppTheme.primary : const Color(0xFFCBD5E1);

          return Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: done || active ? AppTheme.primary : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      done ? Icons.check : step.$3,
                      color: done || active ? Colors.white : const Color(0xFFCBD5E1),
                      size: 18,
                    ),
                  ),
                  if (i < _steps.length - 1)
                    Container(width: 2, height: 24, color: i < _currentIndex ? AppTheme.primary : const Color(0xFFE2E8F0)),
                ],
              ),
              const SizedBox(width: 14),
              Padding(
                padding: EdgeInsets.only(bottom: i < _steps.length - 1 ? 24 : 0),
                child: Text(
                  step.$2,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    color: active ? AppTheme.textPrimary : color,
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _StatusInfo extends StatelessWidget {
  final BookingModel booking;
  const _StatusInfo({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          _Row('Servicio', booking.service.name),
          _Row('Total', 'RD\$${booking.totalPrice.toStringAsFixed(0)}'),
          if (booking.operatorName != null) _Row('Operador', booking.operatorName!),
          _Row('Duración estimada', '~${booking.service.durationMinutes} min'),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }
}
