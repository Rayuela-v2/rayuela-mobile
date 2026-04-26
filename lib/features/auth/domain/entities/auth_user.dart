/// Domain representation of the current user. Mobile screens bind to this,
/// never to the raw DTO.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.completeName,
    required this.email,
    required this.role,
    this.profileImageUrl,
    this.verified = false,
    this.gameProfiles = const [],
  });

  final String id;
  final String username;
  final String completeName;
  final String email;
  final UserRole role;
  final String? profileImageUrl;
  final bool verified;

  /// Per-project gamification record. Populated from `_gameProfiles` on
  /// `GET /user`. Used by the dashboard to overlay points/badges onto
  /// each project card.
  final List<UserGameProfile> gameProfiles;

  bool get isAdmin => role == UserRole.admin;
  bool get isVolunteer => role == UserRole.volunteer;

  UserGameProfile? gameProfileFor(String projectId) {
    for (final gp in gameProfiles) {
      if (gp.projectId == projectId) return gp;
    }
    return null;
  }

  AuthUser copyWith({
    String? id,
    String? username,
    String? completeName,
    String? email,
    UserRole? role,
    String? profileImageUrl,
    bool? verified,
    List<UserGameProfile>? gameProfiles,
  }) {
    return AuthUser(
      id: id ?? this.id,
      username: username ?? this.username,
      completeName: completeName ?? this.completeName,
      email: email ?? this.email,
      role: role ?? this.role,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      verified: verified ?? this.verified,
      gameProfiles: gameProfiles ?? this.gameProfiles,
    );
  }
}

class UserGameProfile {
  const UserGameProfile({
    required this.projectId,
    required this.points,
    required this.badges,
    required this.active,
  });

  final String projectId;
  final int points;
  final List<String> badges;
  final bool active;
}

enum UserRole {
  admin,
  volunteer,
  unknown;

  static UserRole fromApi(String? raw) {
    switch (raw) {
      case 'Admin':
        return UserRole.admin;
      case 'Volunteer':
        return UserRole.volunteer;
      default:
        return UserRole.unknown;
    }
  }
}
