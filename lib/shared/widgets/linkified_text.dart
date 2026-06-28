import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// A widget that displays text with clickable links.
/// It parses both markdown-style links `[text](url)` and raw URLs,
/// rendering them as clickable hyperlinks that open in the system browser.
class LinkifiedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? linkStyle;

  const LinkifiedText({
    super.key,
    required this.text,
    this.style,
    this.linkStyle,
  });

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Clear and dispose old recognizers on build/rebuild
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    if (widget.text.isEmpty) {
      return const SizedBox.shrink();
    }

    final List<InlineSpan> spans = [];
    final regex = RegExp(
      r'\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)|(https?:\/\/[^\s()<>]+)',
    );

    int lastMatchEnd = 0;
    final matches = regex.allMatches(widget.text);

    final defaultLinkStyle = TextStyle(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
    );

    for (final match in matches) {
      // Add plain text before match
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: widget.text.substring(lastMatchEnd, match.start),
          style: widget.style,
        ),);
      }

      final url = match.group(2) ?? match.group(3);
      final displayText = match.group(1) ?? match.group(3);

      if (url != null && displayText != null) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () => _launchUrl(url);
        _recognizers.add(recognizer);

        spans.add(
          TextSpan(
            text: displayText,
            style: widget.linkStyle ?? defaultLinkStyle,
            recognizer: recognizer,
          ),
        );
      }

      lastMatchEnd = match.end;
    }

    // Add remaining plain text
    if (lastMatchEnd < widget.text.length) {
      spans.add(TextSpan(
        text: widget.text.substring(lastMatchEnd),
        style: widget.style,
      ),);
    }

    return Text.rich(
      TextSpan(children: spans),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.tryParse(urlString);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('Could not launch URL: $urlString. Error: $e');
      }
    }
  }
}
