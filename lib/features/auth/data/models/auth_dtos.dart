import '../../../../core/error/app_exception.dart';
import '../../domain/entities/auth_user.dart';

/// POST /auth/login body
class LoginRequestDto {
  const LoginRequestDto({required this.username, required this.password});

  final String username;
  final String password;

  Map<String, dynamic> toJson() => {
        'username': username,
        'password': password,
      };
}

/// POST /auth/login response.
///
/// Backend today (see auth.service.ts) returns `{access_token, username}`.
/// Once backend §4.1 ships the refresh-token flow it will also return
/// `refreshToken` and `expiresIn`. The DTO accepts both shapes and is
/// defensive about missing fields — we never blind-cast null to non-nullable.
class LoginResponseDto {
  const LoginResponseDto({
    required this.accessToken,
    this.refreshToken,
    this.username,
    this.expiresIn,
  });

  final String accessToken;
  final String? refreshToken;
  final String? username;
  final int? expiresIn;

  factory LoginResponseDto.fromJson(Object? raw) {
    final json = _asMap(raw, 'login response');
    final token = _firstString(json, const ['accessToken', 'access_token']);
    if (token == null || token.isEmpty) {
      throw const ValidationException(
        message: 'Login response is missing the access token',
      );
    }
    return LoginResponseDto(
      accessToken: token,
      refreshToken:
          _firstString(json, const ['refreshToken', 'refresh_token']),
      username: _firstString(json, const ['username', '_username']),
      expiresIn: _asInt(json['expiresIn'] ?? json['expires_in']),
    );
  }
}

/// POST /auth/register body
class RegisterRequestDto {
  const RegisterRequestDto({
    required this.completeName,
    required this.username,
    required this.email,
    required this.password,
    this.profileImage,
  });

  final String completeName;
  final String username;
  final String email;
  final String password;
  final String? profileImage;

  Map<String, dynamic> toJson() => {
        'complete_name': completeName,
        'username': username,
        'email': email,
        'password': password,
        if (profileImage != null) 'profile_image': profileImage,
      };
}

/// GET /user
///
/// The backend currently returns the raw `User` entity instance, which
/// JSON-serialises with the private underscore-prefixed field names
/// (`_username`, `_completeName`, `_email`, `_profileImage`, `_verified`,
/// `_role`, `_id`, `_gameProfiles`, ...). We accept both the underscore form
/// and the cleaned snake_case / camelCase form so this DTO keeps working
/// when backend §4.1 adds a proper response mapper.
class UserDto {
  const UserDto({
    required this.id,
    required this.username,
    required this.completeName,
    required this.email,
    required this.role,
    this.profileImage,
    this.verified = false,
    this.gameProfiles = const [],
  });

  final String id;
  final String username;
  final String completeName;
  final String email;
  final String role;
  final String? profileImage;
  final bool verified;
  final List<GameProfileDto> gameProfiles;

  factory UserDto.fromJson(Object? raw) {
    final json = _asMap(raw, 'user');
    return UserDto(
      id: _firstString(json, const ['_id', 'id']) ?? '',
      username:
          _firstString(json, const ['_username', 'username']) ?? '',
      completeName: _firstString(json, const [
            '_completeName',
            'completeName',
            'complete_name',
          ]) ??
          '',
      email: _firstString(json, const ['_email', 'email']) ?? '',
      role: _firstString(json, const ['_role', 'role']) ?? 'Volunteer',
      profileImage: _firstString(json, const [
        '_profileImage',
        'profileImage',
        'profile_image',
      ]),
      verified: _asBool(json['_verified'] ?? json['verified']) ?? false,
      gameProfiles: _parseGameProfiles(
        json['_gameProfiles'] ?? json['gameProfiles'],
      ),
    );
  }

  AuthUser toEntity() => AuthUser(
        id: id,
        username: username,
        completeName: completeName.isEmpty ? username : completeName,
        email: email,
        role: UserRole.fromApi(role),
        profileImageUrl: profileImage,
        verified: verified,
        gameProfiles:
            gameProfiles.map((dto) => dto.toEntity()).toList(growable: false),
      );
}

/// `User._gameProfiles[i]` — per-project gamification record on the user.
class GameProfileDto {
  const GameProfileDto({
    required this.projectId,
    required this.points,
    required this.badges,
    required this.active,
  });

  final String projectId;
  final int points;
  final List<String> badges;
  final bool active;

  factory GameProfileDto.fromJson(Object? raw) {
    final json = _asMap(raw, 'gameProfile');
    final badgesRaw = json['badges'];
    return GameProfileDto(
      projectId: _firstString(json, const ['projectId', '_projectId']) ?? '',
      points: _asInt(json['points']) ?? 0,
      badges: badgesRaw is List
          ? badgesRaw.map((b) => b.toString()).toList(growable: false)
          : const <String>[],
      active: _asBool(json['active']) ?? false,
    );
  }

  UserGameProfile toEntity() => UserGameProfile(
        projectId: projectId,
        points: points,
        badges: badges,
        active: active,
      );
}

List<GameProfileDto> _parseGameProfiles(Object? raw) {
  if (raw is! List) return const [];
  final out = <GameProfileDto>[];
  for (final item in raw) {
    try {
      out.add(GameProfileDto.fromJson(item));
    } catch (_) {
      // Skip malformed entries; we don't want a single bad row to take down
      // the whole user fetch.
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// Defensive parsing helpers
// ---------------------------------------------------------------------------

Map<String, dynamic> _asMap(Object? raw, String what) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return raw.map((k, v) => MapEntry(k.toString(), v));
  throw ValidationException(
    message: 'Expected an object for $what but got ${raw.runtimeType}',
  );
}

/// Returns the first non-null, non-empty string value among [keys] in [json],
/// or null. Numeric values are coerced via [Object.toString].
String? _firstString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final v = json[key];
    if (v == null) continue;
    if (v is String) {
      if (v.isEmpty) continue;
      return v;
    }
    if (v is num || v is bool) return v.toString();
  }
  return null;
}

int? _asInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

bool? _asBool(Object? v) {
  if (v == null) return null;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.toLowerCase();
    if (s == 'true' || s == '1' || s == 'yes') return true;
    if (s == 'false' || s == '0' || s == 'no') return false;
  }
  return null;
}
