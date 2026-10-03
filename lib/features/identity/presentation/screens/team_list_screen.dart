import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/session_store.dart';
import '../../../../core/utils/role_labels.dart';
import '../../../../core/utils/formatters/date_formatter.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../shared/widgets/badges/type_badge.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/inputs/app_search_field.dart';
import '../../../../shared/widgets/inputs/filter_chip_row.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/lists/list_tile_skeleton.dart';
import '../../../../shared/widgets/media/app_avatar.dart';
import '../../data/models/open_invitation.dart';
import '../../data/models/team_member_data.dart';
import '../../data/models/tenant_role.dart';
import '../../data/repositories/team_repository.dart';
import '../bloc/team_list_bloc.dart';
import '../widgets/team_invite_sheet.dart';

class TeamListScreen extends StatelessWidget {
  const TeamListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TeamListBloc(
        getIt<TeamRepository>(),
        loadInvitations: getIt<SessionStore>().hasPermission(
          'invitations.create',
        ),
      )..add(const LoadTeam()),
      child: const _TeamListView(),
    );
  }
}

class _TeamListView extends StatelessWidget {
  const _TeamListView();

  Future<void> _invite(BuildContext context) async {
    final ok = await TeamInviteSheet.show(context);
    if (ok == true && context.mounted) {
      context.read<TeamListBloc>().add(const LoadTeam());
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = getIt<SessionStore>();
    final canInvite = session.hasPermission('invitations.create');
    final canDisable = session.hasPermission('memberships.disable');
    final currentUserId = session.userId;

    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Équipe & Droits',
        actions: [
          if (canInvite)
            IconButton(
              icon: const Icon(Icons.person_add_alt_outlined),
              tooltip: 'Inviter un membre',
              onPressed: () => _invite(context),
            ),
        ],
      ),
      body: BlocConsumer<TeamListBloc, TeamListState>(
        listenWhen: (a, b) =>
            (b.actionMessage != null && a.actionMessage != b.actionMessage) ||
            (b.actionError != null && a.actionError != b.actionError),
        listener: (context, state) {
          final isError = state.actionError != null;
          AppSnackbar.show(
            context,
            (isError ? state.actionError : state.actionMessage)!,
            kind: isError ? SnackKind.error : SnackKind.success,
          );
          context.read<TeamListBloc>().add(const ClearTeamNotice());
        },
        builder: (context, state) {
          if (state.status == TeamStatus.loading && state.members.isEmpty) {
            return const ListSkeleton();
          }
          if (state.status == TeamStatus.failure) {
            return ErrorView(
              message: state.error ?? 'Erreur',
              onRetry: () => context.read<TeamListBloc>().add(const LoadTeam()),
            );
          }
          if (state.members.isEmpty && state.invitations.isEmpty) {
            return EmptyView(
              title: 'Aucun membre',
              message: 'Invitez votre première collaboratrice.',
              icon: Icons.group_outlined,
              action: FilledButton.icon(
                onPressed: () => _invite(context),
                icon: const Icon(Icons.person_add_alt_outlined, size: 18),
                label: const Text('Inviter un membre'),
              ),
            );
          }
          final bloc = context.read<TeamListBloc>();
          final children = <Widget>[
            if (canInvite && state.invitationsError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'Invitations indisponibles : ${state.invitationsError}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ),
            if (canInvite && state.invitations.isNotEmpty) ...[
              Text(
                'Invitations en attente (${state.invitations.length})',
                style: AppTypography.sectionTitle,
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final invitation in state.invitations) ...[
                _InvitationCard(
                  invitation: invitation,
                  onResend: () => bloc.add(ResendInvitation(invitation.id)),
                  onRevoke: () async {
                    final ok = await ConfirmationDialog.show(
                      context,
                      title: 'Annuler cette invitation ?',
                      message:
                          '${invitation.email} ne pourra plus rejoindre le '
                          'cabinet avec ce lien.',
                      confirmLabel: 'Annuler l\'invitation',
                      cancelLabel: 'Garder',
                      isDestructive: true,
                    );
                    if (ok && context.mounted) {
                      bloc.add(RevokeInvitation(invitation.id));
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.sm),
              const Text('Membres', style: AppTypography.sectionTitle),
              const SizedBox(height: AppSpacing.sm),
            ],
            for (final m in state.filtered) ...[
              _StaffCard(
                member: m,
                onDisable:
                    !canDisable ||
                        !m.active ||
                        m.userId == currentUserId ||
                        (m.role == 'owner' && session.role != 'owner')
                    ? null
                    : () async {
                        final ok = await ConfirmationDialog.show(
                          context,
                          title: 'Désactiver ce membre ?',
                          message:
                              '${m.name} perdra immédiatement l\'accès au '
                              'cabinet.',
                          confirmLabel: 'Désactiver',
                          isDestructive: true,
                        );
                        if (!ok || !context.mounted) return;
                        try {
                          await getIt<TeamRepository>().disable(m.id);
                          if (!context.mounted) return;
                          bloc.add(const LoadTeam());
                        } catch (e) {
                          if (!context.mounted) return;
                          AppSnackbar.show(
                            context,
                            ErrorMessage.from(e),
                            kind: SnackKind.error,
                          );
                        }
                      },
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: AppSearchField(
                  hint: 'Rechercher par nom, e-mail...',
                  onChanged: (q) => bloc.add(SearchTeam(q)),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilterChipRow<String?>(
                selected: state.roleFilter,
                onSelected: (v) => bloc.add(FilterTeam(v)),
                options: [
                  const FilterChipOption(value: null, label: 'Tous'),
                  for (final (value, label) in kTenantRoles)
                    FilterChipOption(value: value, label: label),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => bloc.add(const LoadTeam()),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xs,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    children: children,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A colleague who has been invited but has not joined yet. Shows whether the
/// link is still usable, and offers the two things an owner can do about it.
class _InvitationCard extends StatelessWidget {
  final OpenInvitation invitation;
  final VoidCallback onResend;
  final VoidCallback onRevoke;

  const _InvitationCard({
    required this.invitation,
    required this.onResend,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    final expired = invitation.expired;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: expired
              ? AppColors.danger.withValues(alpha: 0.4)
              : AppColors.hairline,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('INVITATION', style: AppTypography.eyebrow),
          const SizedBox(height: 2),
          Text(invitation.email, style: AppTypography.cardTitle),
          const SizedBox(height: 6),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              TypeBadge(
                label: tenantRoleLabel(invitation.role),
                tone: tenantRoleTone(invitation.role),
              ),
              TypeBadge(
                label: expired ? 'Expirée' : 'En attente',
                tone: expired ? BadgeTone.red : BadgeTone.orange,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: onResend,
                icon: const Icon(Icons.send_outlined, size: 16),
                label: Text(expired ? 'Renvoyer (nouveau lien)' : 'Renvoyer'),
              ),
              TextButton(
                onPressed: onRevoke,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Annuler'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  final TeamMemberData member;
  final VoidCallback? onDisable;
  const _StaffCard({required this.member, this.onDisable});

  @override
  Widget build(BuildContext context) {
    final joined = member.joinedAt;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: member.active
              ? AppColors.hairline
              : AppColors.danger.withValues(alpha: 0.4),
        ),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Opacity(
            opacity: member.active ? 1 : 0.5,
            child: AppAvatar(initials: member.initials, size: 44),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name, style: AppTypography.cardTitle),
                const SizedBox(height: 2),
                Text(member.email, style: AppTypography.caption),
                const SizedBox(height: 6),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    TypeBadge(
                      label: tenantRoleLabel(member.role),
                      tone: tenantRoleTone(member.role),
                    ),
                    if (!member.active)
                      const TypeBadge(label: 'Désactivé', tone: BadgeTone.red),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  RoleLabels.describe(member.role),
                  style: AppTypography.caption,
                ),
                if (joined != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Membre depuis le ${AppDateFormatter.date(joined.toLocal())}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (onDisable != null)
            IconButton(
              icon: const Icon(
                Icons.person_off_outlined,
                size: 20,
                color: AppColors.danger,
              ),
              tooltip: 'Désactiver',
              onPressed: onDisable,
            ),
        ],
      ),
    );
  }
}
