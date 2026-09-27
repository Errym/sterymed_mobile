import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/buttons/secondary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../data/models/tenant_role.dart';
import '../../data/repositories/team_repository.dart';
import '../bloc/team_list_bloc.dart';

class TeamInviteSheet extends StatefulWidget {
  const TeamInviteSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      // Cancelling must go through the confirm-if-dirty check below, not a
      // silent tap-outside/drag-down dismiss.
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.backgroundApp,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => BlocProvider.value(
        value: context.read<TeamListBloc>(),
        child: const TeamInviteSheet(),
      ),
    );
  }

  @override
  State<TeamInviteSheet> createState() => _TeamInviteSheetState();
}

class _TeamInviteSheetState extends State<TeamInviteSheet> {
  static const _defaultRole = 'practitioner';

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  String _role = _defaultRole;
  bool _submitting = false;

  bool get _isDirty =>
      _emailCtrl.text.trim().isNotEmpty || _role != _defaultRole;

  @override
  void initState() {
    super.initState();
    // Keeps PopScope's canPop (and therefore the back-gesture guard) in
    // sync with dirty state as the user types.
    _emailCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<bool> _confirmDiscardIfDirty() async {
    if (!_isDirty) return true;
    return ConfirmationDialog.show(
      context,
      title: 'Abandonner l\'invitation ?',
      message: 'Les informations saisies seront perdues.',
      confirmLabel: 'Abandonner',
      isDestructive: true,
    );
  }

  Future<void> _cancel() async {
    if (!await _confirmDiscardIfDirty()) return;
    if (!mounted) return;
    Navigator.of(context).pop(false);
  }

  Future<void> _handlePopAttempt(bool didPop, bool? result) async {
    if (didPop) return;
    if (!await _confirmDiscardIfDirty()) return;
    if (!mounted) return;
    Navigator.of(context).pop(false);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await getIt<TeamRepository>().invite(
        email: _emailCtrl.text.trim(),
        role: _role,
      );
      if (!mounted) return;
      context.read<TeamListBloc>().add(const LoadTeam());
      AppSnackbar.show(context, 'Invitation envoyée.', kind: SnackKind.success);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppSnackbar.show(context, ErrorMessage.from(e), kind: SnackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: !_isDirty,
      onPopInvokedWithResult: _handlePopAttempt,
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              const Text('Inviter un membre',
                  style: AppTypography.sectionTitle),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                label: 'Adresse e-mail *',
                hint: 'praticien@cabinet.fr',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requis.';
                  final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                  if (!re.hasMatch(v.trim())) return 'E-mail invalide.';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              AppDropdown<String>(
                label: 'Rôle',
                value: _role,
                options: [
                  for (final (value, label) in kTenantRoles)
                    AppDropdownOption(value: value, label: label),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'practitioner'),
              ),
              if (_role == 'owner') ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: AppColors.warning, size: 18),
                      SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Ce rôle donne un accès complet au cabinet, sans '
                          'restriction.',
                          style: AppTypography.caption,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Annuler',
                      onPressed: _submitting ? null : _cancel,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: PrimaryButton(
                      label: 'Envoyer l\'invitation',
                      isLoading: _submitting,
                      onPressed: _submitting ? null : _submit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
