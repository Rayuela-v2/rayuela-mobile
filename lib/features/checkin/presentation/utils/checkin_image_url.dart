import '../../../../core/config/env.dart';
import '../../../../core/network/api_paths.dart';

/// Resolves any backend storage reference (checkin photo, badge icon,
/// or project cover image) into a fully-qualified URL the image cache can fetch.
///
/// The backend serves files via `GET /v1/storage/file?key=...`. External
/// fixtures or URLs (`http://`, `https://`) are passed through unchanged.
String resolveStorageUrl(String ref) {
  final trimmed = ref.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  // Strip any leading slash so we don't end up with `//storage`.
  final key = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
  return '${Env.apiBaseUrl}${ApiPaths.storageFile(key)}';
}

/// Backwards-compatible alias for [resolveStorageUrl].
String resolveCheckinImageUrl(String ref) => resolveStorageUrl(ref);

