import 'package:intl/intl.dart';

abstract final class AppCurrencyFormatter {
  static final _eur = NumberFormat.currency(locale: 'fr_FR', symbol: '€');

  static String eur(num amount) => _eur.format(amount);
}
