import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rayuela_mobile/features/profile/domain/entities/profile_avatar.dart';
import 'package:rayuela_mobile/features/profile/presentation/widgets/avatar_picker_sheet.dart';
import 'package:rayuela_mobile/l10n/app_localizations.dart';

/// Narrow phone — the size where the labels are tightest.
const _phone = Size(360, 690);

Future<void> _pumpSheet(
  WidgetTester tester, {
  Locale? locale,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale ?? const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: const Scaffold(body: AvatarPickerSheet(selected: null)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows every catalog role', (tester) async {
    await _pumpSheet(tester);
    for (final avatar in ProfileAvatar.catalog) {
      expect(
        find.byIcon(avatar.icon),
        findsOneWidget,
        reason: 'missing ${avatar.id}',
      );
    }
  });

  testWidgets('circles stay aligned when a label wraps to two lines',
      (tester) async {
    await _pumpSheet(tester);

    // Cluster the circles into rows by proximity, then assert every circle
    // in a row shares an exact top edge. A centred Column would offset the
    // circle of a one-line label against its two-line neighbours by a few
    // pixels — the misalignment in the report — which lands inside the same
    // cluster and fails here.
    final tops = ProfileAvatar.catalog
        .map((a) => tester.getRect(find.byIcon(a.icon)).top)
        .toList()
      ..sort();
    final rows = <List<double>>[
      [tops.first],
    ];
    for (final top in tops.skip(1)) {
      if (top - rows.last.last < 40) {
        rows.last.add(top);
      } else {
        rows.add([top]);
      }
    }

    expect(rows.length, greaterThan(1), reason: 'expected a multi-row grid');
    expect(
      rows.any((r) => r.length > 1),
      isTrue,
      reason: 'expected at least one row with several avatars',
    );
    for (final row in rows) {
      expect(
        row.toSet(),
        hasLength(1),
        reason: 'circles in the same row must share a top edge, got $row',
      );
    }
  });

  testWidgets('cells stay wide enough for the longest label', (tester) async {
    await _pumpSheet(tester);
    // Line-count assertions are useless here: widget tests render with the
    // fixed-width test font, not Roboto, so every label "wraps". What we can
    // pin is the geometry that caused the mid-word break — cells getting too
    // narrow because the grid packed in another column.
    final cell = tester.getSize(
      find
          .ancestor(
            of: find.byIcon(ProfileAvatar.catalog.first.icon),
            matching: find.byType(InkWell),
          )
          .first,
    );
    expect(cell.width, greaterThanOrEqualTo(100));
    // The cell is only as tall as its contents — no dead space. If the
    // contents ever outgrow it the framework raises an overflow, which
    // fails every test in this file.
    expect(cell.height, lessThan(cell.width * 1.2));
  });

  testWidgets('survives a bumped-up system font size', (tester) async {
    // The cell height is fixed, so a large accessibility text scale must
    // ellipsize the label rather than overflow. Any overflow raises and
    // fails this test.
    await _pumpSheet(tester, textScale: 2.0);
    expect(find.byType(AvatarPickerSheet), findsOneWidget);
  });
}
