import 'dart:io';

/// Canonical HTTP `User-Agent` identifier for the Rayuela mobile application.
///
/// Complies with external service policies (such as the OpenStreetMap Tile
/// Usage Policy: https://operations.osmfoundation.org/policies/tiles/) which
/// forbid generic runtime user-agents like `Dart/<version> (dart:io)`.
class RayuelaUserAgent {
  const RayuelaUserAgent._();

  static const String defaultValue =
      'RayuelaMobile/1.0 (+https://github.com/Rayuela-v2)';
}

/// Process-wide [HttpOverrides] that replaces Dart's default
/// `Dart/<version> (dart:io)` `User-Agent` with [RayuelaUserAgent.defaultValue]
/// on every [HttpClient] instantiated in the current isolate (covering [Dio],
/// `package:http`, `flutter_cache_manager`, and `Image.network`).
class RayuelaHttpOverrides extends HttpOverrides {
  RayuelaHttpOverrides({this.userAgent = RayuelaUserAgent.defaultValue});

  final String userAgent;

  /// Installs [RayuelaHttpOverrides] as [HttpOverrides.global] for the
  /// current isolate.
  static void install({String userAgent = RayuelaUserAgent.defaultValue}) {
    HttpOverrides.global = RayuelaHttpOverrides(userAgent: userAgent);
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.userAgent = userAgent;
    return client;
  }
}
