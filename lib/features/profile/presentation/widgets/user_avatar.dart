import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/profile_avatar.dart';

/// Circular avatar for a user, in priority order:
/// 1. a catalog role picked in the profile (`avatar:<id>`),
/// 2. a remote picture (Google sign-in fills `profile_image` with a URL),
/// 3. the first letter of the name — same fallback as the web's `UserPFP`.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.imageValue,
    required this.fallbackLabel,
    this.radius = 20,
  });

  /// Raw `profile_image` value from the backend.
  final String? imageValue;

  /// Name (or username) the initial is taken from.
  final String fallbackLabel;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatar = ProfileAvatar.resolve(imageValue);
    if (avatar != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: avatar.color,
        child: Icon(avatar.icon, size: radius * 1.1, color: Colors.white),
      );
    }

    final url = imageValue;
    if (url != null && url.startsWith('http')) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        backgroundImage: CachedNetworkImageProvider(url),
      );
    }

    final initial = fallbackLabel.trim().isEmpty
        ? '?'
        : fallbackLabel.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primaryContainer,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.9,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
