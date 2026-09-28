import 'package:flutter/material.dart';

import 'cycle_info_banner.dart';

class CycleReadOnlyBanner extends StatelessWidget {
  const CycleReadOnlyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return const CycleInfoBanner(
      message: 'Vous consultez ce cycle en lecture seule. Contactez '
          'l\'équipe de stérilisation pour toute modification.',
    );
  }
}
