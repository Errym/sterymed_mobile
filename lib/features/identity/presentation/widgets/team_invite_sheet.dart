import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/inputs/app_dropdown.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../bloc/team_list_bloc.dart';

class TeamInviteSheet extends StatefulWidget {
  const TeamInviteSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
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
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  String _role = 'practitioner';

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<TeamListBloc>().add(InviteTeamMember(
          email: _emailCtrl.text.trim(),
          role: _role,
        ));
    AppSnackbar.show(context, 'Invitation envoyée.', kind: SnackKind.success);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
              options: const [
                AppDropdownOption(value: 'admin', label: 'Administrateur'),
                AppDropdownOption(
                    value: 'practitioner', label: 'Praticien'),
                AppDropdownOption(
                    value: 'stock_manager', label: 'Responsable stock'),
                AppDropdownOption(
                    value: 'releaser', label: 'Responsable libération'),
                AppDropdownOption(value: 'viewer', label: 'Lecture seule'),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'practitioner'),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'Envoyer l\'invitation',
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
