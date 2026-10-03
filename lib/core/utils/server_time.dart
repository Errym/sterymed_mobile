/// Reads a timestamp sent by the server.
///
/// The API sends ISO-8601 in UTC (`2026-10-03T07:15:40+00:00`). `DateTime`
/// keeps that as a UTC value, and formatting a UTC value prints the UTC clock:
/// a French clinic would read every cycle, usage and audit time one or two
/// hours early. Converting once, here, at the edge means every screen shows the
/// phone's own local time. Date-only strings (`2026-11-03`) are already local
/// and pass through unchanged.
DateTime? parseServerTime(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text)?.toLocal();
}
