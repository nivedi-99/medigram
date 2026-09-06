import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../theme/app_colors.dart';
import '../../widgets/shared_widgets.dart';

class PaymentPage extends StatefulWidget {
  final List<SavedPaymentMethod> methods;

  const PaymentPage({super.key, required this.methods});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  IconData _iconFor(PaymentType type) {
    switch (type) {
      case PaymentType.card:
        return Icons.credit_card_rounded;
      case PaymentType.upi:
        return Icons.qr_code_2_rounded;
      case PaymentType.wallet:
        return Icons.account_balance_wallet_rounded;
      case PaymentType.cod:
        return Icons.payments_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Payment Methods')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.blueLight.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 18, color: AppColors.blueDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Payments are simulated in this build. Export orders are invoiced per contract â€” online payment goes live soon.',
                    style: TextStyle(
                        fontSize: 12, height: 1.35, color: AppColors.textDark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Row(
              children: [
                Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 26),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MediGram Wallet', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('â‚¹350.00', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Saved Methods', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark)),
          const SizedBox(height: 12),
          ...widget.methods.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SoftCard(
                child: Row(
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: AppColors.blueLight,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(_iconFor(m.type), color: AppColors.blueDark, size: 21),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(m.label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textDark)),
                              if (m.isDefault) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.13),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Default',
                                    style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(m.detail, style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, color: AppColors.textMuted),
                      onSelected: (value) {
                        setState(() {
                          if (value == 'default') {
                            for (final method in widget.methods) {
                              method.isDefault = method == m;
                            }
                          } else if (value == 'remove') {
                            widget.methods.remove(m);
                          }
                        });
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'default', child: Text('Set as default')),
                        const PopupMenuItem(value: 'remove', child: Text('Remove')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _showAddMethodSheet(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Payment Method'),
          ),
          const SizedBox(height: 26),
          Text('Transaction History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark)),
          const SizedBox(height: 12),
          const SoftCard(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              children: [
                _TransactionRow(title: 'Order MG-10231', date: '25 Aug 2026', amount: '- â‚¹797.00'),
                Divider(height: 1),
                _TransactionRow(title: 'Order MG-10198', date: '18 Aug 2026', amount: '- â‚¹399.00'),
                Divider(height: 1),
                _TransactionRow(title: 'Wallet top-up', date: '10 Aug 2026', amount: '+ â‚¹500.00', positive: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMethodSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        final cardController = TextEditingController();
        final nameController = TextEditingController();
        return Padding(
          padding: EdgeInsets.fromLTRB(
            22, 22, 22, MediaQuery.of(context).viewInsets.bottom + 22,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add Card', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
              const SizedBox(height: 18),
              LabeledField(
                label: 'Cardholder name',
                controller: nameController,
                hint: 'Name on card',
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 14),
              LabeledField(
                label: 'Card number',
                controller: cardController,
                hint: 'â€¢â€¢â€¢â€¢ â€¢â€¢â€¢â€¢ â€¢â€¢â€¢â€¢ â€¢â€¢â€¢â€¢',
                icon: Icons.credit_card_rounded,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Card added successfully')),
                  );
                },
                child: const Text('Save Card'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final String title;
  final String date;
  final String amount;
  final bool positive;

  const _TransactionRow({
    required this.title,
    required this.date,
    required this.amount,
    this.positive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppColors.textDark)),
                const SizedBox(height: 3),
                Text(date, style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              color: positive ? AppColors.success : AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
