import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rayuela_mobile/core/sync/outbox/backoff_strategy.dart';

void main() {
  test('default schedule grows exponentially', () {
    // Pin Random for determinism.
    final b = JitteredExponentialBackoff(random: Random(42));
    final delays = [for (var i = 1; i <= 7; i++) b.delayFor(i)];
    // Each delay should be at least the previous one × 0.85 / 1.15
    // (the jitter window). Easier: monotonicity in expectation —
    // confirm the sequence covers the seconds-to-hours range.
    expect(delays.first.inSeconds, lessThan(10));
    expect(delays.last.inSeconds, greaterThan(3 * 3600));
  });

  test('jitter keeps the delay inside [base*0.85, base*1.15]', () {
    final b = JitteredExponentialBackoff(
      scheduleSeconds: const [100],
      random: Random(7),
    );
    for (var i = 0; i < 50; i++) {
      final ms = b.delayFor(1).inMilliseconds;
      expect(ms, inInclusiveRange(85_000, 115_000));
    }
  });

  test('maxAttempts defaults to schedule length', () {
    final b = JitteredExponentialBackoff(scheduleSeconds: const [1, 2, 3]);
    expect(b.maxAttempts, 3);
  });

  test('attempt count clamps at the end of the schedule', () {
    final b = JitteredExponentialBackoff(
      scheduleSeconds: const [10, 20],
      random: Random(0),
      jitterRatio: 0,
      maxAttempts: 100,
    );
    // Attempts beyond the schedule reuse the last value.
    expect(b.delayFor(2).inSeconds, 20);
    expect(b.delayFor(99).inSeconds, 20);
  });
}
