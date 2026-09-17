import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/inputs/app_search_field.dart';
import '../../../../shared/widgets/inputs/filter_chip_row.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/media/app_avatar.dart';

class TeamListScreen extends StatefulWidget {
  const TeamListScreen({super.key});

  @override
  State<TeamListScreen> createState() => _TeamListScreenState();
}

class _TeamListScreenState extends State<TeamListScreen> {
  String? _role;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Cabinet Staff Members',
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () {}),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.person_add_alt_outlined, size: 16),
              label: const Text('Add User'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: AppSearchField(
              hint: 'Search by staff name, email, or chair...',
              onChanged: (_) {},
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilterChipRow<String?>(
            selected: _role,
            onSelected: (v) => setState(() => _role = v),
            options: const [
              FilterChipOption(value: null, label: 'All Staff'),
              FilterChipOption(value: 'practitioner', label: 'Practitioners'),
              FilterChipOption(value: 'stock_manager', label: 'Stock Managers'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: const [
                _StaffCard(
                  initials: 'A',
                  name: 'Admin',
                  email: 'admin@steriqore.local',
                  role: 'OWNER / DIRECTION',
                  roleTone: BadgeTone.purple,
                  location: 'Direction & Supervision',
                ),
                _StaffCard(
                  initials: 'DJ',
                  name: 'Dr. Julien Dupont',
                  email: 'practitioner@steriqore.local',
                  role: 'PRACTITIONER',
                  roleTone: BadgeTone.green,
                  location: 'Fauteuil 1 - Chirurgie & Soins',
                ),
                _StaffCard(
                  initials: 'CM',
                  name: 'Claire Martin',
                  email: 'assistant@steriqore.local',
                  role: 'STOCK MANAGER',
                  roleTone: BadgeTone.blue,
                  location: 'Stérilisation Centrale & S...',
                ),
                _StaffCard(
                  initials: 'SB',
                  name: 'Sophie Bernard',
                  email: 'quality@steriqore.local',
                  role: 'QUALITY MANAGER',
                  roleTone: BadgeTone.purple,
                  location: 'Assurance Qualité & C...',
                ),
                _StaffCard(
                  initials: 'CR',
                  name: 'Camille Réception',
                  email: 'reception@steriqore.local',
                  role: 'RÉCEPTION',
                  roleTone: BadgeTone.purple,
                  location: 'Accueil & Règlements',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final String initials;
  final String name;
  final String email;
  final String role;
  final BadgeTone roleTone;
  final String location;

  const _StaffCard({
    required this.initials,
    required this.name,
    required this.email,
    required this.role,
    required this.roleTone,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          AppAvatar(initials: initials, size: 44),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTypography.bodyStrong),
                const SizedBox(height: 2),
                Text(email, style: AppTypography.caption),
                const SizedBox(height: 6),
                Row(
                  children: [
                    TypeBadge(label: role, tone: roleTone),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        '· $location',
                        style: AppTypography.caption,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            size: 20,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }
}
