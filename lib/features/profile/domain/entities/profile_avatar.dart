import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';

/// A pickable identity for a volunteer — an "expedition role" rather than a
/// photo, so the avatar carries the mission narrative instead of just being
/// decoration.
///
/// Persisted inside the existing `User.profile_image` string as
/// `avatar:<id>`, which means: no uploads, no image assets, nothing to
/// download, and it renders offline. Google accounts keep arriving with a
/// real URL in that same field — [resolve] returns null for those and the
/// UI falls back to the picture (see `UserAvatar`).
@immutable
class ProfileAvatar {
  const ProfileAvatar({
    required this.id,
    required this.icon,
    required this.color,
    required this.label,
  });

  final String id;
  final IconData icon;
  final Color color;

  /// Localised display name. The catalog is code, the copy is l10n.
  final String Function(AppLocalizations t) label;

  static const String prefix = 'avatar:';

  /// What goes into `profile_image` on the wire.
  String get storageValue => '$prefix$id';

  /// The 10 roles a volunteer can be. Order is the order shown in the picker.
  static const List<ProfileAvatar> catalog = [
    ProfileAvatar(
      id: 'explorer',
      icon: Icons.explore,
      color: RayuelaColors.primary,
      label: _labelExplorer,
    ),
    ProfileAvatar(
      id: 'naturalist',
      icon: Icons.eco,
      color: Color(0xFF2E7D32),
      label: _labelNaturalist,
    ),
    ProfileAvatar(
      id: 'bug_watcher',
      icon: Icons.emoji_nature,
      color: Color(0xFFF9A825),
      label: _labelBugWatcher,
    ),
    ProfileAvatar(
      id: 'chronicler',
      icon: Icons.photo_camera,
      color: RayuelaColors.accent,
      label: _labelChronicler,
    ),
    ProfileAvatar(
      id: 'cartographer',
      icon: Icons.map,
      color: Color(0xFF3949AB),
      label: _labelCartographer,
    ),
    ProfileAvatar(
      id: 'water_sentinel',
      icon: Icons.water_drop,
      color: Color(0xFF0097A7),
      label: _labelWaterSentinel,
    ),
    ProfileAvatar(
      id: 'night_watch',
      icon: Icons.nightlight_round,
      color: Color(0xFF5E35B1),
      label: _labelNightWatch,
    ),
    ProfileAvatar(
      id: 'trailblazer',
      icon: Icons.hiking,
      color: RayuelaColors.warning,
      label: _labelTrailblazer,
    ),
    ProfileAvatar(
      id: 'field_scientist',
      icon: Icons.science,
      color: Color(0xFF00897B),
      label: _labelFieldScientist,
    ),
    ProfileAvatar(
      id: 'forest_ranger',
      icon: Icons.forest,
      color: Color(0xFF558B2F),
      label: _labelForestRanger,
    ),
  ];

  /// Catalog entry behind [value], or null when it is empty, a remote URL, or
  /// an id this build doesn't know (a newer app version could add one — we
  /// degrade to the initial rather than crash).
  static ProfileAvatar? resolve(String? value) {
    if (value == null || !value.startsWith(prefix)) return null;
    final id = value.substring(prefix.length);
    for (final avatar in catalog) {
      if (avatar.id == id) return avatar;
    }
    return null;
  }
}

// Tear-offs, because const constructors can't hold closures.
String _labelExplorer(AppLocalizations t) => t.avatar_explorer;
String _labelNaturalist(AppLocalizations t) => t.avatar_naturalist;
String _labelBugWatcher(AppLocalizations t) => t.avatar_bug_watcher;
String _labelChronicler(AppLocalizations t) => t.avatar_chronicler;
String _labelCartographer(AppLocalizations t) => t.avatar_cartographer;
String _labelWaterSentinel(AppLocalizations t) => t.avatar_water_sentinel;
String _labelNightWatch(AppLocalizations t) => t.avatar_night_watch;
String _labelTrailblazer(AppLocalizations t) => t.avatar_trailblazer;
String _labelFieldScientist(AppLocalizations t) => t.avatar_field_scientist;
String _labelForestRanger(AppLocalizations t) => t.avatar_forest_ranger;
