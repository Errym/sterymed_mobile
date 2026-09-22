/// One page of a Laravel cursor-paginated response
/// (`{data: [...], meta: {next_cursor, ...}}`).
class CursorPage<T> {
  final List<T> items;
  final String? nextCursor;

  const CursorPage({required this.items, this.nextCursor});

  bool get hasMore => nextCursor != null;

  static String? cursorFromMeta(Map<String, dynamic> json) {
    final meta = json['meta'];
    if (meta is! Map) return null;
    return meta['next_cursor']?.toString();
  }
}
