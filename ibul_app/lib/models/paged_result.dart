class PagedResult<T> {
  const PagedResult({
    required this.items,
    this.nextCursor,
  });

  final List<T> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}
