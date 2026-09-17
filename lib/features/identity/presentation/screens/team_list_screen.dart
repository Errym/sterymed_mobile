import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/inputs/app_search_field.dart';
import '../../../../shared/widgets/inputs/filter_chip_row.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/media/app_avatar.dart';
import '../../data/models/team_member_data.dart';
import '../../data/repositories/team_repository.dart';
import '../bloc/team_list_bloc.dart';
import '../widgets/team_invite_sheet.dart';

class TeamListScreen extends StatelessWidget {
  const TeamListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TeamListBloc(getIt<TeamRepository>())
        ..add(const LoadTeam()),
      child: const _TeamListView(),
    );
  }
}

class _TeamListView extends StatelessWidget {
  const _TeamListView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Équipe & Droits',
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_outlined),
            tooltip: 'Inviter un membre',
            onPressed: () async {
              final ok = await TeamInviteSheet.show(context);
              if (ok == true && context.mounted) {
                context.read<TeamListBloc>().add(const LoadTeam());
              }
            },
          ),
        ],
      ),
      body: BlocBuilder<TeamListBloc, TeamListState>(
        builder: (context, state) {
          if (state.status == TeamStatus.loading && state.members.isEmpty) {
            return const LoadingView();
          }
          if (state.status == TeamStatus.failure) {
            return ErrorView(message: state.error ?? 'Erreur');
          }
          if (state.members.isEmpty) {
            return EmptyView(
              title: 'Aucun membre',
              message: 'Invitez votre première collaboratrice.',
              icon: Icons.group_outlined,
              action: FilledButton.icon(
                onPressed: () async {
                  final ok = await TeamInviteSheet.show(context);
                  if (ok == true && context.mounted) {
                    context.read<TeamListBloc>().add(const LoadTeam());
                  }
                },
                icon: const Icon(Icons.person_add_alt_outlined, size: 18),
                label: const Text('Inviter un membre'),
              ),
            );
          }
          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: AppSearchField(
                  hint: 'Rechercher par nom, e-mail...',
                  onChanged: (_) {},
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilterChipRow<String?>(
                selected: state.roleFilter,
                onSelected: (v) =>
                    context.read<TeamListBloc>().add(FilterTeam(v)),
                options: const [
                  FilterChipOption(value: null, label: 'Tous'),
                  FilterChipOption(value: 'owner', label: 'Direction'),
                  FilterChipOption(
                      value: 'practitioner', label: 'Praticiens'),
                  FilterChipOption(
                      value: 'stock_manager', label: 'Stock'),
                  FilterChipOption(value: 'reception', label: 'Accueil'),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: state.filtered.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) =>
                      _StaffCard(member: state.filtered[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final TeamMemberData member;
  const _StaffCard({required this.member});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          AppAvatar(initials: member.initials, size: 44),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name, style: AppTypography.bodyStrong),
                const SizedBox(height: 2),
                Text(member.email, style: AppTypography.caption),
                const SizedBox(height: 6),
                TypeBadge(
                  label: member.role.toUpperCase(),
                  tone: _toneFor(member.role),
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

  BadgeTone _toneFor(String role) {
    switch (role) {
      case 'owner':
      case 'admin':
        return BadgeTone.purple;
      case 'practitioner':
        return BadgeTone.green;
      case 'stock_manager':
        return BadgeTone.blue;
      case 'reception':
        return BadgeTone.orange;
      default:
        return BadgeTone.gray;
    }
  }
}
