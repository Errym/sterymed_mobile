// Helpers for date-range filters sent to the API.
//
// A date picked in the app means a calendar day, but the server compares
// instants: "to 30 September" at 00:00 would silently drop every record made
// during that day.

/// The last second of [d]'s day when [d] has no time of its own; [d] as given
/// otherwise.
DateTime endOfDay(DateTime d) => (d.hour == 0 && d.minute == 0 && d.second == 0)
    ? DateTime(d.year, d.month, d.day, 23, 59, 59)
    : d;

/// `from` of a range as an unambiguous UTC instant.
String fromParam(DateTime d) => d.toUtc().toIso8601String();

/// `to` of a range as an unambiguous UTC instant, the whole end day included.
String toParam(DateTime d) => endOfDay(d).toUtc().toIso8601String();
