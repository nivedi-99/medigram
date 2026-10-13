import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../services/currency_service.dart';
import '../../services/image_picker_service.dart';
import '../../services/payments_service.dart';
import '../../services/product_image.dart';
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

  // Payment-screenshot proof (uploaded after remitting the INR invoice).
  PickedImage? _proof;
  bool _uploadingProof = false;
  String? _proofUrl;
  String? _proofError;

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
          const SizedBox(height: 24),
          _buildChannelsSection(),
          const SizedBox(height: 24),
          _buildProofSection(),
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
              'All payments must be made in INR (₹). Choose any global channel '
              'below and remit the invoice total in Indian Rupees — it settles '
              'directly to our Indian account. Then upload your payment '
              'screenshot below so we can confirm your order.',
              style: TextStyle(
                  fontSize: 12, height: 1.35, color: AppColors.textDark),
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
  // -------------------------------------------------------------------
  // Payment-screenshot proof — uploaded after remitting the INR invoice.
  // -------------------------------------------------------------------

  Future<void> _pickProof() async {
    try {
      final picked = await pickProductImage();
      if (!mounted) return;
      if (picked == null) return;
      setState(() {
        _proof = picked;
        _proofUrl = null;
        _proofError = null;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() => _proofError = 'Could not open the file picker: $err');
    }
  }

  Future<void> _uploadProof() async {
    final image = _proof;
    if (image == null || _uploadingProof) return;
    setState(() {
      _uploadingProof = true;
      _proofError = null;
    });
    try {
      final url = await PaymentsService.uploadPaymentProof(image);
      if (!mounted) return;
      setState(() {
        _uploadingProof = false;
        _proofUrl = url;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Payment screenshot received — our trade desk will verify it shortly.'),
        ),
      );
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _uploadingProof = false;
        _proofError = 'Upload failed: $err';
      });
    }
  }

  Widget _buildProofSection() {
    return SoftCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  child: const Icon(Icons.receipt_long_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Screenshot',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: AppColors.textDark),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'After remitting in INR, upload the receipt so we can '
                        'confirm your payment.',
                        style: TextStyle(
                            fontSize: 11.5, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_proofUrl != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 18, color: AppColors.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Screenshot received. Our trade desk will verify it '
                        'and confirm your order shortly.',
                        style:
                            TextStyle(fontSize: 12, color: AppColors.textDark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: _proofUrl!)),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy proof link'),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _pickProof,
                  child: const Text('Replace screenshot'),
                ),
              ),
            ] else ...[
              if (_proof == null)
                GestureDetector(
                  onTap: _pickProof,
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border, width: 1.2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload_file_rounded,
                            size: 30, color: AppColors.textMuted),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to choose your payment screenshot',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _proof!.bytes,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_proof!.filename} · ${_proof!.sizeLabel}',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickProof,
                        icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                        label: const Text('Change'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _uploadingProof ? null : _uploadProof,
                        icon: _uploadingProof
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.cloud_upload_rounded, size: 18),
                        label: Text(_uploadingProof ? 'Uploading…' : 'Send'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
            if (_proofError != null) ...[
              const SizedBox(height: 10),
              Text(_proofError!,
                  style: TextStyle(fontSize: 12, color: AppColors.danger)),
            ],
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