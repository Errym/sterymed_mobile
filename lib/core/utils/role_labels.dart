import '../../features/identity/data/models/tenant_role.dart';

/// How a backend role is named and described to people. The names come from
/// the team module's own list (`kTenantRoles`), so a role has one name on every
/// screen; this adds the plain-language descriptions.
abstract final class RoleLabels {
  /// What a role is for, in the words of a clinic (not of a permission list).
  static const _descriptions = <String, String>{
    'owner': 'Accès complet au cabinet, sans restriction.',
    'admin': 'Gère l\'équipe, le stock, les commandes et les réglages.',
    'stock_manager': 'Gère le stock, les lots, les commandes et les réceptions.',
    'releaser': 'Décide de la libération des cycles de stérilisation.',
    'practitioner':
        'Utilise le matériel stérile et suit les travaux prothétiques.',
    'viewer': 'Consulte les informations, sans rien modifier.',
  };

  /// A short line saying what a role's home screen is about.
  static const _focus = <String, String>{
    'owner': 'Vue d\'ensemble du cabinet',
    'admin': 'Vue d\'ensemble du cabinet',
    'stock_manager': 'Stock, commandes et réceptions',
    'releaser': 'Cycles et décisions de libération',
    'practitioner': 'Étiquettes, patients et prothèses',
    'viewer': 'Consultation en lecture seule',
  };

  static String of(String? role) => tenantRoleLabel(role);

  static String describe(String? role) =>
      _descriptions[role] ?? 'Droits définis par le cabinet.';

  static String focusOf(String? role) =>
      _focus[role] ?? 'Voici la situation du cabinet';
}
