import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/profile_avatar.dart';

/// Height of one avatar cell: 16 padding + 52 circle + 6 gap + two 11sp
/// lines (~28) + 4 border/slack. Pinned by avatar_picker_sheet_test.dart,
/// which fails on overflow if the contents ever outgrow it.
const double _cellHeight = 106;

/// Grid of the catalog roles. Pops the chosen `avatar:<id>` value.
class AvatarPickerSheet extends StatelessWidget {
  const AvatarPickerSheet({super.key, required this.selected});

  final String? selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.profile_avatar_picker_title,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              t.profile_avatar_picker_subtitle,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                // Width: wide enough that the longest single word
                // ("Guardabosques") isn't broken mid-word.
                // Height: fixed to what a cell actually holds — 8+8 padding,
                // a 52px circle, a 6px gap and two 11sp lines — instead of
                // being derived from the width, which left dead space.
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 140,
                  mainAxisExtent: _cellHeight,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 8,
                ),
                itemCount: ProfileAvatar.catalog.length,
                itemBuilder: (context, i) {
                  final avatar = ProfileAvatar.catalog[i];
                  final isSelected = avatar.storageValue == selected;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(context).pop(avatar.storageValue),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      // Top-aligned: a two-line label must not push the
                      // circle up out of line with its neighbours.
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: avatar.color,
                            child: Icon(
                              avatar.icon,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Flexible so a bumped-up system font size
                          // ellipsizes the label instead of overflowing the
                          // fixed-height cell.
                          Flexible(
                            child: Text(
                              avatar.label(t),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              // Slightly tighter than bodySmall so the
                              // longest single word ("Guardabosques") fits
                              // the cell instead of breaking mid-word.
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontSize: 11, height: 1.25),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
