import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart' show MediaType;

import '../../../../core/error/result.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_paths.dart';
import '../../domain/entities/checkin_request.dart';
import '../models/checkin_dtos.dart';
import '../models/checkin_history_dto.dart';

/// HTTP for the check-in endpoints. POST /checkin is multipart, so we
/// build a [FormData] payload — Dio handles the multipart framing.
///
/// IMPORTANT: the backend's FilesInterceptor uses the field name `'image'`
/// (singular). See rayuela-NodeBackend/src/module/checkin/checkin.controller.ts:
///   `@UseInterceptors(FilesInterceptor('image', MAX_IMAGES_PER_CHECKIN))`
/// Sending under any other field name silently drops the files server-side.
class CheckinsRemoteSource {
  const CheckinsRemoteSource(this._api);

  final ApiClient _api;

  static const String _imageFieldName = 'image';
  static const int _maxImages = 3;

  /// POST /checkin (multipart/form-data, max 3 image files).
  Future<Result<CheckinResultDto>> submit(CheckinRequest req) async {
    final form = FormData();

    // Body fields. Backend's CreateCheckinDto expects: latitude, longitude,
    // datetime, projectId, taskType. userId is set server-side from the JWT.
    form.fields
      ..add(MapEntry('latitude', req.latitude))
      ..add(MapEntry('longitude', req.longitude))
      ..add(MapEntry('datetime', req.datetime.toUtc().toIso8601String()))
      ..add(MapEntry('projectId', req.projectId))
      ..add(MapEntry('taskType', req.taskType));

    // Cap client-side to mirror the server's MAX_IMAGES_PER_CHECKIN guard.
    final images = req.imagePaths.take(_maxImages);
    for (final path in images) {
      form.files.add(
        MapEntry(
          _imageFieldName,
          await MultipartFile.fromFile(
            path,
            filename: _basename(path),
            contentType: _guessMediaType(path),
          ),
        ),
      );
    }

    return _api.request(
      (d) => d.post<Map<String, dynamic>>(
        ApiPaths.checkins,
        data: form,
        // Dio sets Content-Type: multipart/form-data automatically for FormData.
        options: Options(
          contentType: 'multipart/form-data',
          // Long checkins (3 photos, slow network) need extra headroom.
          sendTimeout: const Duration(seconds: 90),
          receiveTimeout: const Duration(seconds: 60),
        ),
      ),
      parse: CheckinResultDto.fromJson,
    );
  }

  /// GET /checkin/user/:projectId — the requesting user's check-in history
  /// for one project. Backend always returns an array, but we tolerate
  /// either a bare list or `{ data: [...] }` to match other endpoints.
  Future<Result<List<CheckinHistoryItemDto>>> fetchUserCheckins(
    String projectId,
  ) {
    return _api.request(
      (d) => d.get<dynamic>(ApiPaths.userCheckins(projectId)),
      parse: (raw) {
        final list = raw is List
            ? raw
            : (raw is Map && raw['data'] is List
                ? raw['data'] as List
                : const <dynamic>[]);
        return list
            .map(CheckinHistoryItemDto.tryParse)
            .whereType<CheckinHistoryItemDto>()
            .toList(growable: false);
      },
    );
  }

  String _basename(String path) {
    final i = path.lastIndexOf('/');
    return i == -1 ? path : path.substring(i + 1);
  }

  /// Best-effort content-type sniff from the file extension. Dio defaults
  /// to `application/octet-stream`, which some S3-compatible backends
  /// reject for image uploads.
  MediaType? _guessMediaType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
      return MediaType('image', 'heic');
    }
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    return null;
  }
}
