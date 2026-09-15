import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

class AppVersionLabel extends StatelessWidget {
  final String version;

  const AppVersionLabel({super.key, required this.version});

  @override
  Widget build(BuildContext context) {
    return Text('Version $version', style: AppTypography.caption);
  }
}
