import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/widgets/feedback/app_snackbar.dart';

/// Call, write to or find someone from the app. When the phone cannot open the
/// action (a tablet with no dialer, no mail app), the value is copied instead
/// and the person is told, so the tap is never silently lost.
abstract final class ContactLauncher {
  /// Keeps what a dialer understands: digits, a leading plus.
  static String dialable(String phone) =>
      phone.replaceAll(RegExp(r'[^0-9+]'), '');

  static Uri phoneUri(String phone) =>
      Uri(scheme: 'tel', path: dialable(phone));

  static Uri mailUri(String email) => Uri(scheme: 'mailto', path: email.trim());

  static Uri mapUri(String address) => Uri(
        scheme: 'geo',
        path: '0,0',
        queryParameters: {'q': address.trim()},
      );

  static Future<void> _open(
    BuildContext context,
    Uri uri,
    String copyValue,
    String copiedMessage,
  ) async {
    var opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (_) {
      opened = false;
    }
    if (opened || !context.mounted) return;
    await Clipboard.setData(ClipboardData(text: copyValue));
    if (!context.mounted) return;
    AppSnackbar.show(context, copiedMessage, kind: SnackKind.info);
  }

  static Future<void> call(BuildContext context, String phone) => _open(
        context,
        phoneUri(phone),
        phone,
        'Numéro copié : impossible d\'ouvrir le téléphone.',
      );

  static Future<void> email(BuildContext context, String email) => _open(
        context,
        mailUri(email),
        email,
        'Adresse copiée : aucune application e-mail disponible.',
      );

  static Future<void> map(BuildContext context, String address) => _open(
        context,
        mapUri(address),
        address,
        'Adresse copiée : aucune application de cartes disponible.',
      );
}
