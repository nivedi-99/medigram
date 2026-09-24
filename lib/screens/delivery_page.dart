import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

/// Delivery & shipment tracking for the signed-in buyer. One card per order
/// that has been dispatched, with courier, tracking reference and ETA derived
/// from the order record. Values are indicative for the B2B flow.
class DeliveryPage extends StatelessWidget {
  final List<MedicineOrder> orders;

  const DeliveryPage({super.key, required this.orders});

  List<MedicineOrder> get _shipments {
    final list = orders
        .where((o) =>
            o.status == OrderStatus.shipped ||
            o.status == OrderStatus.delivered)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.processing:
        return AppColors.warning;
      case OrderStatus.shipped:
        return AppColors.blueDark;
      case OrderStatus.delivered:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.danger;
    }
  }

  String _courierFor(MedicineOrder order) {
    const couriers = ['DHL Express', 'FedEx International', 'MediGram Air Cargo'];
    return couriers[order.uuid.hashCode.abs() % couriers.length];
  }

  String _trackingFor(MedicineOrder order) {
    final digits = order.id.replaceAll(RegExp(r'[^0-9]'), '');
    final tail = digits.length >= 6
        ? digits.substring(digits.length - 6)
        : digits.padLeft(6, '0');
    return 'MG-$tail-IN';
  }

  String _etaText(MedicineOrder order) {
    if (order.status == OrderStatus.delivered) {
      return 'Delivered ${_formatDate(order.date.add(const Duration(days: 7)))}';
    }
    return 'Estimated ${_formatDate(order.date.add(const Duration(days: 10)))}';
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final shipments = _shipments;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Text(
              'Delivery',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),
        ),
        if (shipments.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'No shipments yet',
              message:
                  'Once an order is dispatched it will appear here with\ncourier, tracking ID and delivery estimates.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _shipmentCard(shipments[index]),
                childCount: shipments.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _shipmentCard(MedicineOrder order) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.id,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                StatusChip(
                  label: order.status.label,
                  color: _statusColor(order.status),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${order.items.length} item(s) • dispatched from Nagpur, IN',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
            const Divider(height: 22),
            _infoRow(
                Icons.flight_takeoff_rounded, 'Courier', _courierFor(order)),
            _infoRow(Icons.qr_code_2_rounded, 'Tracking', _trackingFor(order)),
            _infoRow(Icons.event_available_rounded, 'ETA', _etaText(order)),
            const Divider(height: 22),
            TrackingTimeline(status: order.status),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.blueDark),
          const SizedBox(width: 10),
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}