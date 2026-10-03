import 'package:flutter_test/flutter_test.dart';
import 'package:steriymed_mobile/features/labels/data/repositories/label_repository.dart';

void main() {
  const id = '0199aaaa-bbbb-7ccc-8ddd-eeeeeeeeeeee';

  test('reads the id out of a scanned urn or a bare id', () {
    expect(LabelRepository.idFromCode('urn:steriqore:label:$id'), id);
    expect(LabelRepository.idFromCode('  $id  '), id);
    expect(LabelRepository.idFromCode(id.toUpperCase()), id);
  });

  test('anything else is not an id (the caller falls back to a lookup)', () {
    for (final bad in ['', 'LOT-42', 'urn:steriqore:label:', '123e4567']) {
      expect(LabelRepository.idFromCode(bad), isNull, reason: bad);
    }
  });
}
