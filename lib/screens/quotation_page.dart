import 'package:flutter/material.dart';

import '../services/app_launcher.dart';
import '../services/cart_service.dart';
import '../services/currency_service.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/whatsapp_chat_button.dart';
import 'cart_page.dart';

/// Quotation & payment hub (replaces the old Chat tab). After adding
/// products, buyers land here with two choices: proceed to payment (full
/// checkout) or request a quotation over WhatsApp to talk to the team.
class QuotationPage extends StatefulWidget {
  const QuotationPage({super.key});

  @override
  State<QuotationPage> createState() => _QuotationPageState();
}

class _QuotationPageState extends State<QuotationPage> {
  void _changeQty(int index, int delta) {
    final item = CartService.items[index];
    CartService.setQuantity(index, item.quantity + delta);
    setState(() {});
  }

  void _removeAt(int index) {
    CartService.removeAt(index);
    setState(() {});
  }

  Future<void> _openCheckout() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CartPage()),
    );
    setState(() {}); // cart may have been cleared after a placed order
  }

  Future<void> _requestQuotation() async {
    final items = CartService.items;
    final lines = items
        .map((i) =>
            '- ${i.name} x ${i.quantity} @ USD ${i.unitPrice.toStringAsFixed(2)}')
        .join('\n');
    final message = items.isEmpty
        ? 'Hello MediGram! I would like to request a quotation for your pharmaceutical products.'
        : 'Hello MediGram! Please send me a quotation for:\n$lines\n'
            'Estimated total: USD ${CartService.total.toStringAsFixed(2)}';
    final opened = await openExternalUrl(WhatsAppChatButton.deepLink(message));
    if (opened || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chat with us on WhatsApp: +91 95884 23570'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = CartService.items;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Row(
              children: [
                if (Navigator.of(context).canPop())
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.arrow_back_rounded,
                        color: AppColors.textDark),
                  ),
                Expanded(
                  child: Text(
                    'Quotation & Payment',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Your selected products - choose to pay now or request a '
              'quotation and talk to our team.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const EmptyState(
                icon: Icons.request_quote_outlined,
                title: 'No products selected yet',
                message:
                    'Add products from the catalogue, then choose to pay or '
                    'get a quotation here.',
              )
            else ...[
              for (var i = 0; i < items.length; i++) _itemCard(i, items[i]),
              const SizedBox(height: 14),
              SoftCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Text(
                        'Estimated total',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textDark),
                      ),
                      const Spacer(),
                      Text(
                        CurrencyService.format(CartService.total),
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: AppColors.blueDark),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _openCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blueDark,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.payments_rounded),
                  label: const Text(
                    'Proceed to payment',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _requestQuotation,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1FA855),
                    side:
                        const BorderSide(color: Color(0xFF25D366), width: 1.6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text(
                    'Get quotation on WhatsApp',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Our trade desk replies within minutes on working hours.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _itemCard(int index, CartItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textDark),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    onPressed: () => _removeAt(index),
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 20, color: AppColors.danger),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '${CurrencyService.format(item.unitPrice)} / unit',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const Spacer(),
                  _qtyButton(
                    Icons.remove_rounded,
                    item.quantity > item.minOrderQty
                        ? () => _changeQty(index, item.quantity - 1)
                        : null,
                  ),
                  Container(
                    width: 52,
                    alignment: Alignment.center,
                    child: Text(
                      item.quantity.toString(),
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.textDark),
                    ),
                  ),
                  _qtyButton(Icons.add_rounded,
                      () => _changeQty(index, item.quantity + 1)),
                  const SizedBox(width: 10),
                  Text(
                    CurrencyService.format(item.lineTotal),
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: AppColors.blueDark),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 32,
        width: 32,
        decoration: BoxDecoration(
          color: onTap == null ? AppColors.bg : AppColors.blueLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null ? AppColors.textMuted : AppColors.blueDark,
        ),
      ),
    );
  }
}
