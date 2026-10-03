import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/utils/contact_launcher.dart';
import '../cards/app_card.dart';

/// The grab handle every bottom sheet starts with.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.borderMedium,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    );
  }
}

/// Opens a sheet the same way everywhere: page colour, 24px top corners,
/// scroll-controlled so it can grow with its content and the keyboard.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.backgroundApp,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: builder,
  );
}

/// The content of a detail sheet: handle, then the children, scrollable and
/// padded the same way on every screen.
class DetailSheet extends StatelessWidget {
  final List<Widget> children;
  const DetailSheet({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            const SizedBox(height: AppSpacing.md),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// "icon  label ........ value": one fact in a detail card.
class DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  const DetailRow(this.icon, this.label, this.value, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: AppTypography.label)),
          Flexible(
            child: Text(
              value,
              style: AppTypography.bodyStrong.copyWith(color: color),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small pill of information ("Unité : boîte", "Stérilisable").
class InfoTag extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? color;
  const InfoTag(this.text, {super.key, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceWell,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: c),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              text,
              style: AppTypography.caption.copyWith(
                color: c,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// The round mark at the start of a card: initials (a person, a company) or an
/// icon (a thing).
class EntityMark extends StatelessWidget {
  final String? initials;
  final IconData? icon;
  final Color background;
  final Color foreground;
  final bool round;

  const EntityMark.initials(
    this.initials, {
    super.key,
    this.background = AppColors.brandPrimaryLight,
    this.foreground = AppColors.brandPrimaryDark,
  })  : icon = null,
        round = true;

  const EntityMark.icon(
    this.icon, {
    super.key,
    this.background = AppColors.surfaceWell,
    this.foreground = AppColors.navyHeader,
  })  : initials = null,
        round = false;

  /// "Dental Plus" -> "DP", "Marie" -> "M", "" -> "•".
  static String initialsOf(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '•';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: round ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: round ? null : BorderRadius.circular(AppRadius.control),
      ),
      child: initials != null
          ? Text(
              initials!,
              style: AppTypography.bodyStrong.copyWith(
                color: foreground,
                fontSize: 13,
              ),
            )
          : Icon(icon, size: 21, color: foreground),
    );
  }
}

/// A record in a list: mark, small uppercase line, title, optional subtitle,
/// a status or action on the right and a row of tags underneath.
class EntityCard extends StatelessWidget {
  final Widget mark;
  final String? eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> tags;
  final Widget? footer;
  final VoidCallback? onTap;

  const EntityCard({
    super.key,
    required this.mark,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
    this.tags = const [],
    this.footer,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              mark,
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (eyebrow != null && eyebrow!.isNotEmpty)
                      Text(
                        eyebrow!,
                        style: AppTypography.eyebrow,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      title,
                      style: AppTypography.cardTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: AppTypography.caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: tags,
            ),
          ],
          if (footer != null) ...[
            const SizedBox(height: AppSpacing.sm),
            footer!,
          ],
        ],
      ),
    );
  }
}

/// The record as it will look once saved, shown at the top of a creation form
/// and updated as the person types.
class PreviewCard extends StatelessWidget {
  final Widget mark;
  final String eyebrow;
  final String title;
  final bool titleIsPlaceholder;
  final List<Widget> tags;

  const PreviewCard({
    super.key,
    required this.mark,
    required this.eyebrow,
    required this.title,
    this.titleIsPlaceholder = false,
    this.tags = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          mark,
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: AppTypography.eyebrow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: AppTypography.cardTitle.copyWith(
                    color: titleIsPlaceholder ? AppColors.textTertiary : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: tags,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Appeler  E-mail  Itinéraire": the three ways to reach a supplier, a
/// laboratory or a site. A button only exists for a value that exists.
class ContactActions extends StatelessWidget {
  final String? phone;
  final String? email;
  final String? address;

  const ContactActions({super.key, this.phone, this.email, this.address});

  bool _has(String? v) => v != null && v.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      if (_has(phone))
        _ContactButton(
          key: const Key('contact-call'),
          icon: Icons.call_outlined,
          label: 'Appeler',
          onTap: () => ContactLauncher.call(context, phone!),
        ),
      if (_has(email))
        _ContactButton(
          key: const Key('contact-email'),
          icon: Icons.mail_outline,
          label: 'E-mail',
          onTap: () => ContactLauncher.email(context, email!),
        ),
      if (_has(address))
        _ContactButton(
          key: const Key('contact-map'),
          icon: Icons.directions_outlined,
          label: 'Itinéraire',
          onTap: () => ContactLauncher.map(context, address!),
        ),
    ];
    if (actions.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(child: actions[i]),
        ],
      ],
    );
  }
}

class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ContactButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceWell,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            children: [
              Icon(icon, size: 20, color: AppColors.navyHeader),
              const SizedBox(height: 2),
              Text(label, style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              )),
            ],
          ),
        ),
      ),
    );
  }
}
