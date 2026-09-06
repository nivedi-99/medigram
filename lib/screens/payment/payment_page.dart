import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/currency_service.dart';
import '../../services/payments_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/shared_widgets.dart';

/// Payment hub: saved demo methods plus the real global settlement channels
/// (wire, Western Union, Remitly, MoneyGram, Wise, BTC, ETH, USDT) served
/// from /api/v1/payments, each remitting to our Indian account.
class PaymentPage extends StatefulWidget {
  final List<SavedPaymentMethod> methods;

  const PaymentPage({super.key, required this.methods});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  PaymentsConfig? _config;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _loading = true);
    try {
      final config = await PaymentsService.fetchConfig();
      if (!mounted) return;
      CurrencyService.setRates(config.fx);
      setState(() {
        _config = config;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load settlement channels. Check your connection.';
        _loading = false;
      });
    }
  }

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

  IconData _channelIcon(String key) {
    if (key.contains('bitcoin') ||
        key.contains('ethereum') ||
        key.contains('usdt')) {
      return Icons.currency_bitcoin_rounded;
    }
    if (key.contains('wire') || key.contains('wise')) {
      return Icons.account_balance_rounded;
    }
    if (key.contains('western') ||
        key.contains('moneygram') ||
        key.contains('remitly')) {
      return Icons.attach_money_rounded;
    }
    return Icons.currency_exchange_rounded;
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Payment Methods')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
        children: [
          _buildNotice(),
          const SizedBox(height: 16),
          _buildWallet(),
          const SizedBox(height: 24),
          _buildChannelsSection(),
          const SizedBox(height: 24),
          Text(
            'Saved Methods',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.textDark),
          ),
          const SizedBox(height: 12),
          ...widget.methods.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SoftCard(
                child: Row(
                  children: [
                    Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: AppColors.blueLight.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_iconFor(m.type), color: AppColors.blueDark),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.label,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                  color: AppColors.textDark)),
                          const SizedBox(height: 3),
                          Text(m.detail,
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    if (m.isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.blueLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('Default',
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.blueDark)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _showAddMethodSheet(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Card'),
          ),
        ],
      ),
    );
  }
  Widget _buildNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blueLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: AppColors.blueDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Choose any global channel below and remit the invoice total — '
              'it settles to our Indian account in INR. Share the transaction '
              'reference with your order for confirmation.',
              style: TextStyle(
                  fontSize: 12, height: 1.35, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWallet() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        children: [
          Icon(Icons.account_balance_wallet_rounded,
              color: Colors.white, size: 26),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MediGram Wallet',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text('₹350.00',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildChannelsSection() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Column(
        children: [
          Text(_error!,
              style: TextStyle(fontSize: 12.5, color: AppColors.danger)),
          const SizedBox(height: 8),
          TextButton(onPressed: _loadConfig, child: const Text('Retry')),
        ],
      );
    }
    final methods = _config?.methods ?? const [];
    return Column(children: methods.map(_buildChannelCard).toList());
  }

  Widget _buildChannelCard(PaymentChannel channel) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        onTap: () => _showChannelSheet(channel),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(13),
              ),
              child:
                  Icon(_channelIcon(channel.key), color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.label,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: AppColors.textDark),
                  ),
                  if (channel.tagline.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      channel.tagline,
                      style: TextStyle(
                          fontSize: 11.5, color: AppColors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
  void _showChannelSheet(PaymentChannel channel) {
    const usdExample = 100.0;
    final inr = CurrencyService.settlementInr(usdExample);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        gradient: AppColors.heroGradient,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(_channelIcon(channel.key),
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        channel.label,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.blueLight.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Example: ${CurrencyService.format(usdExample)} invoice '
                    'settles to about $inr (admin-managed FX rate).',
                    style:
                        TextStyle(fontSize: 12.5, color: AppColors.textDark),
                  ),
                ),
                const SizedBox(height: 16),
                ...channel.details.entries.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 130,
                          child: Text(
                              e.key,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted)),
                        ),
                        Expanded(
                          child: Text(
                              e.value,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  channel.instructions,
                  style: TextStyle(
                      fontSize: 12.5, height: 1.5, color: AppColors.textMuted),
                ),
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Got it — I will use this channel'),
                ),
              ],
            ),
          ),
        );
      },
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
                hint: '•••• •••• •••• ••••',
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