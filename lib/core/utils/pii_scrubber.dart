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

  /// Diagnostics accept numeric counters and fixed protocol enums only.
  /// Free-form payloads, names, URLs, identifiers and nested maps are omitted.
  static Map<String, dynamic> diagnostics(Map<String, dynamic>? input) {
    final result = <String, dynamic>{};
    if (input == null) return result;
    for (final key in ['count', 'retry_count', 'duration_ms', 'status_code']) {
      final value = input[key];
      if (value is num && value.isFinite) result[key] = value;
    }
    final method = input['method'];
    if (const [
      'GET',
      'POST',
      'PATCH',
      'PUT',
      'DELETE',
      'HEAD',
      'OPTIONS',
    ].contains(method)) {
      result['method'] = method;
    }
    final requestId = input['request_id'];
    if (requestId is String &&
        RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(requestId)) {
      result['request_id'] = requestId;
    }
    return result;
  }
}
