abstract final class Validators {
  static String? required(String? value, {String field = 'Ce champ'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field est obligatoire.';
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'L\'adresse e-mail est obligatoire.';
    }
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(value.trim())) {
      return 'Adresse e-mail invalide.';
    }
    return null;
  }

static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est obligatoire.';
    }
    if (value.length < 8) {
      return 'Au moins 8 caractères.';
    }
    return null;
  }
}
