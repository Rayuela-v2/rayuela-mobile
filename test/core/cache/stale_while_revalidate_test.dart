import 'package:flutter_test/flutter_test.dart';
import 'package:rayuela_mobile/core/cache/cached_value.dart';
import 'package:rayuela_mobile/core/cache/stale_while_revalidate.dart';
import 'package:rayuela_mobile/core/error/app_exception.dart';

void main() {
  group('staleWhileRevalidate', () {
    test('emits cache then fresh when remote succeeds', () async {
      final fixedNow = DateTime.utc(2026, 5, 5, 10);
      Cached<int>? wrote;

      final stream = staleWhileRevalidate<int>(
        readLocal: () async => Cached(value: 1, fetchedAt: fixedNow),
        fetchRemote: () async => 2,
        writeLocal: (v, at) async {
          wrote = Cached(value: v, fetchedAt: at);
        },
        clock: () => fixedNow,
      );

      final emitted = await stream.toList();
      expect(emitted.map((c) => c.value).toList(), [1, 2]);
      expect(emitted.last.isStale, isFalse);
      expect(wrote!.value, 2);
    });

    test('marks the first emit as stale when older than staleAfter',
        () async {
      final old = DateTime.utc(2026, 5, 5, 9);
      final now = DateTime.utc(2026, 5, 5, 10);

      final stream = staleWhileRevalidate<int>(
        readLocal: () async => Cached(value: 7, fetchedAt: old),
        fetchRemote: () async => 8,
        writeLocal: (_, __) async {},
        staleAfter: const Duration(minutes: 30),
        clock: () => now,
      );

      final first = await stream.first;
      expect(first.value, 7);
      expect(first.isStale, isTrue,
          reason: 'cache is 1h old vs staleAfter=30m');
    });

    test('falls back to cache marked stale on a soft network failure',
        () async {
      final fetched = DateTime.utc(2026, 5, 5, 10);

      final stream = staleWhileRevalidate<String>(
        readLocal: () async =>
            Cached(value: 'cached', fetchedAt: fetched),
        fetchRemote: () async {
          throw const NetworkException();
        },
        writeLocal: (_, __) async {},
        clock: () => fetched,
      );

      final emitted = await stream.toList();
      expect(emitted, hasLength(2));
      expect(emitted[0].value, 'cached');
      expect(emitted[1].value, 'cached');
      expect(emitted[1].isStale, isTrue);
    });

    test('propagates hard failures (validation, auth) through the stream',
        () async {
      final stream = staleWhileRevalidate<int>(
        readLocal: () async =>
            Cached(value: 1, fetchedAt: DateTime.utc(2026, 5, 5)),
        fetchRemote: () async {
          throw const UnauthorizedException();
        },
        writeLocal: (_, __) async {},
      );

      await expectLater(
        stream,
        emitsInOrder([
          isA<Cached<int>>(),
          emitsError(isA<UnauthorizedException>()),
        ]),
      );
    });

    test('propagates the error when no cache is present', () async {
      final stream = staleWhileRevalidate<int>(
        readLocal: () async => null,
        fetchRemote: () async {
          throw const NetworkException();
        },
        writeLocal: (_, __) async {},
      );

      await expectLater(
        stream,
        emitsError(isA<NetworkException>()),
      );
    });
  });
}
