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
    this.description = '',
    this.createdAt,
    this.verified = false,
    this.gameProfiles = const [],
  });

  final String id;
  final String username;
  final String completeName;
  final String email;
  final UserRole role;

  /// Either an `avatar:<id>` pick from the app's catalog or a remote URL
  /// (Google sign-in fills this one). See `ProfileAvatar.resolve`.
  final String? profileImageUrl;

  /// Short user-authored bio shown on the profile screen.
  final String description;

  /// Sign-up date — powers the profile's "exploring since". Null when the
  /// backend didn't send it.
  final DateTime? createdAt;
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
    String? description,
    DateTime? createdAt,
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
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
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
