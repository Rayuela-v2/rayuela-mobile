import '../../../../core/config/env.dart';
import '../../../../core/network/api_paths.dart';

/// Resolves a backend `imageRef` (a storage key from `CheckInTemplate.imageRefs`)
/// into a fully-qualified URL the image cache can fetch.
///
/// The backend serves files via `GET /v1/storage/file?key=...`. Some
/// endpoints (older fixtures, admin uploads) already store full URLs — we
/// detect those and pass them through unchanged.
String resolveCheckinImageUrl(String ref) {
  final trimmed = ref.trim();
  if (trimmed.isEmpty) return '';
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  // Strip any leading slash so we don't end up with `//storage`.
  final key = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
  return '${Env.apiBaseUrl}${ApiPaths.storageFile(key)}';
}
