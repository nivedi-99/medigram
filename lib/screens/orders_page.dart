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
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
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
                                  style: const TextStyle(
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
                            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                          ),
                          const Divider(height: 22),
                          Row(
                            children: [
                              Text(
                                'â‚¹${order.total.toStringAsFixed(2)}',
                                style: const TextStyle(
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
              decoration: const BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                          style: const TextStyle(
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
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
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
                              style: const TextStyle(
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
                  _TrackingTimeline(status: order.status),
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
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _TrackingTimeline extends StatelessWidget {
  final OrderStatus status;

  const _TrackingTimeline({required this.status});

  @override
  Widget build(BuildContext context) {
    final steps = ['Processing', 'Shipped', 'Out for delivery', 'Delivered'];
    int activeIndex;
    switch (status) {
      case OrderStatus.processing:
        activeIndex = 0;
        break;
      case OrderStatus.shipped:
        activeIndex = 1;
        break;
      case OrderStatus.delivered:
        activeIndex = 3;
        break;
      case OrderStatus.cancelled:
        activeIndex = -1;
        break;
    }

    if (status == OrderStatus.cancelled) {
      return const SoftCard(
        color: Color(0xFFFFEDED),
        child: Row(
          children: [
            Icon(Icons.cancel_rounded, color: AppColors.danger),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'This order was cancelled. Refund (if applicable) has been credited to your original payment method.',
                style: TextStyle(color: AppColors.danger, fontSize: 12.5, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    return SoftCard(
      child: Column(
        children: List.generate(steps.length, (i) {
          final done = i <= activeIndex;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    height: 16,
                    width: 16,
                    decoration: BoxDecoration(
                      color: done ? AppColors.blueDark : AppColors.blueLight,
                      shape: BoxShape.circle,
                    ),
                    child: done
                        ? const Icon(Icons.check, size: 11, color: Colors.white)
                        : null,
                  ),
                  if (i != steps.length - 1)
                    Container(
                      height: 26,
                      width: 2,
                      color: done ? AppColors.blueDark : AppColors.blueLight,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Text(
                  steps[i],
                  style: TextStyle(
                    fontWeight: done ? FontWeight.bold : FontWeight.w500,
                    color: done ? AppColors.textDark : AppColors.textMuted,
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
