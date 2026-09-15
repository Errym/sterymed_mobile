import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';

class ProfileMenu extends StatelessWidget {
  final String displayName;
  final String email;
  final String role;

  const ProfileMenu({
    super.key,
    required this.displayName,
    required this.email,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      onSelected: (value) {
        switch (value) {
          case 'settings':
            context.go(Routes.settings);
            break;
          case 'logout':
            context.read<AuthBloc>().add(const AuthLogoutRequested());
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(displayName, style: AppTypography.bodyStrong),
              const SizedBox(height: 2),
              Text(email, style: AppTypography.caption),
              const SizedBox(height: 2),
              Text(
                role,
                style: AppTypography.caption.copyWith(
                  color: AppColors.brandPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings_outlined, size: 18),
              SizedBox(width: AppSpacing.sm),
              Text('Paramètres'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18, color: AppColors.danger),
              SizedBox(width: AppSpacing.sm),
              Text('Se déconnecter'),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.brandPrimaryLight,
          child: Text(
            _initials(displayName),
            style: AppTypography.bodyStrong.copyWith(
              color: AppColors.brandPrimary,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
