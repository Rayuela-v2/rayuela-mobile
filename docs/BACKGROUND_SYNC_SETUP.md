# Background sync — native setup

Sprint G (`docs/OFFLINE_SYNC_PLAN.md` §10) wires `workmanager` so the
mobile outbox keeps draining queued check‑ins when the app isn't in the
foreground. The Dart side is already in place
(`lib/core/sync/outbox/background_sync.dart` +
`background_sync_scheduler.dart`); both platforms still need their
native bits.

The notes below mirror the upstream
[workmanager README](https://pub.dev/packages/workmanager) plus a few
project‑specific identifiers.

---

## Identifiers we use

| Use | Identifier |
|---|---|
| Periodic drain (1 h, NetworkType.connected) | `com.rayuela.sync.periodic` |
| One‑off drain (kick on connectivity online) | `com.rayuela.sync.oneoff` |

These come from `BackgroundSyncTaskId` in
`lib/core/sync/outbox/background_sync_scheduler.dart`. iOS expects them
verbatim in `Info.plist`.

---

## Android

WorkManager is wired automatically by the workmanager plugin — there is
nothing to add to `AndroidManifest.xml`. Two things to double‑check:

1. **`minSdkVersion`** must be ≥ 23. Confirm in
   `android/app/build.gradle` (`defaultConfig`).
2. **Permissions**: the plugin's manifest already declares
   `RECEIVE_BOOT_COMPLETED` and `WAKE_LOCK`. They flow into our merged
   manifest at build time; no manual edits needed.

Periodic tasks fire at most every 15 min on Android (system minimum).
We schedule with a 1‑hour cadence so we always sit comfortably above
that.

---

## iOS

iOS uses `BGTaskScheduler`. The plugin still requires a few manual
changes because the OS must know the task identifiers ahead of time.

### 1. `ios/Runner/Info.plist`

Add the two identifiers under `BGTaskSchedulerPermittedIdentifiers`:

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
  <string>com.rayuela.sync.periodic</string>
  <string>com.rayuela.sync.oneoff</string>
</array>

<key>UIBackgroundModes</key>
<array>
  <string>fetch</string>
  <string>processing</string>
</array>
```

### 2. `ios/Runner/AppDelegate.swift`

```swift
import UIKit
import Flutter
import workmanager

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions:
        [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Register every task identifier we'll later schedule from Dart.
    WorkmanagerPlugin.registerTask(withIdentifier: "com.rayuela.sync.periodic")
    WorkmanagerPlugin.registerTask(withIdentifier: "com.rayuela.sync.oneoff")

    return super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions,
    )
  }
}
```

If `AppDelegate.swift` doesn't exist yet (older Flutter projects ship
an Objective‑C `AppDelegate.m`), Flutter docs cover the migration:
<https://docs.flutter.dev/release/breaking-changes/swift-app-delegate>.

### 3. iOS scheduling caveats

* iOS gives BGTaskScheduler "best effort" delivery — there's **no**
  guarantee a periodic task runs on schedule. It runs when the OS
  decides the device has time and energy. The foreground triggers
  (`AppLifecycleState.resumed`, connectivity stream) remain the
  primary drainers.
* Our 1‑hour cadence is therefore really a "drain at most once an
  hour, when iOS feels like it" hint. Volunteers will still see their
  pending banner clear within seconds of foregrounding the app.
* In Xcode, simulate background runs from the debugger:

  ```
  e -l objc -- (void)[[BGTaskScheduler sharedScheduler]
    _simulateLaunchForTaskWithIdentifier:@"com.rayuela.sync.periodic"]
  ```

---

## Verifying the wiring

After running `flutter pub get` and rebuilding:

* **Android (debug)**: `adb shell dumpsys jobscheduler` and grep for
  the package; you should see two entries. Force a run with
  `adb shell cmd jobscheduler run -f com.rayuela.mobile <jobId>`.
* **iOS (debug)**: in Xcode, Product → Scheme → Edit → Run → "Launch
  due to a background event" or use the lldb command above.
* **Either**: check the device log for the workmanager dispatcher
  ("Workmanager: dispatcher started"). The Dart side logs nothing by
  default; add a `Logger().i('drain bg start')` in
  `runOutboxBackgroundCycle` if you want a sanity print.

---

## Known limitations

* The background isolate has its own SQLite handle. SQLite + WAL is
  safe for concurrent readers/writers across isolates as long as we
  open with `synchronous=NORMAL` (we do — see `AppDatabase`).
* `flutter_secure_storage` works on both platforms in background
  isolates. Token refresh on `401` happens normally because we share
  the same SecureTokenStore.
* Push notifications (Sprint H scope) will hook into the same
  identifiers when we add them.
