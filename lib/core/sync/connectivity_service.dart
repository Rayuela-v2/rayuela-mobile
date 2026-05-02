import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Cross-feature view of the device's network state.
///
/// `connectivity_plus` only tells us whether the OS thinks an interface
/// (Wi-Fi, mobile, ethernet, …) is up. That's not enough for the outbox
/// drainer: a captive portal, a paused VPN, or a Wi-Fi without WAN
/// access all show up as "connected" but every request still fails. So
/// we layer a [ReachabilityProbe] on top — typically a `HEAD /health`
/// against the backend, wired in `bootstrap.dart`.
///
/// State machine:
///   * [NetworkReachability.offline]      – no interface up.
///   * [NetworkReachability.interfaceUp]  – interface up, probe pending.
///   * [NetworkReachability.online]       – interface up AND probe OK.
enum NetworkReachability { offline, interfaceUp, online }

/// Side-effect-free "is the backend reachable right now?" check.
/// Returning `true` promotes [NetworkReachability.interfaceUp] to
/// [NetworkReachability.online]; returning `false` keeps it as
/// [NetworkReachability.interfaceUp] so the UI can show a degraded
/// banner (rather than a hard "offline" one).
typedef ReachabilityProbe = Future<bool> Function();

/// Default probe: trust the OS. Suitable for tests and for cold start
/// before the API client is wired up.
Future<bool> _alwaysReachable() async => true;

/// Reactive wrapper around `connectivity_plus`.
///
/// Lifecycle: instantiate once at bootstrap, dispose on app shutdown
/// (via the Riverpod provider). The class owns its internal
/// subscriptions and exposes a broadcast [changes] stream that any
/// number of widgets/services can listen to.
class ConnectivityService {
  ConnectivityService({
    Connectivity? connectivity,
    ReachabilityProbe? probe,
    Duration probeCooldown = const Duration(seconds: 30),
  })  : _connectivity = connectivity ?? Connectivity(),
        _probe = probe ?? _alwaysReachable,
        _probeCooldown = probeCooldown {
    _interfaceSub = _connectivity.onConnectivityChanged.listen(
      _handleInterfaceChange,
      onError: (_) {/* connectivity_plus very rarely errors */},
    );
    // Seed with the current state so callers don't have to wait for the
    // first change event (the OS might not emit one if nothing changes).
    unawaited(_seedInitialState());
  }

  final Connectivity _connectivity;
  final ReachabilityProbe _probe;
  final Duration _probeCooldown;

  StreamSubscription<List<ConnectivityResult>>? _interfaceSub;
  final StreamController<NetworkReachability> _controller =
      StreamController<NetworkReachability>.broadcast();

  NetworkReachability _last = NetworkReachability.interfaceUp;
  DateTime _lastProbedAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Last reachability we computed. The value is updated whenever
  /// [refresh] runs or when `connectivity_plus` emits a change.
  NetworkReachability get current => _last;

  /// Broadcast stream of state transitions. Replays nothing — use
  /// [current] for the "right now" value.
  Stream<NetworkReachability> get changes => _controller.stream;

  /// Force a re-evaluation: read the OS interface state and (if up)
  /// run the probe. Outbox drainer calls this before processing rows.
  ///
  /// The probe is throttled by [probeCooldown] to avoid hammering the
  /// backend when many drainer ticks land back to back.
  Future<NetworkReachability> refresh({bool force = false}) async {
    final interfaces = await _connectivity.checkConnectivity();
    return _evaluate(interfaces, force: force);
  }

  /// Whether the drainer should attempt a network call right now.
  /// Equivalent to `(await refresh()) == online`, but spelled out
  /// because that's the most common call site.
  Future<bool> isOnlineForReal({bool force = false}) async {
    return (await refresh(force: force)) == NetworkReachability.online;
  }

  /// Tear down subscriptions. Safe to call multiple times.
  Future<void> dispose() async {
    await _interfaceSub?.cancel();
    _interfaceSub = null;
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Future<void> _seedInitialState() async {
    try {
      final interfaces = await _connectivity.checkConnectivity();
      await _evaluate(interfaces, force: true);
    } catch (_) {
      _emit(NetworkReachability.interfaceUp);
    }
  }

  Future<void> _handleInterfaceChange(List<ConnectivityResult> r) async {
    await _evaluate(r, force: true);
  }

  Future<NetworkReachability> _evaluate(
    List<ConnectivityResult> interfaces, {
    required bool force,
  }) async {
    if (_isOffline(interfaces)) {
      _emit(NetworkReachability.offline);
      return _last;
    }

    // Interface is up — probe to figure out whether the backend is
    // actually reachable. Throttle so the drainer can call refresh()
    // freely without a probe storm.
    final now = DateTime.now();
    if (!force && now.difference(_lastProbedAt) < _probeCooldown) {
      return _last;
    }
    _lastProbedAt = now;

    bool reachable;
    try {
      reachable = await _probe();
    } catch (_) {
      reachable = false;
    }
    _emit(reachable
        ? NetworkReachability.online
        : NetworkReachability.interfaceUp);
    return _last;
  }

  static bool _isOffline(List<ConnectivityResult> r) {
    if (r.isEmpty) return true;
    return r.every((e) => e == ConnectivityResult.none);
  }

  void _emit(NetworkReachability next) {
    if (_last == next) return;
    _last = next;
    if (!_controller.isClosed) {
      _controller.add(next);
    }
  }
}
