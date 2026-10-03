import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/files/file_export_service.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/error_message.dart';
import '../../../di/di.dart';
import 'app_snackbar.dart';

/// "The file is saved, now what?": open it, or share it. Shown after every
/// export so the clinic is never left wondering where the file went.
abstract final class SavedFileSheet {
  static Future<void> show(
    BuildContext context, {
    required File file,
    String title = 'Fichier enregistré',
  }) {
    final name = file.uri.pathSegments.last;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.backgroundApp,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.sectionTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                name,
                key: const Key('saved-file-name'),
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                key: const Key('saved-file-open'),
                onPressed: () async {
                  final result = await getIt<FileHandoff>().open(file);
                  if (!ctx.mounted) return;
                  if (result == HandoffResult.opened) {
                    Navigator.of(ctx).pop();
                    return;
                  }
                  AppSnackbar.show(
                    ctx,
                    result == HandoffResult.noViewer
                        ? 'Aucune application ne peut ouvrir ce fichier. '
                            'Utilisez « Partager ».'
                        : 'Impossible d\'ouvrir ce fichier.',
                    kind: SnackKind.warning,
                  );
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Ouvrir'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                key: const Key('saved-file-share'),
                onPressed: () async {
                  try {
                    await getIt<FileHandoff>().share(file);
                  } catch (e) {
                    if (!ctx.mounted) return;
                    AppSnackbar.show(
                      ctx,
                      ErrorMessage.from(e),
                      kind: SnackKind.error,
                    );
                  }
                },
                icon: const Icon(Icons.share_outlined),
                label: const Text('Partager'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
