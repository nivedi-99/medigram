import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/app_launcher.dart';
import '../services/currency_service.dart';
import '../services/payments_service.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

/// MediGram Chat — product Q&A plus instant WhatsApp quotations.
///
/// Clients add medicines to a quote list (MOQ-aware), the app renders a
/// regional-currency quotation (USD for US, EUR for Europe) and hands it to
/// WhatsApp via a wa.me deep link.
class ChatPage extends StatefulWidget {
  final List<ProductRecord> products;
  final PaymentsConfig? config;
  final String customerName;
  final String companyName;

  const ChatPage({
    super.key,
    required this.products,
    this.config,
    this.customerName = '',
    this.companyName = '',
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _QuoteItem {
  final ProductRecord product;
  int quantity;

  _QuoteItem(this.product, this.quantity);

  double get lineTotal => product.price * quantity;
}

class _ChatMessage {
  final String text;
  final bool fromUser;
  final bool isQuote;

  _ChatMessage(this.text, {this.fromUser = false, this.isQuote = false});
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      "Hi! I'm the MediGram trade assistant. Ask me about categories, MOQs, "
      'delivery or payments — or tap "Build quotation" to add medicines and '
      'send a price quote straight to our WhatsApp.',
    ),
  ];

  final List<_QuoteItem> _quoteItems = [];

  String get _whatsappNumber {
    final raw = widget.config?.whatsappNumber ?? '+91 90000 00000';
    return raw.replaceAll(RegExp(r'[^0-9]'), '');
  }

  // ---------------------------------------------------------------------
  // Assistant
  // ---------------------------------------------------------------------

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(text, fromUser: true));
      _messages.add(_ChatMessage(_replyFor(text)));
    });
    _controller.clear();
  }

  String _replyFor(String input) {
    final q = input.toLowerCase();
    if (q.contains('moq') || q.contains('minimum')) {
      return 'Every listing shows its minimum order quantity (MOQ) — usually '
          '50–1000 units. Add medicines via "Build quotation" and we will '
          'confirm stock and final pricing on WhatsApp.';
    }
    if (q.contains('deliver') || q.contains('ship') || q.contains('freight')) {
      return 'We ship worldwide from Mumbai by air and sea freight — DHL, '
          'FedEx, or consolidated sea cargo. Incoterms default to FOB Mumbai; '
          'CIF and DDP are available on request.';
    }
    if (q.contains('pay') || q.contains('remittance') || q.contains('settle')) {
      return 'We accept international wires (SWIFT), Western Union, Remitly, '
          'MoneyGram, Wise, Bitcoin, Ethereum and USDT (TRC-20). All channels '
          'settle to our Indian account — the Payment tab shows exact details '
          'and the INR equivalent at the daily rate.';
    }
    if (q.contains('kyc') || q.contains('verif') || q.contains('licence')) {
      return 'Every buyer is KYC-verified before a first order: business '
          'licence plus import permit where applicable. Verification usually '
          'completes within 24 hours.';
    }
    if (q.contains('category') ||
        q.contains('catalogue') ||
        q.contains('product')) {
      return 'Our catalogue covers ${_categoryCount()} categories — from Pain '
          'Killers and Antibiotics to Ayurvedic and Health Supplements. Browse '
          'the Products tab, or tell me a therapy area and I will point you '
          'to it.';
    }
    if (q.contains('hi') || q.contains('hello') || q.contains('hey')) {
      return 'Hello! Tell me what you are sourcing today, or tap "Build '
          'quotation" to add medicines with quantities and receive a price '
          'quote on WhatsApp.';
    }
    return 'Thanks for your message! Our trade desk replies within minutes on '
        'working hours. For dosage or prescription questions please consult a '
        'licensed pharmacist. Tap "Build quotation" to price your list now.';
  }

  int _categoryCount() => widget.products.map((p) => p.category).toSet().length;

  // ---------------------------------------------------------------------
  // Quotation
  // ---------------------------------------------------------------------

  double get _quoteTotal =>
      _quoteItems.fold(0, (sum, item) => sum + item.lineTotal);

  String _buildQuotationText() {
    final now = DateTime.now();
    final date = '${now.day.toString().padLeft(2, '0')} '
        '${_monthName(now.month)} ${now.year}';
    final buffer = StringBuffer();
    buffer.writeln('*MEDIGRAM — EXPORT QUOTATION*');
    buffer.writeln('Date: $date');
    buffer.writeln('Prices: ${CurrencyService.currencyCode} '
        '(INR settlement on request)');
    buffer.writeln('--------------------------------');
    var i = 1;
    for (final item in _quoteItems) {
      final maker =
          item.product.manufacturer.isEmpty ? 'MediGram' : item.product.manufacturer;
      buffer.writeln('$i. ${item.product.name} — $maker');
      buffer.writeln(
          '    Qty ${item.quantity} x ${CurrencyService.format(item.product.price)}'
          ' = ${CurrencyService.format(item.lineTotal)}');
      i++;
    }
    buffer.writeln('--------------------------------');
    buffer.writeln('TOTAL: ${CurrencyService.format(_quoteTotal)}');
    buffer.writeln(
        'INR equivalent approx: ${CurrencyService.settlementInr(_quoteTotal)}');
    buffer.writeln('Validity: 7 days | Incoterms: FOB Mumbai');
    if (widget.companyName.isNotEmpty || widget.customerName.isNotEmpty) {
      buffer.writeln(
          'For: ${widget.companyName.isNotEmpty ? widget.companyName : widget.customerName}');
    }
    buffer.writeln('Sent from the MediGram B2B app.');
    return buffer.toString();
  }

  static String _monthName(int month) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][month - 1];

  Future<void> _sendQuotationOnWhatsApp() async {
    if (_quoteItems.isEmpty) return;
    final quote = _buildQuotationText();
    final number = _whatsappNumber;
    final url = 'https://wa.me/$number?text=${Uri.encodeComponent(quote)}';
    setState(() {
      _messages.add(_ChatMessage(quote, fromUser: true, isQuote: true));
      _messages.add(_ChatMessage(
        'Your quotation is ready — WhatsApp is opening with it pre-filled. '
        'Just hit send there to reach our trade desk; they confirm stock, '
        'freight and the final INR settlement.',
      ));
    });
    _quoteItems.clear();
    final ok = await openExternalUrl(url);
    if (mounted && !ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Open WhatsApp manually and paste the quote.')),
      );
    }
  }

  Future<void> _openQuotationBuilder() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        builder: (_) => _QuotationBuilderSheet(
          products: widget.products,
          items: _quoteItems,
          onQuoteItemsChanged: () => setState(() {}),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
          child: Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.support_agent_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MediGram Chat',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      'Trade desk • Online • Prices in '
                          '${CurrencyService.currencyCode}',
                      style: TextStyle(fontSize: 11.5, color: AppColors.success),
                    ),
                  ],
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    tooltip: 'Build quotation',
                    onPressed: _openQuotationBuilder,
                    icon: Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.blueDark,
                    ),
                  ),
                  if (_quoteItems.isNotEmpty)
                    Positioned(
                      right: 0,
                      top: 2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.pink,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${_quoteItems.length}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildMessages()),
        _buildQuoteBar(),
        _buildInput(),
      ],
    );
  }

  Widget _buildMessages() {
    return ListView.builder(
      padding: const EdgeInsets.all(18),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return Align(
          alignment: msg.fromUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            decoration: BoxDecoration(
              gradient: msg.fromUser ? AppColors.heroGradient : null,
              color: msg.fromUser ? null : AppColors.card,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(msg.fromUser ? 18 : 4),
                bottomRight: Radius.circular(msg.fromUser ? 4 : 18),
              ),
              border:
                  msg.fromUser ? null : Border.all(color: AppColors.border),
            ),
            child: Text(
              msg.text,
              style: TextStyle(
                color: msg.fromUser ? Colors.white : AppColors.textDark,
                height: 1.45,
                fontSize: msg.isQuote ? 12.5 : 13.5,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuoteBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _quoteItems.isEmpty
                  ? 'Quote list is empty — add medicines for an instant price.'
                  : '${_quoteItems.length} item(s) — total '
                      '${CurrencyService.format(_quoteTotal)}',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _quoteItems.isEmpty ? null : _sendQuotationOnWhatsApp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blueDark,
              foregroundColor: AppColors.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Send quote'),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(
                hintText: 'Ask about categories, MOQ, delivery...',
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _send,
              icon:
                  const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
/// Search + add medicines with MOQ-aware quantity steppers, live totals and
/// the WhatsApp hand-off.
class _QuotationBuilderSheet extends StatefulWidget {
  final List<ProductRecord> products;
  final List<_QuoteItem> items;
  final VoidCallback onQuoteItemsChanged;

  const _QuotationBuilderSheet({
    required this.products,
    required this.items,
    required this.onQuoteItemsChanged,
  });

  @override
  State<_QuotationBuilderSheet> createState() => _QuotationBuilderSheetState();
}

class _QuotationBuilderSheetState extends State<_QuotationBuilderSheet> {
  String _query = '';

  List<ProductRecord> get _results {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.products.take(30).toList();
    return widget.products
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q))
        .take(30)
        .toList();
  }

  _QuoteItem? _itemFor(ProductRecord p) {
    for (final item in widget.items) {
      if (item.product.id == p.id) return item;
    }
    return null;
  }

  void _add(ProductRecord p) {
    setState(() {
      final existing = _itemFor(p);
      if (existing == null) {
        widget.items.add(_QuoteItem(p, p.minOrderQty));
      } else {
        existing.quantity += p.minOrderQty;
      }
    });
    widget.onQuoteItemsChanged();
  }

  void _changeQty(_QuoteItem item, int delta) {
    setState(() {
      item.quantity =
          (item.quantity + delta).clamp(item.product.minOrderQty, 100000);
    });
    widget.onQuoteItemsChanged();
  }

  void _remove(_QuoteItem item) {
    setState(() => widget.items.remove(item));
    widget.onQuoteItemsChanged();
  }

  double get _total => widget.items.fold(0, (sum, item) => sum + item.lineTotal);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.88,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
            child: Row(
              children: [
                Icon(Icons.receipt_long_rounded, color: AppColors.blueDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Build quotation',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                Text(
                  'Prices in ${CurrencyService.currencyCode}',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search medicines...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }
  Widget _buildList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      children: [
        if (widget.items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Search below and add medicines — quantities start at each '
              "product's minimum order quantity.",
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
          ),
        for (final item in widget.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildItemCard(item),
          ),
        if (widget.items.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textDark),
                ),
              ),
              Text(
                CurrencyService.format(_total),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: AppColors.blueDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'INR settlement approx: ${CurrencyService.settlementInr(_total)}',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              context
                  .findAncestorStateOfType<_ChatPageState>()
                  ?._sendQuotationOnWhatsApp();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.blueDark,
              foregroundColor: AppColors.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            icon: const Icon(Icons.send_rounded),
            label: const Text('Generate & send on WhatsApp'),
          ),
          const SizedBox(height: 14),
        ],
        Text(
          'Add more medicines',
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              color: AppColors.textDark),
        ),
        const SizedBox(height: 8),
        ..._results.map(_buildPickerRow),
      ],
    );
  }
  Widget _buildItemCard(_QuoteItem item) {
    return SoftCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                Text(
                  CurrencyService.format(item.lineTotal),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: AppColors.blueDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _QtyButton(
                  icon: Icons.remove_rounded,
                  onTap: () => _changeQty(item, -item.product.minOrderQty),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'Qty ${item.quantity}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                _QtyButton(
                  icon: Icons.add_rounded,
                  onTap: () => _changeQty(item, item.product.minOrderQty),
                ),
                const Spacer(),
                Text(
                  'MOQ ${item.product.minOrderQty}',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: () => _remove(item),
                  child: Icon(Icons.delete_outline_rounded,
                      size: 20, color: AppColors.danger),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildPickerRow(ProductRecord p) {
    final item = _itemFor(p);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SoftCard(
        child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        dense: true,
        title: Text(
          p.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.textDark),
        ),
        subtitle: Text(
          '${p.category} • MOQ ${p.minOrderQty} • ${CurrencyService.format(p.price)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
        ),
        trailing: item == null
            ? IconButton(
                onPressed: () => _add(p),
                icon: Icon(Icons.add_circle_rounded, color: AppColors.pink),
              )
            : Text(
                '${item.quantity} added',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 30,
        width: 30,
        decoration: BoxDecoration(
          color: AppColors.blueLight.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: AppColors.blueDark),
      ),
    );
  }
}
