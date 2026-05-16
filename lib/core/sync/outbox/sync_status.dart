/// Coarse, UI-facing summary of the sync subsystem.
///
/// We deliberately keep this small (4 values) rather than splitting
/// every nuance into its own state — the AppBar badge and "Pending
/// data" screen only need to differentiate the cases that map to
/// different visuals.
enum SyncStatus {
  /// Either online and the queue is empty, OR online and waiting for
  /// the next eligible row to come due. The default at rest.
  idle,

  /// The drainer is currently inside an HTTP call.
  syncing,

  /// No network reachable. The badge shows an offline cloud icon.
  offline,

  /// Last drain ended with at least one row landing in `dead`. The
  /// badge turns amber and the "Pending data" screen highlights the
  /// failures.
  error,
}
