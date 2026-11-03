import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/providers/core_providers.dart';
import '../error/result.dart';
import '../locale/locale_controller.dart';
import '../network/api_client.dart';
import '../network/api_paths.dart';
import '../network/user_agent_http_overrides.dart';

@visibleForTesting
const String kMapConfigPrefsKey = 'app.maps.config.v1';

/// Centralized map tile provider configuration returned by `GET /v1/maps/config`.
///
/// Defaults strictly comply with the OpenStreetMap Tile Usage Policy:
/// https://operations.osmfoundation.org/policies/tiles/
@immutable
class MapConfig {
  const MapConfig({
    this.urlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    this.subdomains = const <String>[],
    this.attributionText = '© OpenStreetMap contributors',
    this.attributionUrl = 'https://www.openstreetmap.org/copyright',
    this.fixMapUrl = 'https://www.openstreetmap.org/fixthemap',
    this.minZoom = 2,
    this.maxZoom = 19,
    this.userAgent = RayuelaUserAgent.defaultValue,
    this.cacheMaxAgeDays = 14,
    this.allowBulkPrefetch = false,
  });

  factory MapConfig.defaultOsm() => const MapConfig();

  factory MapConfig.fromJson(Map<String, dynamic> json) {
    final rawSubdomains = json['subdomains'];
    final subdomains = rawSubdomains is List
        ? rawSubdomains
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false)
        : const <String>[];

    final urlTemplate = (json['urlTemplate'] as String?)?.trim();
    final attributionText = (json['attributionText'] as String?)?.trim();
    final attributionUrl = (json['attributionUrl'] as String?)?.trim();
    final fixMapUrl = (json['fixMapUrl'] as String?)?.trim();
    final userAgent = (json['userAgent'] as String?)?.trim();
    final rawCacheDays = (json['cacheMaxAgeDays'] as num?)?.toInt() ?? 14;

    return MapConfig(
      urlTemplate: (urlTemplate != null && urlTemplate.isNotEmpty)
          ? urlTemplate
          : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      subdomains: subdomains,
      attributionText: (attributionText != null && attributionText.isNotEmpty)
          ? attributionText
          : '© OpenStreetMap contributors',
      attributionUrl: (attributionUrl != null && attributionUrl.isNotEmpty)
          ? attributionUrl
          : 'https://www.openstreetmap.org/copyright',
      fixMapUrl: (fixMapUrl != null && fixMapUrl.isNotEmpty)
          ? fixMapUrl
          : 'https://www.openstreetmap.org/fixthemap',
      minZoom: (json['minZoom'] as num?)?.toInt() ?? 2,
      maxZoom: (json['maxZoom'] as num?)?.toInt() ?? 19,
      userAgent: (userAgent != null && userAgent.isNotEmpty)
          ? userAgent
          : RayuelaUserAgent.defaultValue,
      cacheMaxAgeDays: rawCacheDays < 7 ? 7 : rawCacheDays,
      allowBulkPrefetch: json['allowBulkPrefetch'] == true,
    );
  }

  final String urlTemplate;
  final List<String> subdomains;
  final String attributionText;
  final String attributionUrl;
  final String fixMapUrl;
  final int minZoom;
  final int maxZoom;
  final String userAgent;
  final int cacheMaxAgeDays;
  final bool allowBulkPrefetch;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'urlTemplate': urlTemplate,
        'subdomains': subdomains,
        'attributionText': attributionText,
        'attributionUrl': attributionUrl,
        'fixMapUrl': fixMapUrl,
        'minZoom': minZoom,
        'maxZoom': maxZoom,
        'userAgent': userAgent,
        'cacheMaxAgeDays': cacheMaxAgeDays,
        'allowBulkPrefetch': allowBulkPrefetch,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapConfig &&
          urlTemplate == other.urlTemplate &&
          listEquals(subdomains, other.subdomains) &&
          attributionText == other.attributionText &&
          attributionUrl == other.attributionUrl &&
          fixMapUrl == other.fixMapUrl &&
          minZoom == other.minZoom &&
          maxZoom == other.maxZoom &&
          userAgent == other.userAgent &&
          cacheMaxAgeDays == other.cacheMaxAgeDays &&
          allowBulkPrefetch == other.allowBulkPrefetch;

  @override
  int get hashCode => Object.hash(
        urlTemplate,
        Object.hashAll(subdomains),
        attributionText,
        attributionUrl,
        fixMapUrl,
        minZoom,
        maxZoom,
        userAgent,
        cacheMaxAgeDays,
        allowBulkPrefetch,
      );
}

/// Manages the active [MapConfig]: loads any persisted copy from
/// [SharedPreferences] synchronously on startup, falls back to
/// [MapConfig.defaultOsm], and refreshes from `GET /v1/maps/config` in
/// the background when an [ApiClient] is available.
class MapConfigController extends StateNotifier<MapConfig> {
  MapConfigController({
    SharedPreferences? prefs,
    ApiClient? apiClient,
    bool autoRefresh = true,
  })  : _prefs = prefs,
        _apiClient = apiClient,
        super(_readCached(prefs)) {
    if (autoRefresh && _apiClient != null) {
      unawaited(refresh());
    }
  }

  final SharedPreferences? _prefs;
  final ApiClient? _apiClient;

  static MapConfig _readCached(SharedPreferences? prefs) {
    if (prefs == null) return MapConfig.defaultOsm();
    final raw = prefs.getString(kMapConfigPrefsKey);
    if (raw == null || raw.isEmpty) return MapConfig.defaultOsm();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return MapConfig.fromJson(decoded);
      }
    } catch (_) {
      // Corrupted cache entry — ignore and fall back to OSM defaults.
    }
    return MapConfig.defaultOsm();
  }

  /// Fetch the latest map configuration from `GET /v1/maps/config` and
  /// persist it locally. Silently retains current state when offline.
  Future<MapConfig> refresh() async {
    final client = _apiClient;
    if (client == null) return state;

    final result = await client.request<MapConfig>(
      (dio) => dio.get<Map<String, dynamic>>(ApiPaths.mapsConfig),
      parse: (data) {
        if (data is Map<String, dynamic>) {
          return MapConfig.fromJson(data);
        }
        return MapConfig.defaultOsm();
      },
    );

    if (result case Success<MapConfig>(:final value)) {
      if (mounted) {
        state = value;
      }
      try {
        await _prefs?.setString(
          kMapConfigPrefsKey,
          jsonEncode(value.toJson()),
        );
      } catch (_) {/* best-effort persistence */}
      return value;
    }
    return state;
  }
}

/// Provides the current [MapConfig] synchronously (using cached or default
/// OSM settings immediately, and updating when `GET /v1/maps/config` resolves).
///
/// Safe to read in widget tests even when `sharedPreferencesProvider` or
/// `apiClientProvider` are not overridden.
final mapConfigControllerProvider =
    StateNotifierProvider<MapConfigController, MapConfig>((ref) {
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } on UnimplementedError catch (_) {
    prefs = null;
  }

  ApiClient? apiClient;
  try {
    apiClient = ref.watch(apiClientProvider);
  } on UnimplementedError catch (_) {
    apiClient = null;
  }

  return MapConfigController(
    prefs: prefs,
    apiClient: apiClient,
  );
});

final mapConfigProvider = Provider<MapConfig>((ref) {
  return ref.watch(mapConfigControllerProvider);
});
