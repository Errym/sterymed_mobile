#!/usr/bin/env bash
source "$(dirname "$0")/_common.sh"

banner "FIX 1.4 — NC filter chips"

require_repo_root
require_clean_tree

FILE="lib/features/compliance/presentation/screens/non_conformities_screen.dart"
backup_file "$FILE"

# Replace everything from "class _NcView" up to (but not including) "class _NcCard".
python3 - "$FILE" <<'PYEOF'
import sys, io

path = sys.argv[1]
with io.open(path, encoding='utf-8') as f:
    src = f.read()

new_block = r'''class _NcView extends StatefulWidget {
  const _NcView();

  @override
  State<_NcView> createState() => _NcViewState();
}

class _NcViewState extends State<_NcView> {
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final canManage = getIt<SessionStore>().hasPermission(
      'non_conformities.manage',
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundApp,
      appBar: AppAppBar(
        title: 'Non-Conformités & Rappels',
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                final ok = await NcCreateSheet.show(context);
                if (ok == true && context.mounted) {
                  context
                      .read<NonConformityListBloc>()
                      .add(const LoadNonConformities());
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: FilterChipRow<String?>(
              selected: _statusFilter,
              onSelected: (v) {
                setState(() => _statusFilter = v);
                context
                    .read<NonConformityListBloc>()
                    .add(FilterNonConformities(v));
              },
              options: const [
                FilterChipOption(value: null, label: 'Toutes'),
                FilterChipOption(value: 'open', label: 'En cours'),
                FilterChipOption(value: 'resolved', label: 'Résolues'),
              ],
            ),
          ),
          Expanded(
            child: BlocBuilder<NonConformityListBloc, NonConformityListState>(
              builder: (context, state) {
                if (state.status == NonConformityStatus.loading &&
                    state.items.isEmpty) {
                  return const ListSkeleton();
                }
                if (state.status == NonConformityStatus.failure) {
                  return ErrorView(
                    message: state.error ?? 'Erreur',
                    onRetry: () => context
                        .read<NonConformityListBloc>()
                        .add(const LoadNonConformities()),
                  );
                }
                if (state.items.isEmpty) {
                  return EmptyView(
                    title: 'Aucune non-conformité',
                    message: _statusFilter == null
                        ? 'Aucun incident enregistré.'
                        : 'Aucun incident pour ce filtre.',
                    icon: Icons.verified_outlined,
                    action: canManage
                        ? FilledButton.icon(
                            onPressed: () async {
                              final ok = await NcCreateSheet.show(context);
                              if (ok == true && context.mounted) {
                                context
                                    .read<NonConformityListBloc>()
                                    .add(const LoadNonConformities());
                              }
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Nouvelle non-conformité'),
                          )
                        : null,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => context
                      .read<NonConformityListBloc>()
                      .add(const LoadNonConformities()),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: state.items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (_, i) => AnimatedListItem(
                      index: i,
                      child:
                          _NcCard(item: state.items[i], canManage: canManage),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

'''

start = src.index('class _NcView')
end = src.index('class _NcCard')
src = src[:start] + new_block + src[end:]

# Add the filter_chip_row import if not present.
if "shared/widgets/inputs/filter_chip_row.dart" not in src:
    src = src.replace(
        "import '../../../../shared/widgets/feedback/error_view.dart';",
        "import '../../../../shared/widgets/feedback/error_view.dart';\n"
        "import '../../../../shared/widgets/inputs/filter_chip_row.dart';",
    )

with io.open(path, 'w', encoding='utf-8') as f:
    f.write(src)

print("Rewrote _NcView in non_conformities_screen.dart")
PYEOF

run_analyze
commit_fix "feat(compliance): wire filter chips to NonConformityListBloc" "$FILE"

ok "FIX 1.4 complete"