import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/core/errors/api_exception.dart';
import 'package:steriymed_mobile/core/utils/error_message.dart';

void main() {
  // The server answers business rules in English with a stable code; a French
  // clinic must read French, and the app branches on the code, not the text.
  const english = {
    'LABEL_EXPIRED': 'This label is past its use-by date.',
    'LABEL_RECALLED': 'This label has been recalled and must not be used.',
    'LABEL_USAGE_ALREADY_RECORDED': 'This label already has a recorded usage.',
    'LABEL_NOT_PRINTABLE': 'A used label can no longer be printed.',
    'CYCLE_LOAD_LOCKED':
        'Items can only be edited while the cycle is still in draft.',
    'OWNER_ROLE_REQUIRED': 'Only an owner may do that.',
  };

  for (final entry in english.entries) {
    test('${entry.key} is shown in French, not the server English', () {
      final shown = ErrorMessage.from(
        ApiException(code: entry.key, message: entry.value, statusCode: 409),
      );
      expect(shown, isNot(entry.value));
      expect(shown, isNot(contains('This ')));
      expect(shown, isNotEmpty);
    });
  }

  test('an unknown code still shows the server message', () {
    expect(
      ErrorMessage.from(
        const ApiException(code: 'SOMETHING_NEW', message: 'Message serveur.'),
      ),
      'Message serveur.',
    );
  });
}
