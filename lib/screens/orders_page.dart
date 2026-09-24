import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';
import 'report_product_page.dart';
import '../services/cart_service.dart';
import 'cart_page.dart';

class OrdersPage extends StatelessWidget {
  final List<MedicineOrder> orders;

  const OrdersPage({super.key, required this.orders});

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

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Text(
              'Your Orders',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),
        ),
        if (orders.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'No orders yet',
              message: 'Orders you place will show up here with live status\nand delivery details.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final order = orders[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: SoftCard(
                      onTap: () => _showOrderDetail(context, order),
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
                            '${order.items.length} item(s) â€¢ ${_formatDate(order.date)}',
                            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                          ),
                          const Divider(height: 22),
                          Row(
                            children: [
                              Text(
                                'â‚¹${order.total.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ReportProductPage(order: order),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.flag_outlined, size: 16),
                                label: const Text('Report'),
                                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  CartService.addOrderItems(order);
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const CartPage(),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.replay_rounded, size: 16),
                                label: const Text('Reorder'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: orders.length,
              ),
            ),
          ),
      ],
    );
  }

  void _showOrderDetail(BuildContext context, MedicineOrder order) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 30),
                children: [
                  Center(
                    child: Container(
                      height: 5,
                      width: 44,
                      decoration: BoxDecoration(
                        color: AppColors.blueLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Order ${order.id}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
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
                  const SizedBox(height: 4),
                  Text(
                    'Placed on ${_formatDate(order.date)} â€¢ Paid via ${order.paymentMethod}',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 20),
                  SoftCard(
                    child: Column(
                      children: [
                        for (final item in order.items) ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.name}  Ã—${item.quantity}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text('â‚¹${item.lineTotal.toStringAsFixed(2)}'),
                            ],
                          ),
                          if (item != order.items.last) const SizedBox(height: 10),
                        ],
                        const Divider(height: 28),
                        Row(
                          children: [
                            const Text(
                              'Total paid',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Text(
                              'â‚¹${order.total.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.blueDark,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  TrackingTimeline(status: order.status),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ReportProductPage(order: order),
                              ),
                            );
                          },
                          icon: const Icon(Icons.flag_outlined, size: 18),
                          label: const Text('Report issue'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('Get invoice'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
