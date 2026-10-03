import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../shared/widgets/badges/status_badge.dart';
import '../../data/models/stock_level_data.dart';

/// How a stock row is named and coloured, in one place so the list, the detail
/// sheet and the lots screen always agree.
class StockStatusStyle {
  final String label;
  final StatusTone tone;
  final Color color;
  const StockStatusStyle(this.label, this.tone, this.color);
}

StockStatusStyle stockStatusOf(StockLevelData level) {
  if (level.isQuarantined) {
    return const StockStatusStyle(
      'Quarantaine',
      StatusTone.danger,
      AppColors.danger,
    );
  }
  if (level.isExpired) {
    return const StockStatusStyle('Périmé', StatusTone.danger, AppColors.danger);
  }
  if (level.isLow) {
    return const StockStatusStyle(
      'Stock bas',
      StatusTone.warning,
      AppColors.warning,
    );
  }
  if (level.isNearExpiry) {
    return const StockStatusStyle(
      'DLC proche',
      StatusTone.warning,
      AppColors.warning,
    );
  }
  return const StockStatusStyle(
    'Stock OK',
    StatusTone.success,
    AppColors.success,
  );
}

/// Fill of the gauge: the minimum threshold sits at the half-way mark, so a
/// full bar means "at least twice what is required".
double stockGaugeOf(StockLevelData level) {
  if (level.minThreshold <= 0) return level.qty > 0 ? 1 : 0;
  return (level.qty / (level.minThreshold * 2)).clamp(0.0, 1.0);
}
