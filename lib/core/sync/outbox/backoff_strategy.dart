import 'dart:math';

/// How long to wait before the next attempt of a failed outbox row.
///
/// Default schedule (in seconds), keyed by `attemptCount` *after* the
/// failure being scheduled (1-based — the first retry uses index 0):
///
///   `[5, 15, 60, 300, 1800, 7200, 21600]`  →  5s · 15s · 1m · 5m · 30m · 2h · 6h
///
/// Each delay is multiplied by a random factor in `[0.85, 1.15]` so a
/// fleet of devices coming back online doesn't synchronise their
/// retries and DDoS the backend (a textbook thundering herd).
abstract class BackoffStrategy {
  /// [attemptCount] is the number of attempts that have already failed
  /// (including the one we're scheduling for). Returns the delay until
  /// the next attempt.
  Duration delayFor(int attemptCount);

  /// Maximum number of attempts before the row is moved to `dead`.
  int get maxAttempts;
}

class JitteredExponentialBackoff implements BackoffStrategy {
  JitteredExponentialBackoff({
    List<int>? scheduleSeconds,
    this.jitterRatio = 0.15,
    Random? random,
    int? maxAttempts,
  })  : _schedule = scheduleSeconds ?? const [5, 15, 60, 300, 1800, 7200, 21600],
        _random = random ?? Random(),
        _maxAttempts = maxAttempts;

  final List<int> _schedule;
  final double jitterRatio;
  final Random _random;
  final int? _maxAttempts;

  @override
  int get maxAttempts => _maxAttempts ?? _schedule.length;

  @override
  Duration delayFor(int attemptCount) {
    final idx = (attemptCount - 1).clamp(0, _schedule.length - 1);
    final base = _schedule[idx];
    final low = 1 - jitterRatio;
    final span = jitterRatio * 2;
    final factor = low + _random.nextDouble() * span;
    final ms = (base * 1000 * factor).round();
    return Duration(milliseconds: ms);
  }
}
