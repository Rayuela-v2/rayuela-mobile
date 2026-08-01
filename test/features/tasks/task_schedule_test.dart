import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rayuela_mobile/features/tasks/domain/entities/task_item.dart';
import 'package:rayuela_mobile/features/tasks/presentation/widgets/task_detail_sheet.dart';
import 'package:rayuela_mobile/l10n/app_localizations.dart';

/// Captures [taskScheduleShort]'s output under an English MaterialApp (so
/// MaterialLocalizations.narrowWeekdays is available).
Future<String?> _format(WidgetTester tester, TaskTimeInterval? interval) async {
  String? result;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          result = taskScheduleShort(context, interval);
          return const SizedBox();
        },
      ),
    ),
  );
  return result;
}

void main() {
  testWidgets('maps ISO weekdays to narrow letters and joins the hour range',
      (tester) async {
    final out = await _format(
      tester,
      const TaskTimeInterval(
        name: 'Weekday shift',
        days: [1, 3, 5], // Mon, Wed, Fri
        startTime: '09:00',
        endTime: '17:00',
      ),
    );
    // English narrowWeekdays is Sunday-first: [S,M,T,W,T,F,S].
    // ISO 1,3,5 → indices 1,3,5 → M,W,F.
    expect(out, 'M·W·F  09:00–17:00');
  });

  testWidgets('collapses a full week to "Every day"', (tester) async {
    final out = await _format(
      tester,
      const TaskTimeInterval(
        name: '',
        days: [1, 2, 3, 4, 5, 6, 7],
        startTime: '',
        endTime: '',
      ),
    );
    expect(out, 'Every day');
  });

  testWidgets('returns null when there is no interval', (tester) async {
    expect(await _format(tester, null), isNull);
  });
}
