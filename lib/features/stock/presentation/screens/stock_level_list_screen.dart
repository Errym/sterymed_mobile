import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/extensions/context_ext.dart';
import '../../../../core/utils/formatters/date_formatter.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/status_badge.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/feedback/loading_view.dart';
import '../../../../shared/widgets/feedback/pending_changes_banner.dart';
import '../../../../shared/widgets/inputs/filter_chip_row.dart';
import '../../../../shared/widgets/layout/form_card.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../data/models/stock_level_data.dart';
import '../../data/repositories/stock_repository.dart';
import '../bloc/stock_level_list_bloc.dart';
import '../widgets/stock_level_style.dart';
import '../widgets/stock_level_tile.dart';

part 'stock_level_list_screen_parts/stock_level_view.dart';
part 'stock_level_list_screen_parts/stock_search_bar_state.dart';
part 'stock_level_list_screen_parts/detail_row.dart';

class StockLevelListScreen extends StatelessWidget {
  const StockLevelListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => StockLevelListBloc(getIt<StockRepository>())
        ..add(const LoadStockLevels()),
      child: const _StockLevelView(),
    );
  }
}
