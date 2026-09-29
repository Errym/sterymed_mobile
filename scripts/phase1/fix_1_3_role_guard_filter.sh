#!/usr/bin/env bash
source "$(dirname "$0")/_common.sh"

banner "FIX 1.3 — RoleGuard filtering"

require_repo_root
require_clean_tree

GUARD="lib/core/router/guards/role_guard.dart"
DASH="lib/features/dashboard/presentation/screens/dashboard_screen.dart"
NAV="lib/features/shell/presentation/widgets/bottom_nav_bar.dart"

backup_file "$GUARD"
backup_file "$DASH"
backup_file "$NAV"

# ── 1. Add filterAllowed<T> helper to RoleGuard ───────────────────────
if ! grep -q "static List<T> filterAllowed" "$GUARD"; then
  HELPER=$(cat <<'DART'

  /// Filters items by whether the user is allowed to reach [routeOf(item)].
  /// Use this in every nav surface (bottom nav, governance menu, quick
  /// actions) so permissions are enforced consistently with the router.
  static List<T> filterAllowed<T>({
    required List<T> items,
    required String Function(T) routeOf,
    required bool Function(String) hasPermission,
  }) =>
      items
          .where((i) => isAllowed(route: routeOf(i), hasPermission: hasPermission))
          .toList();
DART
  )

  # Append before the final closing brace of the class.
  TMP=$(mktemp)
  # find last "}" in file
  LAST_BRACE=$(grep -n "^}" "$GUARD" | tail -n1 | cut -d: -f1 || true)
  if [[ -z "$LAST_BRACE" ]]; then
    fail "Could not find closing brace in $GUARD"
    exit 1
  fi
  head -n "$((LAST_BRACE - 1))" "$GUARD" > "$TMP"
  printf '%s\n' "$HELPER" >> "$TMP"
  tail -n +"$LAST_BRACE" "$GUARD" >> "$TMP"
  mv "$TMP" "$GUARD"
  ok "Added filterAllowed helper to $GUARD"
else
  ok "filterAllowed already present in $GUARD"
fi

# ── 2. Replace bottom nav _visibleTabs ────────────────────────────────
NAV_BLOCK=$(cat <<'DART'
  List<_NavTab> _visibleTabs() {
    final session = getIt<SessionStore>();
    return RoleGuard.filterAllowed<_NavTab>(
      items: _tabs,
      routeOf: (tab) => tab.route,
      hasPermission: session.hasPermission,
    );
  }
DART
)

if grep -q "return _tabs" "$NAV"; then
  START="  List<_NavTab> _visibleTabs() {"
  END="    return _tabs"
  # Find the actual closing of that method: the line after `return _tabs...`
  # Simplest: use replace_block with start and the line containing
  # "      .toList();" that follows. Let's do it manually.
  LINE_START=$(grep -nF "$START" "$NAV" | head -n1 | cut -d: -f1)
  LINE_RET=$(grep -nF "return _tabs" "$NAV" | head -n1 | cut -d: -f1)
  # The method ends with the first "  }" after LINE_RET.
  LINE_END=$(awk -v start="$LINE_RET" 'NR>=start && /^  }$/ {print NR; exit}' "$NAV")
  if [[ -z "$LINE_START" || -z "$LINE_END" ]]; then
    fail "Could not locate _visibleTabs block in $NAV"
    exit 1
  fi
  TMP=$(mktemp)
  head -n "$((LINE_START - 1))" "$NAV" > "$TMP"
  printf '%s\n' "$NAV_BLOCK" >> "$TMP"
  tail -n +"$((LINE_END + 1))" "$NAV" >> "$TMP"
  mv "$TMP" "$NAV"
  ok "Replaced _visibleTabs in $NAV"
else
  ok "_visibleTabs already refactored in $NAV"
fi

# ── 3. Replace _GovernanceMenu in dashboard_screen.dart ──────────────
# The menu is large. Easiest robust approach: use python to replace from
# "class _GovernanceMenu" up to and including the closing brace of the class.
if ! grep -q "filterAllowedItems" "$DASH"; then
  python3 - "$DASH" <<'PYEOF'
import re, sys, io

path = sys.argv[1]
with io.open(path, encoding='utf-8') as f:
    src = f.read()

new_menu = r'''
class _GovernanceMenu extends StatelessWidget {
  const _GovernanceMenu();

  @override
  Widget build(BuildContext context) {
    final session = getIt<SessionStore>();
    bool allowed(String route) => RoleGuard.isAllowed(
          route: route,
          hasPermission: session.hasPermission,
        );

    List<_MenuItem> filterItems(List<_MenuItem> items) =>
        items.where((item) => allowed(item.route)).toList();

    final groups = <(String, List<_MenuItem>)>[
      (
        'Opérations',
        filterItems([
          const _MenuItem('Cycles de stérilisation',
              'Suivi complet des autoclaves', Icons.autorenew, Routes.cycles),
          const _MenuItem('Stock & Catalogue', 'Niveaux, mouvements et alertes',
              Icons.inventory_2_outlined, Routes.stock),
          const _MenuItem('Lots', 'Lots, DLC et traçabilité',
              Icons.inventory_outlined, Routes.batches),
        ]),
      ),
      (
        'Prothèses',
        filterItems([
          const _MenuItem(
              'Travaux prothétiques',
              'Suivi empreinte → pose, laboratoires',
              Icons.medical_services_outlined,
              Routes.prosthetic),
        ]),
      ),
      (
        'Catalogue & Achats',
        filterItems([
          const _MenuItem('Catalogue produits', 'Consommables et références',
              Icons.category_outlined, Routes.products),
          const _MenuItem('Fournisseurs', 'Contacts et références fournisseurs',
              Icons.local_shipping_outlined, Routes.suppliers),
          const _MenuItem(
              'Commandes & Réceptions',
              'Bons de commande et réceptions',
              Icons.shopping_cart_outlined,
              Routes.purchases),
        ]),
      ),
      (
        'Clinique & Conformité',
        filterItems([
          const _MenuItem(
              'Gestion des patients',
              'Fiches patients et historiques',
              Icons.people_outline,
              Routes.patients),
          const _MenuItem(
              'Non-Conformités & Rappels',
              'Incidents et quarantaines',
              Icons.warning_amber_outlined,
              Routes.nonConformities),
          const _MenuItem('Journal d\'Audit', 'Traces immuables',
              Icons.verified_user_outlined, Routes.audit),
          const _MenuItem(
              'Recherche de preuves',
              'Traçabilité patient, cycle, lot',
              Icons.manage_search_outlined,
              Routes.evidenceSearch),
        ]),
      ),
      (
        'Administration',
        filterItems([
          const _MenuItem('Équipe & Droits', 'Comptes du personnel',
              Icons.person_add_alt_outlined, Routes.team),
          const _MenuItem('Sites & Espaces', 'Fauteuils et zones stériles',
              Icons.meeting_room_outlined, Routes.sites),
          const _MenuItem('Appareils & Programmes', 'Autoclaves et presets',
              Icons.precision_manufacturing_outlined, Routes.devices),
          const _MenuItem('Règles DLU', 'Durées limite d\'utilisation',
              Icons.timer_outlined, Routes.dluRules),
          const _MenuItem('Export Données', 'Portabilité RGPD / ARS',
              Icons.download_outlined, Routes.dataExports),
        ]),
      ),
    ];

    final hasAnyItem = groups.any((g) => g.$2.isNotEmpty);
    if (!hasAnyItem) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          children: const [
            Icon(Icons.lock_outline, size: 40, color: AppColors.textTertiary),
            SizedBox(height: AppSpacing.md),
            Text('Aucun module accessible', style: AppTypography.sectionTitle),
            SizedBox(height: AppSpacing.xs),
            Text(
              'Contactez votre administrateur pour obtenir des accès.',
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (title, items) in groups)
          if (items.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(
                  top: AppSpacing.sm, bottom: AppSpacing.xs),
              child: Text(
                title.toUpperCase(),
                style: AppTypography.label.copyWith(
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            for (final item in items) ...[
              _ActionRow(item: item),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
      ],
    );
  }
}
'''

# Replace from "class _GovernanceMenu" to the closing brace of that class.
# We locate the start, then find the matching brace by counting.
start = src.index('class _GovernanceMenu')
# find the end: the next "\n}\n" that returns to top level AFTER start.
# Count braces from the class opening.
i = src.index('{', start)
depth = 0
end = None
for j in range(i, len(src)):
    if src[j] == '{':
        depth += 1
    elif src[j] == '}':
        depth -= 1
        if depth == 0:
            end = j
            break

if end is None:
    print("Could not find end of _GovernanceMenu", file=sys.stderr)
    sys.exit(1)

src = src[:start] + new_menu.lstrip('\n') + src[end + 1:]

with io.open(path, 'w', encoding='utf-8') as f:
    f.write(src)

print("Replaced _GovernanceMenu in dashboard_screen.dart")
PYEOF
else
  ok "_GovernanceMenu already refactored in $DASH"
fi

run_analyze
commit_fix "fix(nav): filter menu and bottom nav by RoleGuard, add empty fallback" "$GUARD" "$DASH" "$NAV"

ok "FIX 1.3 complete"