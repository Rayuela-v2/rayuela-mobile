/// Wraps a piece of data with the moment it was retrieved.
///
/// `isStale` is `true` whenever the value comes from local storage and
/// either:
///   * the wall clock distance to [fetchedAt] exceeds the entity's
///     freshness budget, OR
///   * a remote refresh has just failed and we're falling back to the
///     last known good copy.
///
/// UI surfaces "Updated 4 m ago" / "Showing offline copy" labels off
/// of these two fields, so consistency across providers matters more
/// than the exact threshold (each repo decides its own).
class Cached<T> {
  const Cached({
    required this.value,
    required this.fetchedAt,
    this.isStale = false,
  });

  final T value;
  final DateTime fetchedAt;
  final bool isStale;

  Cached<T> markStale() => Cached(
        value: value,
        fetchedAt: fetchedAt,
        isStale: true,
      );

  Cached<R> map<R>(R Function(T) f) => Cached(
        value: f(value),
        fetchedAt: fetchedAt,
        isStale: isStale,
      );
}
