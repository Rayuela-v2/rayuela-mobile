import 'package:flutter/material.dart';

import '../../domain/entities/project_detail.dart';

/// Makes a badge *look* like it is dissolving.
///
/// Two different motions, because the two states mean different things:
///
///   * [BadgeAvailability.fading] — the window is open and time is running
///     out, so the artwork breathes: it keeps sinking towards transparent
///     and coming back, never settling. Motion that never resolves is what
///     reads as "this is still happening, and it won't wait for you".
///   * [BadgeAvailability.expired] — it's over. Animating forever would be
///     noise about something already finished, so this plays once on
///     appearance: a slow dissolve that settles into a ghost and stops.
///
/// Active badges pass straight through untouched — no ticker, no rebuilds,
/// which matters because the grid can hold dozens of them.
class BadgeFadeEffect extends StatefulWidget {
  const BadgeFadeEffect({
    super.key,
    required this.availability,
    required this.child,
  });

  final BadgeAvailability availability;
  final Widget child;

  /// Where the dissolve comes to rest. Low enough to read as "going", high
  /// enough that the artwork is still identifiable — a badge you can't make
  /// out is a badge you can't miss.
  static const double _fadingFloor = 0.45;
  static const double _expiredRest = 0.35;

  @override
  State<BadgeFadeEffect> createState() => _BadgeFadeEffectState();
}

class _BadgeFadeEffectState extends State<BadgeFadeEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    // Slow on purpose. A quick blink reads as a glitch or a loading state;
    // a long breath reads as something draining away.
    duration: const Duration(milliseconds: 1900),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(BadgeFadeEffect old) {
    super.didUpdateWidget(old);
    if (old.availability != widget.availability) _sync();
  }

  /// Drives the controller to match the current state. Called on mount and
  /// whenever the badge crosses a lifecycle boundary — including a window
  /// that closes while the user is looking at it, which stops the breathing
  /// and plays the final dissolve.
  void _sync() {
    switch (widget.availability) {
      case BadgeAvailability.fading:
        _controller.repeat(reverse: true);
      case BadgeAvailability.expired:
        _controller
          ..duration = const Duration(milliseconds: 1100)
          ..forward(from: 0);
      case BadgeAvailability.active:
        _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.availability == BadgeAvailability.active) return widget.child;

    // Respect the OS "reduce motion" switch: people who turn it on often do
    // so because pulsing makes them ill. They still get the dimmed end state,
    // and the icon + label carry the meaning regardless.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return Opacity(
        opacity: widget.availability == BadgeAvailability.expired
            ? BadgeFadeEffect._expiredRest
            : BadgeFadeEffect._fadingFloor,
        child: widget.child,
      );
    }

    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    final opacity = widget.availability == BadgeAvailability.expired
        ? curve.drive(Tween(begin: 1.0, end: BadgeFadeEffect._expiredRest))
        : curve.drive(Tween(begin: 1.0, end: BadgeFadeEffect._fadingFloor));

    return FadeTransition(opacity: opacity, child: widget.child);
  }
}
