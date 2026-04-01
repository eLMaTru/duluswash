import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../booking/models/booking_model.dart';
import '../providers/operator_provider.dart';

class OperatorHomeScreen extends ConsumerWidget {
  const OperatorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final name = authState is AuthAuthenticated ? authState.user.name : '';
    final activeBookingAsync = ref.watch(operatorActiveBookingProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(name.isNotEmpty ? 'Hola, $name' : 'Panel Operador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
      body: activeBookingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (activeBooking) {
          if (activeBooking != null) {
            return _ActiveBookingView(booking: activeBooking);
          }
          return _PendingBookingsList();
        },
      ),
    );
  }
}

// ─── Active booking ───────────────────────────────────────────────────────────

class _ActiveBookingView extends ConsumerWidget {
  final BookingModel booking;
  const _ActiveBookingView({required this.booking});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionState = ref.watch(operatorActionProvider);
    final isLoading = actionState is AsyncLoading;

    final isPending = booking.status == BookingStatus.accepted;
    final isInProgress = booking.status == BookingStatus.inProgress;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.local_car_wash, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPending ? '⏳ Pedido aceptado' : '🚿 En progreso',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primary),
                      ),
                      Text(booking.service.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _DetailRow(icon: Icons.person, label: 'Cliente', value: booking.customerName),
          _DetailRow(icon: Icons.location_on, label: 'Ubicación', value: booking.address),
          _DetailRow(icon: Icons.directions_car, label: 'Vehículo', value: booking.vehicleType.name.toUpperCase()),
          _DetailRow(icon: Icons.attach_money, label: 'Total', value: 'RD\$${booking.totalPrice.toStringAsFixed(0)}'),
          _DetailRow(icon: Icons.timer, label: 'Duración estimada', value: '~${booking.service.durationMinutes} min'),
          const Spacer(),
          if (isPending)
            ElevatedButton.icon(
              onPressed: isLoading ? null : () => ref.read(operatorActionProvider.notifier).start(booking.id),
              icon: const Icon(Icons.play_arrow),
              label: isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Iniciar lavado'),
            ),
          if (isInProgress)
            ElevatedButton.icon(
              onPressed: isLoading ? null : () => ref.read(operatorActionProvider.notifier).complete(booking.id),
              icon: const Icon(Icons.check_circle),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E)),
              label: isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Marcar como completado'),
            ),
        ],
      ),
    );
  }
}

// ─── Pending bookings list ────────────────────────────────────────────────────

class _PendingBookingsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingBookingsProvider);
    final actionState = ref.watch(operatorActionProvider);
    final isLoading = actionState is AsyncLoading;

    return pendingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (bookings) {
        if (bookings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('Sin pedidos pendientes', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('Los nuevos pedidos aparecerán aquí', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                '${bookings.length} pedido${bookings.length > 1 ? 's' : ''} disponible${bookings.length > 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: bookings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _BookingCard(
                  booking: bookings[i],
                  isLoading: isLoading,
                  onAccept: () => ref.read(operatorActionProvider.notifier).accept(bookings[i].id),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  final bool isLoading;
  final VoidCallback onAccept;

  const _BookingCard({required this.booking, required this.isLoading, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(booking.service.icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.service.name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    Text(booking.customerName,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Text(
                'RD\$${booking.totalPrice.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(booking.address,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.timer_outlined, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text('~${booking.service.durationMinutes} min',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : onAccept,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
              child: isLoading
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Aceptar pedido'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }
}
