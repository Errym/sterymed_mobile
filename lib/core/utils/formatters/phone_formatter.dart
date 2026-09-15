abstract final class AppPhoneFormatter {
  static String format(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return phone;
    return '${digits.substring(0, 2)} '
        '${digits.substring(2, 4)} '
        '${digits.substring(4, 6)} '
        '${digits.substring(6, 8)} '
        '${digits.substring(8, 10)}';
  }
}
