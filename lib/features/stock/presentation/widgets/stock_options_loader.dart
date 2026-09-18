import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/utils/error_message.dart';
import '../../../../di/di.dart';
import '../../data/models/stock_option.dart';
import '../../data/repositories/stock_repository.dart';

/// Simple reusable widget that loads the batch + location option lists
/// and hands them to a builder. Shows a spinner while loading, an error
/// card on failure, and a warning when the list is empty.
class StockOptionsLoader extends StatefulWidget {
  final Widget Function(
    BuildContext context,
    List<StockOption> batches,
    List<StockOption> locations,
    Future<void> Function() reload,
  ) builder;

  const StockOptionsLoader({super.key, required this.builder});

  @override
  State<StockOptionsLoader> createState() => _StockOptionsLoaderState();
}

class _StockOptionsLoaderState extends State<StockOptionsLoader> {
  List<StockOption>? _batches;
  List<StockOption>? _locations;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final opts = await getIt<StockRepository>().listOptions(forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _batches = opts.batches;
        _locations = opts.locations;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ErrorMessage.from(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.dangerLight,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Impossible de charger les données de stock',
              style: AppTypography.bodyStrong,
            ),
            const SizedBox(height: 4),
            Text(_error!, style: AppTypography.caption),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Réessayer'),
              ),
            ),
          ],
        ),
      );
    }
    return widget.builder(
      context,
      _batches ?? const [],
      _locations ?? const [],
      _load,
    );
  }
}
