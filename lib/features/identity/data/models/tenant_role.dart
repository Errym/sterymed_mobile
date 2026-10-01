import '../../../../shared/widgets/badges/type_badge.dart';

/// The six roles from the backend's `App\Domain\Identity\Enums\TenantRole`
/// — single source of truth for how they're labeled/colored across the
/// Team feature, so a UI-only listing never drifts from the real enum
/// again (a prior "4-role" planning doc invented a fictional `reception`
/// role and dropped `admin`/`releaser`/`viewer`).
const List<(String value, String label)> kTenantRoles = [
  ('owner', 'Direction'),
  ('admin', 'Administrateur'),
  ('stock_manager', 'Responsable stock'),
  ('releaser', 'Responsable libération'),
  ('practitioner', 'Praticien'),
  ('viewer', 'Lecture seule'),
];

String tenantRoleLabel(String? role) {
  for (final (value, label) in kTenantRoles) {
    if (value == role) return label;
  }
  return role ?? 'Aucun rôle';
}

BadgeTone tenantRoleTone(String? role) {
  switch (role) {
    case 'owner':
      return BadgeTone.purple;
    case 'admin':
      return BadgeTone.blue;
    case 'stock_manager':
      return BadgeTone.orange;
    case 'releaser':
      return BadgeTone.green;
    case 'practitioner':
      return BadgeTone.green;
    case 'viewer':
      return BadgeTone.gray;
    default:
      return BadgeTone.gray;
  }
}
