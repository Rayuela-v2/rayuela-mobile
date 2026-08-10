import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rayuela_mobile/features/dashboard/domain/entities/project_detail.dart';
import 'package:rayuela_mobile/features/dashboard/presentation/widgets/badge_fade_effect.dart';

void main() {
  Widget host(
    BadgeAvailability availability, {
    bool reduceMotion = false,
  }) =>
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: BadgeFadeEffect(
            availability: availability,
            child: const SizedBox(width: 10, height: 10),
          ),
        ),
      );

  double? opacityOf(WidgetTester tester) {
    final fade = tester.widgetList<FadeTransition>(find.byType(FadeTransition));
    if (fade.isEmpty) return null;
    return fade.first.opacity.value;
  }

  testWidgets('leaves an active badge completely alone', (tester) async {
    await tester.pumpWidget(host(BadgeAvailability.active));
    // No FadeTransition at all — no ticker running behind a grid of these.
    expect(find.byType(FadeTransition), findsNothing);
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('keeps a fading badge breathing without ever settling',
      (tester) async {
    await tester.pumpWidget(host(BadgeAvailability.fading));

    final start = opacityOf(tester)!;
    expect(start, 1.0);

    // Halfway through the breath: on its way down.
    await tester.pump(const Duration(milliseconds: 950));
    final mid = opacityOf(tester)!;
    expect(mid, lessThan(start));

    // Bottom of the breath, at the floor — dim but still legible.
    await tester.pump(const Duration(milliseconds: 950));
    expect(opacityOf(tester), closeTo(0.45, 0.01));

    // ...and back up again instead of resting there. The motion never
    // resolves, which is what reads as "still happening".
    await tester.pump(const Duration(milliseconds: 1500));
    expect(opacityOf(tester), greaterThan(mid));

    // Leave it mid-flight to prove dispose tears the ticker down cleanly;
    // a leak here fails the test with a pending-timer error.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('dissolves an expired badge once and then stops', (tester) async {
    await tester.pumpWidget(host(BadgeAvailability.expired));
    expect(opacityOf(tester), 1.0);

    await tester.pumpAndSettle();
    final rest = opacityOf(tester)!;
    expect(rest, closeTo(0.35, 0.01));

    // Settled for good — no second act.
    await tester.pump(const Duration(seconds: 3));
    expect(opacityOf(tester), rest);
  });

  testWidgets('plays the final dissolve when a window closes on screen',
      (tester) async {
    await tester.pumpWidget(host(BadgeAvailability.fading));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.pumpWidget(host(BadgeAvailability.expired));
    await tester.pumpAndSettle();
    expect(opacityOf(tester), closeTo(0.35, 0.01));
  });

  testWidgets('honours the OS reduce-motion switch', (tester) async {
    await tester.pumpWidget(
      host(BadgeAvailability.fading, reduceMotion: true),
    );
    // Dimmed end state, no animation to make anyone queasy.
    expect(find.byType(FadeTransition), findsNothing);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.45);

    await tester.pumpWidget(
      host(BadgeAvailability.expired, reduceMotion: true),
    );
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.35);
  });
}
