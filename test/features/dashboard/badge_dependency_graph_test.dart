import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rayuela_mobile/features/dashboard/domain/entities/project_detail.dart';
import 'package:rayuela_mobile/features/dashboard/presentation/widgets/badge_dependency_graph.dart';
import 'package:rayuela_mobile/l10n/app_localizations.dart';

void main() {
  Widget host(List<ProjectBadge> badges) => MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: BadgeDependencyGraph(badges: badges),
          ),
        ),
      );

  testWidgets('shows the time left on the node itself, not just the tooltip',
      (tester) async {
    await tester.pumpWidget(
      host([
        const ProjectBadge(name: 'Root'),
        ProjectBadge(
          name: 'Fading',
          previousBadges: const ['Root'],
          status: 'faded',
          expiresAt: DateTime.now().add(const Duration(days: 3, hours: 1)),
        ),
      ]),
    );
    await tester.pump();

    // The graph is the default view: a countdown that only exists behind a
    // long-press is a countdown nobody sees.
    expect(find.text('3d'), findsOneWidget);
  });

  testWidgets('shows no countdown once the window has closed', (tester) async {
    await tester.pumpWidget(
      host([
        const ProjectBadge(name: 'Root'),
        ProjectBadge(
          name: 'Gone',
          previousBadges: const ['Root'],
          status: 'faded',
          // Elapsed while the payload sat in the offline cache.
          expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('d'), findsNothing);
  });

  testWidgets('leaves an ordinary catalog free of status chips',
      (tester) async {
    await tester.pumpWidget(
      host([
        const ProjectBadge(name: 'Root'),
        const ProjectBadge(name: 'Child', previousBadges: ['Root']),
      ]),
    );
    await tester.pump();

    expect(find.byType(Text), findsNothing);
  });
}
