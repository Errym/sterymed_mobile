import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../shared/widgets/layout/detail_kit.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/severity_badge.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../data/models/alert_data.dart';
import '../bloc/alert_list_bloc.dart';

part 'alert_list_screen_parts/alert_list_view.dart';
part 'alert_list_screen_parts/count.dart';

/// The alert kinds the server raises (`AlertType`). There is deliberately no
/// "overdue control" entry: the server does not raise that alert yet.
const alertTypeLabels = <String, String>{
  'low_stock': 'Stock bas',
  'near_expiry': 'Péremption proche',
  'expired': 'Périmé',
  'failed_cycle': 'Cycle en échec',
};


class AlertListScreen extends StatelessWidget {
  const AlertListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => AlertListBloc(ctx.read())..add(const LoadAlerts()),
      child: const _AlertListView(),
    );
  }
}
