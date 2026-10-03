/// Reads an amount typed on a French keyboard ("120,50", "1 200,5", "120.5").
///
/// `double.tryParse` only understands a dot, so a comma used to turn a valid
/// amount into `null`, which a PATCH then sent as "clear this field".
abstract final class DecimalInput {
  static final _spaces = RegExp(r'[\s\u00A0\u202F]');
  static final _plain = RegExp(r'^\d+(\.\d+)?$');

  /// The amount, or null when [raw] is empty or not a valid non-negative
  /// amount with at most [maxDecimals] decimals. Use [isInvalid] to tell the
  /// two apart.
  static double? parse(String? raw, {int maxDecimals = 2}) {
    final text = raw?.replaceAll(_spaces, '') ?? '';
    if (text.isEmpty) return null;
    final lastComma = text.lastIndexOf(',');
    final lastDot = text.lastIndexOf('.');
    final decimalAt = lastComma > lastDot ? lastComma : lastDot;
    final String normalised;
    if (decimalAt < 0) {
      normalised = text;
    } else {
      // The last separator is the decimal mark; any other is a thousands mark.
      final whole = text.substring(0, decimalAt).replaceAll(RegExp('[.,]'), '');
      normalised = '$whole.${text.substring(decimalAt + 1)}';
    }
    if (!_plain.hasMatch(normalised)) return null;
    final decimals = normalised.contains('.')
        ? normalised.length - normalised.indexOf('.') - 1
        : 0;
    if (decimals > maxDecimals) return null;
    return double.tryParse(normalised);
  }

  /// True when something was typed but it is not a usable amount.
  static bool isInvalid(String? raw, {int maxDecimals = 2}) =>
      (raw?.trim().isNotEmpty ?? false) &&
      parse(raw, maxDecimals: maxDecimals) == null;

  static const invalidMessage = 'Montant invalide (ex. 120,50).';
}
