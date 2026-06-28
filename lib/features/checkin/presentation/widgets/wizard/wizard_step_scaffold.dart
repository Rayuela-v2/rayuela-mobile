import 'package:flutter/material.dart';

/// Shared layout for the check-in wizard steps.
///
/// Keeps [footer] (the action button bar) pinned to the bottom and always
/// visible, while [content] scrolls when it doesn't fit the available height.
/// This avoids the footer being pushed off-screen on short viewports or when
/// the keyboard is open.
class WizardStepScaffold extends StatelessWidget {
  const WizardStepScaffold({
    super.key,
    required this.content,
    required this.footer,
  });

  /// Scrollable body, laid out top-to-bottom. Must not contain its own
  /// vertically-unbounded scrollable (e.g. a plain [ListView]/[GridView]).
  final List<Widget> content;

  /// Pinned bottom bar — typically a [WizardFooter] wrapping the step's
  /// primary button.
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: content,
            ),
          ),
        ),
        footer,
      ],
    );
  }
}

/// The dark-green rounded bar that hosts a wizard step's action button(s).
class WizardFooter extends StatelessWidget {
  const WizardFooter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E3A2F),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: child,
    );
  }
}
