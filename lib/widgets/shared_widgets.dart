import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';

/// Rounded white card with a soft shadow, used everywhere for consistency.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? AppColors.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Section heading used across dashboard/profile/orders pages.
class SectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionTitle({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.blueDark,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small stat tile, e.g. for dashboard quick stats.
class StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Gradient? gradient;

  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: BoxDecoration(
        gradient: gradient ?? AppColors.blueGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable list row with a leading icon bubble, used in Profile/Settings.
class MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final Color? iconBg;
  final Widget? trailing;
  final VoidCallback? onTap;

  const MenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    this.iconBg,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      leading: Container(
        height: 42,
        width: 42,
        decoration: BoxDecoration(
          color: iconBg ?? AppColors.blueLight,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: iconColor ?? AppColors.blueDark, size: 21),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14.5,
          color: AppColors.textDark,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            )
          : null,
      trailing: trailing ??
          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
    );
  }
}

/// Status chip used for order status, e.g. Delivered / Processing.
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const StatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Standard rounded text field with label, used across forms.
class LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType keyboardType;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final int maxLines;

  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.suffix,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20, color: AppColors.blueDark),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

/// Gradient page header used on auth screens and a few detail pages.
class GradientHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const GradientHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.local_pharmacy_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 60, 28, 36),
      decoration: BoxDecoration(
        gradient: AppColors.authGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty-state placeholder, reused for empty orders/notifications lists.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: AppColors.blueLight,
            child: Icon(icon, size: 36, color: AppColors.blueDark),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Order progress timeline shared by the Orders sheet and the Delivery page.
class TrackingTimeline extends StatelessWidget {
  final OrderStatus status;

  const TrackingTimeline({super.key, required this.status});

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
      return SoftCard(
        color: AppColors.isDark
            ? AppColors.danger.withValues(alpha: 0.16)
            : const Color(0xFFFFEDED),
        child: Row(
          children: [
            Icon(Icons.cancel_rounded, color: AppColors.danger),
            const SizedBox(width: 10),
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
