import 'dart:async';

import '../config/env.dart';
import '../error/app_exception.dart';
import 'cached_value.dart';

/// Stream-based stale-while-revalidate runner used by the read-side
/// repositories.
///
/// Behaviour:
///
///   1. Read the local cache. If a value exists, emit it immediately
///      (`isStale` derived from [staleAfter]).
///   2. Run [fetchRemote] in parallel.
///      * Success → write the result via [writeLocal] and emit it as
///        fresh (`isStale: false`).
///      * Network/timeout/server failure with cache present → re-emit
///        the cache as stale (`isStale: true`) so the UI can render a
///        soft warning without losing content.
///      * Failure with no cache → propagate via [Stream.addError].
///   3. Close.
///
/// The "soft" failure modes above are the ones the connectivity probe
/// or the user can recover from; everything else (validation, auth,
/// not found) bubbles unchanged so callers can show the real reason.
Stream<Cached<T>> staleWhileRevalidate<T>({
  required Future<Cached<T>?> Function() readLocal,
  required Future<T> Function() fetchRemote,
  required Future<void> Function(T value, DateTime fetchedAt) writeLocal,
  Duration? staleAfter,
  DateTime Function()? clock,
}) async* {
  final now = clock ?? DateTime.now;
  final limit = staleAfter ?? Env.cacheStaleDuration;

  Cached<T>? cached;
  try {
    cached = await readLocal();
  } catch (_) {
    cached = null;
  }

  if (cached != null) {
    final age = now().difference(cached.fetchedAt);
    yield Cached(
      value: cached.value,
      fetchedAt: cached.fetchedAt,
      isStale: age > limit,
    );
  }

  try {
    final fresh = await fetchRemote();
    final at = now();
    try {
      await writeLocal(fresh, at);
    } catch (_) {
      // Persisting the cache is best-effort. The UI still gets the
      // fresh value below.
    }
    yield Cached(value: fresh, fetchedAt: at);
  } on AppException catch (e) {
    if (cached != null && _isSoftFailure(e)) {
      yield cached.markStale();
      return;
    }
    rethrow;
  }
}

/// Failures the SWR loop should swallow when a cache is present. Hard
/// failures (validation, auth, not found) still bubble — they don't
/// look any better wrapped in a stale-cache banner.
bool _isSoftFailure(AppException e) {
  return e is NetworkException ||
      e is TimeoutException ||
      e is ServerException ||
      e is UnknownException;
}
