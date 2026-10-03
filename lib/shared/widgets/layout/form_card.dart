import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../cards/app_card.dart';

/// A white card that groups one idea of a form or detail screen: an optional
/// small uppercase title (with an optional trailing hint such as "Requis"),
/// then its content with even spacing. Screens are stacks of these, so they
/// all share the same rhythm.
class FormCard extends StatelessWidget {
  final String? title;
  final Widget? trailing;
  final List<Widget> children;
  final double gap;
  final EdgeInsets? padding;

  const FormCard({
    super.key,
    this.title,
    this.trailing,
    required this.children,
    this.gap = AppSpacing.sm,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final body = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) body.add(SizedBox(height: gap));
      body.add(children[i]);
    }
    return AppCard(
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(title!.toUpperCase(), style: AppTypography.eyebrow),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          ...body,
        ],
      ),
    );
  }
}

/// A tinted strip inside a card: an icon, a label, and a value on the right
/// ("Stock disponible · 45 boîtes", "Nouveau stock restant · 40").
class StatStrip extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Widget value;
  final Color? tint;

  const StatStrip({
    super.key,
    this.icon,
    required this.label,
    required this.value,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: tint ?? AppColors.surfaceWell,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.brandPrimary),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(child: Text(label, style: AppTypography.body)),
          const SizedBox(width: AppSpacing.sm),
          value,
        ],
      ),
    );
  }
}

/// A quiet reassurance / rule note at the bottom of a form ("This is recorded
/// in the register under your operator id").
class NoteStrip extends StatelessWidget {
  final String text;
  final IconData icon;

  const NoteStrip({
    super.key,
    required this.text,
    this.icon = Icons.verified_user_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceWell,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.brandPrimary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTypography.caption)),
        ],
      ),
    );
  }
}

/// The footer every form ends with: the main action at full width, then a
/// plain "Annuler" link underneath that leaves the screen.
class FormFooter extends StatelessWidget {
  final Widget primary;
  final VoidCallback? onCancel;
  final String cancelLabel;

  const FormFooter({
    super.key,
    required this.primary,
    this.onCancel,
    this.cancelLabel = 'Annuler',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        primary,
        if (onCancel != null) ...[
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(cancelLabel),
          ),
        ],
      ],
    );
  }
}

/// A footer fixed to the bottom of a form screen, outside the scrolling
/// content, so the main action is always reachable one-handed however long
/// the form is.
class PinnedFooter extends StatelessWidget {
  final Widget child;

  const PinnedFooter({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundCard,
        boxShadow: AppShadows.card,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// "+5  +10  +15  +20": adds to the quantity box in one tap, never above [max].
class QuickAmountChips extends StatelessWidget {
  final TextEditingController controller;
  final List<int> amounts;
  final int? max;

  const QuickAmountChips({
    super.key,
    required this.controller,
    this.amounts = const [5, 10, 15, 20],
    this.max,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final n in amounts)
          ActionChip(
            key: ValueKey('quick_add_$n'),
            label: Text('+$n'),
            labelStyle: AppTypography.bodyStrong.copyWith(fontSize: 13),
            backgroundColor: AppColors.surfaceWell,
            side: BorderSide.none,
            onPressed: () {
              final current = int.tryParse(controller.text.trim()) ?? 0;
              var next = current + n;
              final cap = max;
              if (cap != null && cap > 0 && next > cap) next = cap;
              controller.text = '$next';
              controller.selection =
                  TextSelection.collapsed(offset: controller.text.length);
            },
          ),
      ],
    );
  }
}

/// Ready-made reasons that fill the reason box in one tap. The person can
/// still edit the text afterwards.
class ReasonPresetChips extends StatelessWidget {
  final TextEditingController controller;
  final List<String> presets;

  const ReasonPresetChips({
    super.key,
    required this.controller,
    required this.presets,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final p in presets)
            ChoiceChip(
              label: Text(p),
              labelStyle: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: value.text.trim() == p
                    ? AppColors.textOnBrand
                    : AppColors.textPrimary,
              ),
              selected: value.text.trim() == p,
              selectedColor: AppColors.navyHeader,
              backgroundColor: AppColors.surfaceWell,
              showCheckmark: false,
              side: BorderSide.none,
              onSelected: (_) {
                controller.text = p;
                controller.selection =
                    TextSelection.collapsed(offset: p.length);
              },
            ),
        ],
      ),
    );
  }
}
