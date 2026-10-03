import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/storage/session_store.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../di/di.dart';
import '../../../../shared/widgets/badges/status_badge.dart';
import '../../../../shared/widgets/cards/app_card.dart';
import '../../../../shared/widgets/feedback/app_snackbar.dart';
import '../../../../shared/widgets/feedback/confirmation_dialog.dart';
import '../../../../shared/widgets/feedback/empty_view.dart';
import '../../../../shared/widgets/feedback/error_view.dart';
import '../../../../shared/widgets/inputs/filter_chip_row.dart';
import '../../../../shared/widgets/layout/app_appbar.dart';
import '../../../../shared/widgets/layout/detail_kit.dart';
import '../../../../shared/widgets/layout/form_card.dart';
import '../../../../shared/widgets/lists/animated_list_item.dart';
import '../../../../shared/widgets/lists/list_tile_skeleton.dart';
import '../../../stock/data/models/stock_level_data.dart';
import '../../../stock/data/repositories/stock_repository.dart';
import '../../data/models/product_category_data.dart';
import '../../data/models/product_data.dart';
import '../../data/repositories/product_category_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../bloc/product_list_bloc.dart';
import '../widgets/product_form_sheet.dart';

part 'product_list_screen_parts/product_filter.dart';
part 'product_list_screen_parts/product_tile.dart';
part 'product_list_screen_parts/row.dart';

class ProductListScreen extends StatelessWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProductListBloc(getIt<ProductRepository>())
        ..add(const LoadProducts()),
      child: const _ProductListView(),
    );
  }
}
