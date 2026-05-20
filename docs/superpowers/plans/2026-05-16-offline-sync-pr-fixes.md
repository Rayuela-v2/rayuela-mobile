# Offline Sync PR — Review Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land all review fixes for PR #1 (`feature/offline-sync` → `main` on `Rayuela-v2/rayuela-mobile`) with one TDD-style commit per fix, fill the test gaps (`CheckinsRepositoryImpl`, `OutboxLifecycle`), then validate end-to-end locally with a real backend.

**Architecture:** Six code fixes addressing duplicate-submission risk, startup race, UX leaks, and refresh efficiency. Two new unit-test suites for previously-untested orchestration code. One manual E2E pass against the local NestJS backend covering the airplane-mode → reconnect path.

**Tech Stack:** Flutter 3.27+, Dart, sqflite (+ `sqflite_common_ffi` for tests), Riverpod, mocktail, flutter_test. Backend dependency: `rayuela-NodeBackend` running locally via `npm run start:dev` with MongoDB + Garage S3 via docker-compose.

**Repo:** `/Users/lucasmatwiejczuk/GitProjects/RayuelaWorkspace/rayuela-mobile`
**Branch:** Start from `origin/feature/offline-sync`, work on a new branch `feature/offline-sync-review-fixes`.

---

## File Map

### Files modified

| File | Why |
|---|---|
| `lib/app/bootstrap.dart` | Reorder construction so `apiClient` exists before `ConnectivityService` (Fix 2). |
| `lib/features/checkin/data/repositories/checkins_repository_impl.dart` | Mint UUID up-front; pass as Idempotency-Key on direct path + as outbox id on fallback (Fix 1). |
| `lib/features/checkin/data/sources/checkins_remote_source.dart` | Accept optional `idempotencyKey` on direct `submit` (Fix 1). |
| `lib/core/sync/outbox/outbox_service.dart` | (a) Single-flight via `bool _draining` instead of `Mutex.isLocked` race (Fix 5). (b) `retry()` no longer overwrites `last_error_message` (Fix 3). |
| `lib/core/sync/outbox/outbox_dao.dart` | Add `clearError(id)` helper used by the new `retry()` (Fix 3). |
| `lib/features/dashboard/presentation/screens/dashboard_screen.dart` | Replace double-call pull-to-refresh with `invalidate` + await stream (Fix 4a). |
| `lib/features/tasks/presentation/screens/tasks_screen.dart` | Same single-refresh pattern (Fix 4b). |
| `lib/features/dashboard/presentation/providers/project_detail_providers.dart` | Same single-refresh pattern (Fix 4c). |
| `lib/features/dashboard/presentation/providers/projects_providers.dart` | Same (touched by Fix 4a). |

### Files created (tests)

| File | What it covers |
|---|---|
| `test/features/checkin/checkins_repository_impl_test.dart` | Routing matrix for `submitCheckin` (Fix 1 + missing-test gap). |
| `test/core/sync/outbox/outbox_lifecycle_test.dart` | `bind/unbind`, app-resume trigger, connectivity-online trigger. |

### Files created (none new for production code)

No new production files — all fixes edit existing code.

---

## Task 0: Branch + baseline

**Files:**
- None (git only)

- [ ] **Step 1: Fetch and check out the PR branch**

```bash
cd /Users/lucasmatwiejczuk/GitProjects/RayuelaWorkspace/rayuela-mobile
git fetch origin
git checkout -b feature/offline-sync-review-fixes origin/feature/offline-sync
```

- [ ] **Step 2: Confirm a clean baseline by running the existing test suite**

```bash
flutter pub get
flutter test
```

Expected: every test passes. If any pre-existing test is red, stop and report — do not start work on a broken baseline.

- [ ] **Step 3: Static analysis baseline**

```bash
flutter analyze
```

Expected: zero errors, warnings tolerated only if they already exist on the PR branch. Record the warning count so later tasks don't introduce new ones.

---

## Task 1: Fix duplicate submission — mint Idempotency-Key on the direct path

**Background:** Today `_trySendDirect` calls `_remote.submit(request)` without a key. If the backend persists the check-in but the response is lost (timeout, connection error), the fallback `_enqueue` mints a *new* UUID, so the eventual drain creates a second check-in. Fix: mint the UUID at the top of `submitCheckin`, send it as `Idempotency-Key` on the direct call, and reuse it as the outbox row id on fallback.

**Files:**
- Modify: `lib/features/checkin/data/sources/checkins_remote_source.dart`
- Modify: `lib/features/checkin/data/repositories/checkins_repository_impl.dart`
- Modify: `lib/core/sync/outbox/outbox_service.dart` (accept caller-provided id)
- Test: `test/features/checkin/checkins_repository_impl_test.dart` (new)

- [ ] **Step 1: Write the failing test for "direct path sends Idempotency-Key matching outbox id on timeout fallback"**

Create `test/features/checkin/checkins_repository_impl_test.dart` with this exact contents:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rayuela_mobile/core/error/app_exception.dart';
import 'package:rayuela_mobile/core/error/result.dart';
import 'package:rayuela_mobile/core/sync/connectivity_service.dart';
import 'package:rayuela_mobile/core/sync/outbox/outbox_dao.dart';
import 'package:rayuela_mobile/core/sync/outbox/outbox_entry.dart';
import 'package:rayuela_mobile/core/sync/outbox/outbox_service.dart';
import 'package:rayuela_mobile/features/checkin/data/repositories/checkins_repository_impl.dart';
import 'package:rayuela_mobile/features/checkin/data/sources/checkins_remote_source.dart';
import 'package:rayuela_mobile/features/checkin/domain/entities/checkin_request.dart';
import 'package:rayuela_mobile/features/checkin/domain/entities/checkin_submission_outcome.dart';

class _MockRemote extends Mock implements CheckinsRemoteSource {}
class _MockOutbox extends Mock implements OutboxService {}
class _MockDao extends Mock implements OutboxDao {}
class _MockConnectivity extends Mock implements ConnectivityService {}

CheckinRequest _req() => CheckinRequest(
      projectId: 'p1',
      taskId: 't1',
      taskType: 'observation',
      latitude: '0',
      longitude: '0',
      datetime: DateTime.utc(2026, 5, 16, 12),
      notes: null,
      imagePaths: const ['/tmp/x.jpg'],
    );

void main() {
  setUpAll(() {
    registerFallbackValue(_req());
  });

  late _MockRemote remote;
  late _MockOutbox outbox;
  late _MockDao dao;
  late _MockConnectivity connectivity;

  setUp(() {
    remote = _MockRemote();
    outbox = _MockOutbox();
    dao = _MockDao();
    connectivity = _MockConnectivity();
  });

  CheckinsRepositoryImpl build() => CheckinsRepositoryImpl(
        remote: remote,
        outbox: outbox,
        outboxDao: dao,
        connectivity: connectivity,
        currentUserId: () => 'u1',
      );

  test('online + empty queue: direct submit uses the same UUID as fallback enqueue', () async {
    when(() => dao.pendingCount('u1')).thenAnswer((_) async => 0);
    when(() => connectivity.isOnlineForReal()).thenAnswer((_) async => true);

    // Direct submit times out — repository must fall through to enqueue.
    when(() => remote.submit(any(), idempotencyKey: any(named: 'idempotencyKey')))
        .thenAnswer((_) async => const Failure(TimeoutException()));

    final captured = <String>[];
    when(() => outbox.enqueue(
          id: any(named: 'id'),
          userId: any(named: 'userId'),
          projectId: any(named: 'projectId'),
          taskId: any(named: 'taskId'),
          taskType: any(named: 'taskType'),
          latitude: any(named: 'latitude'),
          longitude: any(named: 'longitude'),
          datetime: any(named: 'datetime'),
          notes: any(named: 'notes'),
          sourceImagePaths: any(named: 'sourceImagePaths'),
        )).thenAnswer((inv) async {
      final id = inv.namedArguments[#id] as String;
      captured.add(id);
      return OutboxEntry(
        id: id,
        userId: 'u1',
        projectId: 'p1',
        taskId: 't1',
        taskType: 'observation',
        latitude: '0',
        longitude: '0',
        datetime: DateTime.utc(2026, 5, 16, 12),
        clientCapturedAt: DateTime.utc(2026, 5, 16, 12),
        images: const [],
        status: OutboxStatus.pending,
        attemptCount: 0,
        createdAt: DateTime.utc(2026, 5, 16, 12),
        updatedAt: DateTime.utc(2026, 5, 16, 12),
      );
    });
    when(() => outbox.drain(userId: any(named: 'userId')))
        .thenAnswer((_) async {});

    final result = await build().submitCheckin(_req());

    // Capture the key passed to the remote.
    final keyOnDirect = verify(() => remote.submit(
          any(),
          idempotencyKey: captureAny(named: 'idempotencyKey'),
        )).captured.single as String;

    expect(captured, hasLength(1), reason: 'enqueue must have been called once');
    expect(captured.single, keyOnDirect,
        reason: 'enqueue id must equal the Idempotency-Key sent on the failed direct submit');

    expect(result, isA<Success<CheckinSubmissionOutcome>>());
    final outcome = (result as Success<CheckinSubmissionOutcome>).value;
    expect(outcome, isA<CheckinSubmissionQueued>());
  });
}
```

- [ ] **Step 2: Run the test and watch it fail**

```bash
flutter test test/features/checkin/checkins_repository_impl_test.dart
```

Expected: fails to compile — `remote.submit(...)` does not yet accept `idempotencyKey`, and `outbox.enqueue` does not yet accept `id`.

- [ ] **Step 3: Add `idempotencyKey` parameter to `CheckinsRemoteSource.submit`**

Open `lib/features/checkin/data/sources/checkins_remote_source.dart`. Locate the `submit` method signature. Add `String? idempotencyKey` and when non-null pass it as an HTTP header on the POST. Concretely:

```dart
Future<Result<CheckinResultDto>> submit(
  CheckinRequest request, {
  String? idempotencyKey,
}) async {
  final headers = <String, String>{};
  if (idempotencyKey != null) {
    headers['Idempotency-Key'] = idempotencyKey;
  }
  // … existing body construction …
  final response = await _api.post(
    ApiPaths.checkin,
    data: formData,
    options: Options(headers: headers.isEmpty ? null : headers),
  );
  // … existing response handling unchanged …
}
```

- [ ] **Step 4: Add `id` parameter to `OutboxService.enqueue`**

Open `lib/core/sync/outbox/outbox_service.dart`. Change the `enqueue` signature to accept an optional caller-provided id; default behaviour (mint a new one) is preserved when `id == null`.

```dart
Future<OutboxEntry> enqueue({
  String? id,                     // NEW
  required String userId,
  required String projectId,
  String? taskId,
  required String taskType,
  required String latitude,
  required String longitude,
  required DateTime datetime,
  String? notes,
  required List<String> sourceImagePaths,
}) async {
  final entryId = id ?? _uuid.v4();   // CHANGED
  // … rest of the method uses `entryId` instead of locally-minted `id` …
}
```

Rename every internal use of `id` inside the method to `entryId` to avoid shadowing.

- [ ] **Step 5: Rewire `CheckinsRepositoryImpl.submitCheckin` to mint up-front and thread the key**

Open `lib/features/checkin/data/repositories/checkins_repository_impl.dart`. Replace the body of `submitCheckin` and the `_trySendDirect` / `_enqueue` helpers:

```dart
@override
Future<Result<CheckinSubmissionOutcome>> submitCheckin(
  CheckinRequest request,
) async {
  final userId = _currentUserId();
  if (userId.isEmpty) {
    return const Failure(
      UnauthorizedException(message: 'You need to log in to submit a check-in'),
    );
  }

  // Mint the idempotency key once. The same value is used as the
  // Idempotency-Key on the direct attempt AND as the outbox row id on
  // fallback, so a lost-response retry is safely deduplicated server-side.
  final idempotencyKey = _uuid.v4();

  final pending = await _outboxDao.pendingCount(userId);
  final online = await _connectivity.isOnlineForReal();

  if (online && pending == 0) {
    final outcome = await _trySendDirect(request, idempotencyKey);
    if (outcome != null) return Success(outcome);
  }

  return Success(await _enqueue(request, userId, idempotencyKey));
}

Future<CheckinSubmissionOutcome?> _trySendDirect(
  CheckinRequest request,
  String idempotencyKey,
) async {
  final res = await _remote.submit(request, idempotencyKey: idempotencyKey);
  if (res case Success(:final value)) {
    return CheckinSubmissionAccepted(value.toEntity());
  }
  final error = (res as Failure).error;
  if (error is ConflictException) {
    // Server already has this idempotency key — treat as success but we
    // don't have the CheckinResult; fall through to a queued outcome so
    // the UI shows the safe "pending" path instead of a fake reward screen.
    return null;
  }
  if (error is NetworkException ||
      error is TimeoutException ||
      error is ServerException) {
    return null;
  }
  return CheckinSubmissionRejected(error);
}

Future<CheckinSubmissionQueued> _enqueue(
  CheckinRequest request,
  String userId,
  String idempotencyKey,
) async {
  final entry = await _outbox.enqueue(
    id: idempotencyKey,
    userId: userId,
    projectId: request.projectId,
    taskId: request.taskId,
    taskType: request.taskType,
    latitude: request.latitude,
    longitude: request.longitude,
    datetime: request.datetime,
    notes: request.notes,
    sourceImagePaths: request.imagePaths,
  );
  // ignore: unawaited_futures
  _outbox.drain(userId: userId);
  return CheckinSubmissionQueued(outboxId: entry.id, queuedAt: entry.createdAt);
}
```

Add `Uuid _uuid` as a constructor-injected dependency on `CheckinsRepositoryImpl`, defaulting to `const Uuid()`:

```dart
const CheckinsRepositoryImpl({
  required CheckinsRemoteSource remote,
  required OutboxService outbox,
  required OutboxDao outboxDao,
  required ConnectivityService connectivity,
  required String Function() currentUserId,
  Uuid uuid = const Uuid(),
})  : _remote = remote,
      _outbox = outbox,
      _outboxDao = outboxDao,
      _connectivity = connectivity,
      _currentUserId = currentUserId,
      _uuid = uuid;
```

Add the field and the `package:uuid/uuid.dart` import.

- [ ] **Step 6: Update the Riverpod provider wiring in `lib/features/checkin/presentation/providers/checkin_providers.dart`**

The provider that constructs `CheckinsRepositoryImpl` needs no change (the new `uuid` parameter has a default), but verify by reading the file.

- [ ] **Step 7: Run the new test — expect it to pass**

```bash
flutter test test/features/checkin/checkins_repository_impl_test.dart
```

Expected: PASS.

- [ ] **Step 8: Run the full outbox + checkin test subtree**

```bash
flutter test test/core/sync test/features/checkin
```

Expected: PASS. If `outbox_service_test.dart` breaks because of the new `id` parameter on `enqueue`, it shouldn't (the parameter is optional with default).

- [ ] **Step 9: Commit**

```bash
git add lib/features/checkin/data/sources/checkins_remote_source.dart \
        lib/features/checkin/data/repositories/checkins_repository_impl.dart \
        lib/core/sync/outbox/outbox_service.dart \
        test/features/checkin/checkins_repository_impl_test.dart
git commit -m "fix(checkin): mint Idempotency-Key up-front to prevent duplicate submissions on lost-response retry"
```

---

## Task 2: Add the full routing matrix to the CheckinsRepositoryImpl test

**Background:** Task 1 added one test (the duplicate-prevention one). The repository's routing logic still has untested branches: online+empty→accepted, online+empty→rejected (4xx), offline→queued, online+non-empty→queued. This task fills them so the most important decision in the PR is fully covered.

**Files:**
- Modify: `test/features/checkin/checkins_repository_impl_test.dart`

- [ ] **Step 1: Add four tests covering the remaining routing branches**

Append inside the `main()` block of `test/features/checkin/checkins_repository_impl_test.dart`:

```dart
test('online + empty queue + 2xx: returns Accepted, does not touch outbox', () async {
  when(() => dao.pendingCount('u1')).thenAnswer((_) async => 0);
  when(() => connectivity.isOnlineForReal()).thenAnswer((_) async => true);
  when(() => remote.submit(any(), idempotencyKey: any(named: 'idempotencyKey')))
      .thenAnswer((_) async => Success(_fakeDto()));

  final result = await build().submitCheckin(_req());

  expect(result, isA<Success<CheckinSubmissionOutcome>>());
  final outcome = (result as Success<CheckinSubmissionOutcome>).value;
  expect(outcome, isA<CheckinSubmissionAccepted>());
  verifyNever(() => outbox.enqueue(
        id: any(named: 'id'),
        userId: any(named: 'userId'),
        projectId: any(named: 'projectId'),
        taskId: any(named: 'taskId'),
        taskType: any(named: 'taskType'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
        datetime: any(named: 'datetime'),
        notes: any(named: 'notes'),
        sourceImagePaths: any(named: 'sourceImagePaths'),
      ));
});

test('online + empty queue + 4xx validation: returns Rejected, does not enqueue', () async {
  when(() => dao.pendingCount('u1')).thenAnswer((_) async => 0);
  when(() => connectivity.isOnlineForReal()).thenAnswer((_) async => true);
  when(() => remote.submit(any(), idempotencyKey: any(named: 'idempotencyKey')))
      .thenAnswer((_) async => Failure(ValidationException(
            message: 'bad',
            fieldErrors: const {},
          )));

  final result = await build().submitCheckin(_req());
  final outcome = (result as Success<CheckinSubmissionOutcome>).value;
  expect(outcome, isA<CheckinSubmissionRejected>());
  verifyNever(() => outbox.enqueue(
        id: any(named: 'id'),
        userId: any(named: 'userId'),
        projectId: any(named: 'projectId'),
        taskId: any(named: 'taskId'),
        taskType: any(named: 'taskType'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
        datetime: any(named: 'datetime'),
        notes: any(named: 'notes'),
        sourceImagePaths: any(named: 'sourceImagePaths'),
      ));
});

test('offline: enqueues without touching remote', () async {
  when(() => dao.pendingCount('u1')).thenAnswer((_) async => 0);
  when(() => connectivity.isOnlineForReal()).thenAnswer((_) async => false);
  _stubEnqueueOk();

  final result = await build().submitCheckin(_req());
  expect((result as Success).value, isA<CheckinSubmissionQueued>());
  verifyNever(() => remote.submit(any(), idempotencyKey: any(named: 'idempotencyKey')));
});

test('online + non-empty queue: enqueues to preserve FIFO, skips remote', () async {
  when(() => dao.pendingCount('u1')).thenAnswer((_) async => 3);
  when(() => connectivity.isOnlineForReal()).thenAnswer((_) async => true);
  _stubEnqueueOk();

  final result = await build().submitCheckin(_req());
  expect((result as Success).value, isA<CheckinSubmissionQueued>());
  verifyNever(() => remote.submit(any(), idempotencyKey: any(named: 'idempotencyKey')));
});
```

Add these helpers above `main()`:

```dart
CheckinResultDto _fakeDto() => CheckinResultDto(
      // adjust to match the actual DTO fields in your codebase
      id: 'srv-1',
      points: 10,
      newBadges: const [],
    );
```

And inside `setUp`, after the mock constructions, register a helper closure on the test scope:

```dart
void _stubEnqueueOk() {
  when(() => outbox.enqueue(
        id: any(named: 'id'),
        userId: any(named: 'userId'),
        projectId: any(named: 'projectId'),
        taskId: any(named: 'taskId'),
        taskType: any(named: 'taskType'),
        latitude: any(named: 'latitude'),
        longitude: any(named: 'longitude'),
        datetime: any(named: 'datetime'),
        notes: any(named: 'notes'),
        sourceImagePaths: any(named: 'sourceImagePaths'),
      )).thenAnswer((inv) async {
    final id = (inv.namedArguments[#id] as String?) ?? 'gen-id';
    return OutboxEntry(
      id: id,
      userId: 'u1',
      projectId: 'p1',
      taskId: 't1',
      taskType: 'observation',
      latitude: '0',
      longitude: '0',
      datetime: DateTime.utc(2026, 5, 16, 12),
      clientCapturedAt: DateTime.utc(2026, 5, 16, 12),
      images: const [],
      status: OutboxStatus.pending,
      attemptCount: 0,
      createdAt: DateTime.utc(2026, 5, 16, 12),
      updatedAt: DateTime.utc(2026, 5, 16, 12),
    );
  });
  when(() => outbox.drain(userId: any(named: 'userId'))).thenAnswer((_) async {});
}
```

If the real `CheckinResultDto` fields differ, open `lib/features/checkin/data/sources/checkins_remote_source.dart` (or wherever the DTO lives) and adjust `_fakeDto()` to the actual constructor.

- [ ] **Step 2: Run the test file — all five tests pass**

```bash
flutter test test/features/checkin/checkins_repository_impl_test.dart
```

Expected: 5 passed.

- [ ] **Step 3: Commit**

```bash
git add test/features/checkin/checkins_repository_impl_test.dart
git commit -m "test(checkin): cover all CheckinsRepositoryImpl routing branches"
```

---

## Task 3: Fix `retry()` overwriting `last_error_message` with non-localized debug string

**Background:** `OutboxService.retry()` calls `dao.markFailed(id, errorMessage: 'User requested immediate retry', …)`. `PendingCheckinTile` displays `lastErrorMessage` directly, so users see an English internal string the moment they tap Retry. Fix: clear the error fields on retry, don't repurpose `markFailed`.

**Files:**
- Modify: `lib/core/sync/outbox/outbox_dao.dart`
- Modify: `lib/core/sync/outbox/outbox_service.dart`
- Modify: `test/core/sync/outbox/outbox_service_test.dart`

- [ ] **Step 1: Write the failing test in `outbox_service_test.dart`**

Append inside the existing `main()` of `test/core/sync/outbox/outbox_service_test.dart`:

```dart
group('retry', () {
  test('clears prior error fields and resets eligibility (does not overwrite with debug string)',
      () async {
    final sender = _ScriptedSender([]);
    final svc = OutboxService(
      dao: dao,
      imageStore: imageStore,
      connectivity: connectivity,
      sender: sender,
      clock: () => DateTime.utc(2026, 5, 16, 12),
    );
    addTearDown(svc.dispose);

    final src = await writeFakeJpeg('r.jpg');
    final entry = await svc.enqueue(
      userId: 'u1',
      projectId: 'p1',
      taskType: 'observation',
      latitude: '0',
      longitude: '0',
      datetime: DateTime.utc(2026, 5, 16, 12),
      sourceImagePaths: [src],
    );
    await dao.markFailed(
      entry.id,
      attemptCount: 2,
      nextAttemptAt: DateTime.utc(2027),
      errorCode: 'http_503',
      errorMessage: 'Server unavailable',
    );

    final ok = await svc.retry(entry.id);
    expect(ok, isTrue);

    final row = await dao.findById(entry.id);
    expect(row!.lastErrorMessage, isNull,
        reason: 'retry must not surface an internal debug string to the UI');
    expect(row.lastErrorCode, isNull);
    expect(row.nextAttemptAt!.isBefore(DateTime.utc(2026, 5, 16, 13)), isTrue,
        reason: 'row must be eligible immediately');
  });
});
```

- [ ] **Step 2: Run — watch it fail**

```bash
flutter test test/core/sync/outbox/outbox_service_test.dart --plain-name "clears prior error"
```

Expected: FAIL. `lastErrorMessage` is `"User requested immediate retry"`, not `null`.

- [ ] **Step 3: Add `clearError` to `OutboxDao`**

Open `lib/core/sync/outbox/outbox_dao.dart`. After `markDead`, add:

```dart
/// Reset a row so it's eligible immediately and wipe the prior error
/// fields. Used by manual retry — the UI must not show stale error
/// state once the user has acknowledged it by tapping Retry.
Future<void> clearErrorAndMakeEligible(
  String id, {
  required DateTime now,
}) async {
  await _db.update(
    'outbox_checkins',
    {
      'status': OutboxStatus.pending.wireValue,
      'next_attempt_at': now.toUtc().toIso8601String(),
      'last_error_code': null,
      'last_error_message': null,
      'updated_at': _nowIso(),
    },
    where: 'id = ?',
    whereArgs: [id],
  );
}
```

- [ ] **Step 4: Rewrite `OutboxService.retry`**

Replace the body of `retry` in `lib/core/sync/outbox/outbox_service.dart`:

```dart
Future<bool> retry(String id) async {
  final row = await _dao.findById(id);
  if (row == null) return false;
  await _dao.clearErrorAndMakeEligible(id, now: _clock());
  _changesController.add(id);
  return true;
}
```

- [ ] **Step 5: Run — test passes**

```bash
flutter test test/core/sync/outbox/outbox_service_test.dart
```

Expected: all tests pass, including the new `retry` group.

- [ ] **Step 6: Commit**

```bash
git add lib/core/sync/outbox/outbox_dao.dart \
        lib/core/sync/outbox/outbox_service.dart \
        test/core/sync/outbox/outbox_service_test.dart
git commit -m "fix(outbox): clear error fields on manual retry instead of writing debug string to last_error_message"
```

---

## Task 4: Fix `late apiClient` race in bootstrap

**Background:** `ConnectivityService` is constructed before `apiClient`, but its probe closure dereferences `apiClient` via `late final`. The constructor seeds initial state asynchronously, so under load the probe can run before the `apiClient = ApiClient(...)` line, throwing `LateInitializationError`. Fix: construct `apiClient` first, then `ConnectivityService` with the now-assigned reference.

**Files:**
- Modify: `lib/app/bootstrap.dart`

- [ ] **Step 1: Read the current bootstrap to understand the order**

```bash
sed -n '1,160p' lib/app/bootstrap.dart
```

Confirm the order is: open db/imageStore → declare `late apiClient` → construct `ConnectivityService(probe: ...apiClient...)` → assign `apiClient =`. We're reversing the last two.

- [ ] **Step 2: Edit `bootstrap.dart` so `apiClient` is fully constructed before `ConnectivityService`**

In `lib/app/bootstrap.dart`, move the `apiClient = ApiClient(...)` assignment so it happens **before** `ConnectivityService(...)` is constructed, and change `late final ApiClient apiClient;` to a plain `final apiClient = ApiClient(...)`. Concretely:

Replace this block:

```dart
  late final ApiClient apiClient;

  final connectivity = ConnectivityService(
    probe: () async {
      try {
        await apiClient.raw.get<dynamic>( … );
        return true;
      } on DioException catch (e) { … }
    },
  );

  late final ProviderContainer container;

  apiClient = ApiClient(
    tokens: tokens,
    onAuthFailure: () { container.read(authControllerProvider.notifier).onSessionExpired(); },
  );
```

With this block (note: still `late` for `container` since the closure inside `apiClient` references it):

```dart
  late final ProviderContainer container;

  final apiClient = ApiClient(
    tokens: tokens,
    onAuthFailure: () {
      container.read(authControllerProvider.notifier).onSessionExpired();
    },
  );

  // ConnectivityService probe captures the now-assigned apiClient, so
  // there is no late-init window between construction and first probe.
  final connectivity = ConnectivityService(
    probe: () async {
      try {
        await apiClient.raw.get<dynamic>(
          ApiPaths.health,
          options: Options(
            sendTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 4),
            validateStatus: (_) => true,
          ),
        );
        return true;
      } on DioException catch (e) {
        return e.type != DioExceptionType.connectionTimeout &&
            e.type != DioExceptionType.receiveTimeout &&
            e.type != DioExceptionType.sendTimeout &&
            e.type != DioExceptionType.connectionError;
      } catch (_) {
        return false;
      }
    },
  );
```

- [ ] **Step 3: Add a smoke test that the construction order does not throw**

Append to `test/core/sync/connectivity_service_test.dart` (the file already exists from the PR):

```dart
test('seedInitialState completes even when probe is invoked immediately', () async {
  // Regression: bootstrap previously had a `late apiClient` race where
  // the probe closure could be invoked before the variable was assigned.
  // The fix is structural (constructor order), so this test asserts the
  // intended invariant: a probe that throws synchronously is handled
  // gracefully and the service settles into `interfaceUp`.
  final raw = _MockConnectivity();
  when(() => raw.onConnectivityChanged)
      .thenAnswer((_) => const Stream.empty());
  when(() => raw.checkConnectivity())
      .thenAnswer((_) async => [ConnectivityResult.wifi]);

  final svc = ConnectivityService(
    connectivity: raw,
    probe: () async => throw StateError('apiClient not ready'),
  );
  await Future<void>.delayed(Duration.zero);
  await svc.refresh(force: true);
  expect(svc.current, NetworkReachability.interfaceUp);
  await svc.dispose();
});
```

If `_MockConnectivity` isn't already declared in that test file, add it next to the existing mocks at the top.

- [ ] **Step 4: Run the connectivity tests**

```bash
flutter test test/core/sync/connectivity_service_test.dart
```

Expected: PASS.

- [ ] **Step 5: Smoke-build the app to confirm bootstrap still wires up**

```bash
flutter analyze lib/app/bootstrap.dart
```

Expected: no new errors.

- [ ] **Step 6: Commit**

```bash
git add lib/app/bootstrap.dart test/core/sync/connectivity_service_test.dart
git commit -m "fix(bootstrap): construct ApiClient before ConnectivityService to avoid late-init race in probe"
```

---

## Task 5: Replace `Mutex.isLocked` TOCTOU with explicit single-flight flag

**Background:** `OutboxService.drain` reads `_drainLock.isLocked` and then calls `_drainLock.protect(...)`. Two concurrent triggers can both pass the check and one ends up queued inside the mutex — defeating the "skip if already draining" intent. Fix: use an explicit `bool _draining` toggled inside the protected section, with the early-return based on it.

**Files:**
- Modify: `lib/core/sync/outbox/outbox_service.dart`
- Modify: `test/core/sync/outbox/outbox_service_test.dart`

- [ ] **Step 1: Write the failing test for "concurrent drains do not double-process"**

Append to `test/core/sync/outbox/outbox_service_test.dart`:

```dart
test('concurrent drain triggers result in at most one drain cycle', () async {
  // Sender that blocks until released. Lets us hold a drain "open" while
  // we kick a second trigger and prove it returns immediately.
  final gate = Completer<void>();
  final sender = _GatedSender(gate.future);
  final svc = OutboxService(
    dao: dao,
    imageStore: imageStore,
    connectivity: connectivity,
    sender: sender,
  );
  addTearDown(svc.dispose);

  final src = await writeFakeJpeg('g.jpg');
  await svc.enqueue(
    userId: 'u1',
    projectId: 'p1',
    taskType: 'observation',
    latitude: '0',
    longitude: '0',
    datetime: DateTime.utc(2026, 5, 16, 12),
    sourceImagePaths: [src],
  );

  final firstDrain = svc.drain(userId: 'u1');
  // Give the first drain a microtask to acquire the flag.
  await Future<void>.delayed(Duration.zero);

  // Second trigger MUST early-return without queueing behind the mutex.
  final start = DateTime.now();
  await svc.drain(userId: 'u1');
  final elapsed = DateTime.now().difference(start);
  expect(elapsed.inMilliseconds, lessThan(50),
      reason: 'second drain must skip, not block on the in-flight one');

  gate.complete();
  await firstDrain;
  expect(sender.sentCount, 1, reason: 'only one drain cycle should have run');
});
```

Add the helper class above `main()`:

```dart
class _GatedSender implements OutboxSender {
  _GatedSender(this._gate);
  final Future<void> _gate;
  int sentCount = 0;

  @override
  Future<OutboxSendOutcome> send(OutboxEntry entry) async {
    sentCount++;
    await _gate;
    return const OutboxSendSucceeded();
  }
}
```

- [ ] **Step 2: Run the test — watch it fail or hang**

```bash
flutter test test/core/sync/outbox/outbox_service_test.dart --plain-name "concurrent drain"
```

Expected: with `Mutex.isLocked` the second `drain` call serializes inside `protect` and the assertion `elapsed < 50ms` fails (it would only return after `gate.complete()`).

- [ ] **Step 3: Replace the `Mutex` early-return with an atomic flag**

In `lib/core/sync/outbox/outbox_service.dart`:

1. Remove the `import 'package:mutex/mutex.dart';` if no other code uses it.
2. Replace the field `final Mutex _drainLock = Mutex();` with `bool _draining = false;`.
3. Replace the `drain` body:

```dart
Future<void> drain({
  required String userId,
  int maxPerCycle = 50,
}) async {
  if (_draining) return;
  _draining = true;
  try {
    await _drainLoop(userId, maxPerCycle);
  } finally {
    _draining = false;
  }
}
```

Because Dart's event loop is single-threaded, the `_draining = true` assignment and the early-return both happen before any `await`, so the flag is race-free without a mutex.

If the `mutex` package is no longer referenced anywhere, remove it from `pubspec.yaml`:

```bash
grep -rn "package:mutex" lib test
```

If that returns nothing, delete the `mutex: ^3.1.0` line from `pubspec.yaml` and run `flutter pub get`.

- [ ] **Step 4: Run — test passes**

```bash
flutter test test/core/sync/outbox/outbox_service_test.dart
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/core/sync/outbox/outbox_service.dart \
        test/core/sync/outbox/outbox_service_test.dart \
        pubspec.yaml pubspec.lock
git commit -m "fix(outbox): replace Mutex.isLocked TOCTOU with explicit single-flight flag for drain"
```

---

## Task 6: Fix pull-to-refresh double-fetch (dashboard, project detail, tasks)

**Background:** Three screens implement pull-to-refresh by calling the remote source directly AND invalidating the SWR provider, which triggers a second remote fetch. Result: every pull = two HTTP requests. Fix: in each case, invalidate the provider once and await its stream's next value.

**Files:**
- Modify: `lib/features/dashboard/presentation/screens/dashboard_screen.dart`
- Modify: `lib/features/dashboard/presentation/providers/projects_providers.dart`
- Modify: `lib/features/dashboard/presentation/providers/project_detail_providers.dart`
- Modify: `lib/features/tasks/presentation/screens/tasks_screen.dart`

- [ ] **Step 1: Audit the three current implementations**

```bash
sed -n '50,90p' lib/features/dashboard/presentation/screens/dashboard_screen.dart
sed -n '60,90p' lib/features/tasks/presentation/screens/tasks_screen.dart
sed -n '30,50p' lib/features/dashboard/presentation/providers/project_detail_providers.dart
```

For each, identify (a) the SWR stream provider name and (b) the "refresh helper" provider being called alongside the invalidate.

- [ ] **Step 2: Replace dashboard pull-to-refresh**

In `lib/features/dashboard/presentation/screens/dashboard_screen.dart`, find the `onRefresh` handler. Replace its body with:

```dart
onRefresh: () async {
  ref.invalidate(subscribedProjectsProvider);
  await ref.read(subscribedProjectsProvider.stream).firstWhere(
        (cached) => !cached.isStale,
      );
},
```

Delete the now-unused `refreshSubscribedProjectsProvider` import and any call to it if no other callers remain.

- [ ] **Step 3: Replace tasks pull-to-refresh**

In `lib/features/tasks/presentation/screens/tasks_screen.dart`, find the `onRefresh` handler:

```dart
onRefresh: () async {
  ref.invalidate(projectTasksProvider(projectId));
  await ref
      .read(projectTasksProvider(projectId).stream)
      .firstWhere((cached) => !cached.isStale);
},
```

Remove the prior `repo.getTasksForProject(...)` direct call from this handler.

- [ ] **Step 4: Replace project-detail refresh helper**

In `lib/features/dashboard/presentation/providers/project_detail_providers.dart`, find `refreshProjectDetailProvider`. Either:
- (a) Delete the provider and rewrite its sole caller (`project_detail_screen.dart`) to invalidate the SWR provider and await the stream (preferred), or
- (b) Replace its body to do just `ref.invalidate(projectDetailProvider(projectId))` with no remote call. Callers that need to await the new value should `await ref.read(projectDetailProvider(projectId).stream).firstWhere((c) => !c.isStale)`.

Pick (a) if there's exactly one call site; (b) if there are multiple. Whichever you pick, follow through every call site so no caller still does both.

If you go with (a), the call site likely lives in `lib/features/dashboard/presentation/screens/project_detail_screen.dart`. Update there too.

- [ ] **Step 5: Compile-check and run any widget tests that touch these screens**

```bash
flutter analyze
flutter test test/features/checkin/outbox_banner_test.dart test/features/dashboard
```

Expected: no analyzer errors, tests pass. (Existing tests don't directly assert refresh behaviour; this fix is verified manually in Task 9.)

- [ ] **Step 6: Commit**

```bash
git add lib/features/dashboard lib/features/tasks
git commit -m "fix(ui): single-fetch pull-to-refresh on dashboard, project detail, and tasks screens"
```

---

## Task 7: Fill the test gap — `OutboxLifecycle`

**Background:** `OutboxLifecycle` is the glue that calls `OutboxService.drain` on app resume and on connectivity-online transitions. It is currently untested. Adding coverage prevents regressions when someone edits the lifecycle wiring.

**Files:**
- Test: `test/core/sync/outbox/outbox_lifecycle_test.dart` (new)

- [ ] **Step 1: Create the test file**

Create `test/core/sync/outbox/outbox_lifecycle_test.dart`:

```dart
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rayuela_mobile/core/sync/connectivity_service.dart';
import 'package:rayuela_mobile/core/sync/outbox/outbox_lifecycle.dart';
import 'package:rayuela_mobile/core/sync/outbox/outbox_service.dart';

class _MockOutbox extends Mock implements OutboxService {}
class _MockConnectivity extends Mock implements ConnectivityService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockOutbox outbox;
  late _MockConnectivity connectivity;
  late StreamController<NetworkReachability> changes;

  setUp(() {
    outbox = _MockOutbox();
    connectivity = _MockConnectivity();
    changes = StreamController<NetworkReachability>.broadcast();
    when(() => connectivity.changes).thenAnswer((_) => changes.stream);
    when(() => outbox.drain(userId: any(named: 'userId')))
        .thenAnswer((_) async {});
  });

  tearDown(() async {
    await changes.close();
  });

  test('bind triggers an opportunistic drain', () async {
    final lc = OutboxLifecycle(outbox: outbox, connectivity: connectivity);
    lc.bind('u1');
    await Future<void>.delayed(Duration.zero);
    verify(() => outbox.drain(userId: 'u1')).called(1);
  });

  test('connectivity online while bound triggers a drain', () async {
    final lc = OutboxLifecycle(outbox: outbox, connectivity: connectivity);
    lc.bind('u1');
    await Future<void>.delayed(Duration.zero);
    clearInteractions(outbox);

    changes.add(NetworkReachability.online);
    await Future<void>.delayed(Duration.zero);
    verify(() => outbox.drain(userId: 'u1')).called(1);
  });

  test('connectivity online while unbound does not drain', () async {
    final lc = OutboxLifecycle(outbox: outbox, connectivity: connectivity);
    lc.bind('u1');
    await Future<void>.delayed(Duration.zero);
    lc.unbind();
    clearInteractions(outbox);

    changes.add(NetworkReachability.online);
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => outbox.drain(userId: any(named: 'userId')));
  });

  test('connectivity offline/interfaceUp does not trigger a drain', () async {
    final lc = OutboxLifecycle(outbox: outbox, connectivity: connectivity);
    lc.bind('u1');
    await Future<void>.delayed(Duration.zero);
    clearInteractions(outbox);

    changes.add(NetworkReachability.offline);
    changes.add(NetworkReachability.interfaceUp);
    await Future<void>.delayed(Duration.zero);
    verifyNever(() => outbox.drain(userId: any(named: 'userId')));
  });

  test('app resume while bound triggers a drain', () async {
    final lc = OutboxLifecycle(outbox: outbox, connectivity: connectivity);
    lc.bind('u1');
    await Future<void>.delayed(Duration.zero);
    clearInteractions(outbox);

    lc.didChangeAppLifecycleState(AppLifecycleState.resumed);
    verify(() => outbox.drain(userId: 'u1')).called(1);
  });
}
```

- [ ] **Step 2: Run the new test file**

```bash
flutter test test/core/sync/outbox/outbox_lifecycle_test.dart
```

Expected: all 5 tests pass.

- [ ] **Step 3: Commit**

```bash
git add test/core/sync/outbox/outbox_lifecycle_test.dart
git commit -m "test(outbox): cover OutboxLifecycle bind/unbind, resume, connectivity triggers"
```

---

## Task 8: Run the full test + analyze pass before manual testing

**Files:**
- None.

- [ ] **Step 1: Full test suite**

```bash
flutter test
```

Expected: all tests green, including the new ones from Tasks 1–7. Total count should be at least the count from Task 0 baseline + the new test cases.

- [ ] **Step 2: Static analysis**

```bash
flutter analyze
```

Expected: zero new warnings/errors compared to the Task 0 baseline.

- [ ] **Step 3: Format**

```bash
flutter format lib test
```

If the formatter changes anything, commit it:

```bash
git diff --quiet || (git add lib test && git commit -m "chore: dart format")
```

---

## Task 9: Manual local testing — pull-to-refresh single fetch

**Background:** Tasks 1, 2, 3, 5, 7 are verified by automated tests. Task 6 (pull-to-refresh) is best verified by observing actual network traffic, because the bug is "two HTTP calls per refresh."

**Prerequisites:** Backend running locally per `memory/project_rayuela_start.md`.

- [ ] **Step 1: Start the backend stack**

```bash
cd /Users/lucasmatwiejczuk/GitProjects/RayuelaWorkspace/rayuela-NodeBackend
docker-compose up -d mongodb garage
# If first time: bash ../init-garage.sh
npm run start:dev
```

Wait until you see `Nest application successfully started`. Verify health:

```bash
curl -I http://localhost:3000/v1/health
```

Expected: `HTTP/1.1 200 OK` or `404` (whichever the route maps to — the probe accepts either).

- [ ] **Step 2: Start the mobile app pointed at the local backend**

```bash
cd /Users/lucasmatwiejczuk/GitProjects/RayuelaWorkspace/rayuela-mobile
flutter run --dart-define-from-file=.env.development
```

- [ ] **Step 3: Watch backend HTTP logs during a dashboard pull-to-refresh**

In the backend terminal, look for `GET /v1/projects/subscribed` lines (or whichever endpoint the dashboard hits). Pull-to-refresh on the dashboard.

Expected: **exactly one** `GET /v1/projects/subscribed` per pull. Before the fix this was two; after the fix it should be one. Repeat 3 times to confirm.

- [ ] **Step 4: Repeat for project detail and tasks screens**

Navigate into a subscribed project. Pull-to-refresh. Expected: one `GET /v1/projects/:id` and one `GET /v1/projects/:id/tasks` per pull, no doubles.

- [ ] **Step 5: Record findings**

If you observe a double fetch on any of the three screens, do not proceed to Task 10 — return to Task 6 and identify which call site still does both `invalidate` + a direct remote call.

---

## Task 10: Manual local testing — offline check-in + sync after connectivity

**Background:** The headline feature. Verifies the whole stack end-to-end: queueing while offline, idempotency on reconnect, FIFO drain order.

- [ ] **Step 1: Confirm backend supports `Idempotency-Key`**

Backend may not yet implement the header. Check:

```bash
grep -rn "Idempotency-Key" /Users/lucasmatwiejczuk/GitProjects/RayuelaWorkspace/rayuela-NodeBackend/src
```

If empty: idempotency is mobile-side only for now — the test still works (no duplicate-prevention guarantee, but the queue/drain UX is fully verifiable). Note this in your findings.

- [ ] **Step 2: Verify online happy-path (control case)**

With Wi-Fi on, the mobile app online, log in. Create a check-in normally. Expected: reward screen with points; backend log shows one `POST /v1/checkin`.

- [ ] **Step 3: Toggle airplane mode on the device/emulator**

iOS simulator: `Hardware → Network Link Conditioner → 100% Loss` or simply disconnect the host's Wi-Fi.
Android emulator: pull down notification shade → toggle airplane.

In the app, the AppBar badge should change to the cloud-off icon within a few seconds. If it doesn't, the connectivity probe isn't flipping — check that `ConnectivityService.changes` is firing.

- [ ] **Step 4: Submit a check-in while offline**

Take a photo, fill location/notes, tap Submit. Expected:
1. Submit transitions to the **Pending** screen (not the reward screen).
2. Returning to the Dashboard, the outbox banner shows "1 check-in por enviar — Ver".
3. **Settings → Datos pendientes** lists the row with status "Pendiente".

- [ ] **Step 5: Submit a second check-in while still offline**

Expected: pending count becomes 2. Verify FIFO: the older one is listed first in the pending screen (or last, depending on the design — confirm the list order matches `docs/OFFLINE_CHECKINS.md` section 5).

- [ ] **Step 6: Force-kill the app and re-open while still offline**

iOS: swipe up to dismiss. Android: recent apps → swipe.
Re-open. Expected: pending count is still 2, no rows lost, photos preview correctly. This proves images survived a process kill.

- [ ] **Step 7: Reconnect**

Disable airplane mode / reconnect Wi-Fi. Expected:
1. AppBar badge transitions cloud-off → syncing → idle within 30 seconds.
2. Pending count goes 2 → 1 → 0 in order.
3. Backend logs show two `POST /v1/checkin` requests, each with a distinct `Idempotency-Key` header (if backend logs them — otherwise just two checkins created).
4. The reward screen does **not** appear during drain (drain is silent).

- [ ] **Step 8: Verify no duplicates on the backend**

Backend Swagger or direct DB query:

```bash
docker exec -it rayuela_mongodb mongosh rayuela --eval 'db.checkins.find({}, {_id:1, createdAt:1}).sort({createdAt:-1}).limit(5)'
```

Expected: exactly two new check-in documents — one per offline submit. If you see four (Task 1 regression) or zero (drain didn't fire), investigate before signing off.

- [ ] **Step 9: Force a retry scenario**

Submit one more check-in offline. Reconnect. Immediately after the row goes "Enviando…", kill the app. Wait 30 seconds. Re-open. Expected: row reappears as `pending` (the `reclaimStaleInflight` path) and eventually drains. Backend gets exactly one new check-in (idempotency key prevents duplicate even though the row was re-sent).

This only fully passes if the backend honors `Idempotency-Key`. If not, expect *possibly* two backend rows for this one user-submission — acceptable for now and noted as a known limitation in `docs/CHANGELOG_OFFLINE.md`.

- [ ] **Step 10: Record findings in a session note**

Append a one-paragraph summary to the PR description draft (do not post to PR yet) covering:
- Pull-to-refresh: confirmed single-fetch on all three screens.
- Offline queue: N check-ins survived airplane mode + process kill, drained FIFO.
- Idempotency: backend received N unique rows (or "duplicates observed because backend does not honor key").

---

## Task 11: Push and update the PR

- [ ] **Step 1: Push the branch**

```bash
git push -u origin feature/offline-sync-review-fixes
```

- [ ] **Step 2: Open a PR or stack a commit on the existing one**

Decide with the user:
- **Option A:** Stack as a new PR targeting `feature/offline-sync` (cleanest review).
- **Option B:** Push directly to `feature/offline-sync` (fewer PRs but loses the review-fix history as a discrete unit).

Default: Option A. Do not run `gh pr create` without explicit user confirmation.

- [ ] **Step 3: Summarise what changed and link to the original Copilot comments**

In the PR body, link each fix back to the comment it addresses:
- Fix 1 → Copilot comment on `checkins_repository_impl.dart:88`
- Fix 2 → Copilot comment on `bootstrap.dart:61`
- Fix 3 → Copilot comment on `outbox_service.dart:256`
- Fix 4 → Copilot comments on `dashboard_screen.dart:61`, `tasks_screen.dart:76`, `project_detail_providers.dart:37`
- Fix 5 → independent review finding (TOCTOU on `_drainLock`)
- New tests → `CheckinsRepositoryImpl` (routing), `OutboxLifecycle` (triggers)

Do not add Claude/AI signatures (per CLAUDE.md house rule).

---

## Self-Review Notes

- **Spec coverage:** Every issue from the analysis has a task. Fix 1 → Task 1+2. Fix 2 → Task 4. Fix 3 → Task 3. Fix 4 → Task 6. Fix 5 → Task 5. Missing-test gaps → Tasks 2 and 7. Test run → Task 8. Manual UI test → Task 9. Manual E2E test → Task 10. PR update → Task 11.
- **Placeholder scan:** No TBDs. Code is provided in every modify/create step. Where DTO shape (`CheckinResultDto`) might differ from a stale assumption, Task 2 Step 1 includes an explicit instruction to confirm against the actual DTO before proceeding.
- **Type consistency:** `clearErrorAndMakeEligible` (Task 3) is referenced consistently. `OutboxService.enqueue` gains an optional `id` (Task 1) and that signature is what Task 1's test and Task 5's test exercise. `remote.submit(..., idempotencyKey: ...)` is the same shape in production code (Task 1 Step 3) and in tests (Task 1 Step 1, Task 2 Step 1).

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-05-16-offline-sync-pr-fixes.md`. Two execution options:**

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration. Best for this plan since each task is self-contained.
2. **Inline Execution** — Execute tasks in this session using `executing-plans`, batch with checkpoints. Useful if you want to watch each step.

Which approach?
