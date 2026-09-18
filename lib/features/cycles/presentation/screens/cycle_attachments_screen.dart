// TODO(p0): Re-enable when backend attachment upload is fixed.
// See docs/BACKEND_BUGS.md#bug-001
//
// Original implementation preserved in git history.
import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';

class CycleAttachmentsScreen extends StatelessWidget {
  final String cycleId;
  const CycleAttachmentsScreen({super.key, required this.cycleId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppBar(title: const Text('Pièces jointes')),
      body: const EmptyView(
        title: 'Fonctionnalité bientôt disponible',
        message:
            'L\'ajout de pièces jointes sera activé dans une prochaine '
            'version. Merci de votre compréhension.',
        icon: Icons.construction_outlined,
      ),
    );
  }
}
