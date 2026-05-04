import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Small footer-style label that surfaces the freshness of a SWR-backed
/// view: when the data was fetched and whether it's currently the
/// stale fallback for a failed network call.
///
/// Renders nothing when [fetchedAt] is null so screens can drop it in
/// next to a `RefreshIndicator` without conditional widgets.
class LastUpdatedChip extends StatelessWidget {
  const LastUpdatedChip({
    super.key,
    required this.fetchedAt,
    this.isStale = false,
  });

  final DateTime? fetchedAt;
  final bool isStale;

  @override
  Widget build(BuildContext context) {
    final at = fetchedAt;
    if (at == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    final age = DateTime.now().difference(at);
    final label = isStale
        ? t.cache_offline_chip(_relative(age, t))
        : t.cache_updated_chip(_relative(age, t));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(
            isStale ? Icons.cloud_off_outlined : Icons.history,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _relative(Duration age, AppLocalizations t) {
    if (age.inSeconds < 30) return t.cache_just_now;
    if (age.inMinutes < 1) {
      return t.cache_seconds_ago(age.inSeconds);
    }
    if (age.inMinutes < 60) {
      return t.cache_minutes_ago(age.inMinutes);
    }
    if (age.inHours < 24) {
      return t.cache_hours_ago(age.inHours);
    }
    return t.cache_days_ago(age.inDays);
  }
}
