import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/layout/metadata_section.dart';
import '../../../../shared/widgets/feedback/metadata_row.dart';
import '../../../../shared/widgets/media/app_avatar.dart';

class TeamDetailScreen extends StatefulWidget {
  final String memberId;
  const TeamDetailScreen({super.key, required this.memberId});

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  bool _active = true;
  final _nameCtrl = TextEditingController(text: 'Dr. Julien Dupont');
  final _emailCtrl =
      TextEditingController(text: 'practitioner@steriqore.local');
  final _phoneCtrl = TextEditingController(text: '+33 6 12 34 56 78');
  final _stationCtrl =
      TextEditingController(text: 'Fauteuil 1 - Chirurgie & Soins');
  String _role = 'practitioner';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _stationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: const AppAppBar(title: 'Staff Profile & Rights'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Identity card
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                const AppAvatar(initials: 'DJ', size: 56),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dr. Julien Dupont',
                          style:
                              AppTypography.bodyStrong.copyWith(fontSize: 16)),
                      const SizedBox(height: 2),
                      const Text('practitioner@steriqore.local',
                          style: AppTypography.caption),
                      const SizedBox(height: 6),
                      const Row(
                        children: [
                          TypeBadge(
                            label: 'PRACTITIONER',
                            tone: BadgeTone.green,
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Text('ID #USR-2', style: AppTypography.caption),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Active toggle
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.successLight,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_outlined,
                    color: AppColors.success, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _active ? 'Account Active' : 'Account Disabled',
                        style: AppTypography.bodyStrong.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                      const Text(
                        'User is authorized to sign in and operate',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
             Switch(
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                  activeThumbColor: AppColors.brandPrimary,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          const _SectionLabel('ASSIGNED ROLE'),
          AppDropdown<String>(
            value: _role,
            options: const [
              AppDropdownOption(
                value: 'practitioner',
                label: 'Practitioner / Chirurgien-Dentiste',
              ),
              AppDropdownOption(
                value: 'stock_manager',
                label: 'Stock Manager / Responsable Stock',
              ),
              AppDropdownOption(
                value: 'quality_manager',
                label: 'Quality Manager / Responsable Qualité',
              ),
              AppDropdownOption(
                value: 'reception',
                label: 'Réception / Accueil',
              ),
            ],
            onChanged: (v) => setState(() => _role = v ?? _role),
          ),
          const SizedBox(height: AppSpacing.lg),

          const _SectionLabel('ACCOUNT PROFILE'),
          AppTextField(
            label: 'Full Name *',
            controller: _nameCtrl,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Login Email *',
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Phone Number',
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Assigned Station or Chair',
            controller: _stationCtrl,
          ),
          const SizedBox(height: AppSpacing.lg),

          const MetadataSection(
            title: 'AUDIT & METADATA',
            children: [
              MetadataRow(label: 'Account Created', value: '17/07/2026'),
              MetadataRow(label: 'Last Session', value: '15/09/2026 21:37'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          PrimaryButton(
            label: 'Save Changes',
            onPressed: () {},
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text,
        style: AppTypography.label.copyWith(
          letterSpacing: 0.6,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
