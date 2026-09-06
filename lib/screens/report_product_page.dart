import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

class ReportProductPage extends StatefulWidget {
  final MedicineOrder order;

  const ReportProductPage({super.key, required this.order});

  @override
  State<ReportProductPage> createState() => _ReportProductPageState();
}

class _ReportProductPageState extends State<ReportProductPage> {
  String? selectedItem;
  String issueType = 'Damaged packaging';
  final _detailsController = TextEditingController();
  bool _submitted = false;
  bool _submitting = false;

  final issueTypes = const [
    'Damaged packaging',
    'Wrong item received',
    'Missing item',
    'Suspected quality issue',
    'Late delivery',
    'Billing / payment issue',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.order.items.isNotEmpty) {
      selectedItem = widget.order.items.first.name;
    }
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (selectedItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select the product this report is about.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await DatabaseService.submitProductReport(
        orderId: widget.order.uuid,
        productName: selectedItem ?? '',
        issueType: issueType,
        details: _detailsController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _submitted = true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not submit the report. Please try again.'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(title: const Text('Report submitted')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: AppColors.success.withValues(alpha: 0.15),
                  child: const Icon(Icons.check_circle_rounded, size: 46, color: AppColors.success),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Thanks — we\'ve received your report',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
                const SizedBox(height: 10),
                Text(
                  'Our support team will review order ${widget.order.id} and get back to you within 24–48 hours.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted, height: 1.4),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to orders'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Report a Product Issue')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
        children: [
          Text(
            'Order ${widget.order.id}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark, fontSize: 15),
          ),
          const SizedBox(height: 18),
          const Text(
            'Which product is this about?',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppColors.textDark),
          ),
          const SizedBox(height: 10),
          RadioGroup<String>(
            groupValue: selectedItem,
            onChanged: (v) => setState(() => selectedItem = v),
            child: Column(
              children: [
                for (final item in widget.order.items)
                  RadioListTile<String>(
                    value: item.name,
                    activeColor: AppColors.blueDark,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      item.name,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'What went wrong?',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppColors.textDark),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: issueTypes.map((type) {
              final selected = issueType == type;
              return ChoiceChip(
                label: Text(type),
                selected: selected,
                onSelected: (_) => setState(() => issueType = type),
                selectedColor: AppColors.blueDark,
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppColors.textDark,
                  fontSize: 12.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: selected ? Colors.transparent : AppColors.blueLight),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          LabeledField(
            label: 'Additional details',
            controller: _detailsController,
            hint: 'Describe the issue in a few lines...',
            icon: Icons.notes_rounded,
            maxLines: 5,
          ),
          const SizedBox(height: 26),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Text('Submit Report'),
          ),
        ],
      ),
    );
  }
}
