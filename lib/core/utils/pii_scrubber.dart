abstract final class PiiScrubber {
  static final _patterns = <RegExp, String>{
    RegExp(r'"token"\s*:\s*"[^"]*"'): '"token":"[REDACTED]"',
    RegExp(r'"password"\s*:\s*"[^"]*"'): '"password":"[REDACTED]"',
    RegExp(r'"patient_id"\s*:\s*"[^"]*"'): '"patient_id":"[REDACTED]"',
    RegExp(r'"practitioner_id"\s*:\s*"[^"]*"'):
        '"practitioner_id":"[REDACTED]"',
    RegExp(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*'): 'Bearer [REDACTED]',
  };

  static String scrub(String input) {
    var out = input;
    for (final entry in _patterns.entries) {
      out = out.replaceAll(entry.key, entry.value);
    }
    return out;
  }
}