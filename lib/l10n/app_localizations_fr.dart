// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'SteryMed';

  @override
  String get welcome => 'Bienvenue';

  @override
  String get loginSubtitle =>
      'Connectez-vous pour accéder à votre espace cabinet.';

  @override
  String get tenantSlugLabel => 'Identifiant du cabinet';

  @override
  String get tenantSlugHint => 'ex. cabinet-martin';

  @override
  String get emailLabel => 'Adresse e-mail';

  @override
  String get emailHint => 'vous@cabinet.fr';

  @override
  String get passwordLabel => 'Mot de passe';

  @override
  String get loginButton => 'Se connecter';

  @override
  String get logoutButton => 'Se déconnecter';

  @override
  String get retry => 'Réessayer';

  @override
  String get loading => 'Chargement...';

  @override
  String get fieldRequired => 'Ce champ est obligatoire.';

  @override
  String get emailInvalid => 'Adresse e-mail invalide.';

  @override
  String get passwordTooShort => 'Au moins 8 caractères.';

  @override
  String get loggedOutPreviously => 'Enregistré précédemment.';

  @override
  String get offline => 'Mode hors ligne';

  @override
  String syncPending(int count) {
    return '$count en attente';
  }
}
