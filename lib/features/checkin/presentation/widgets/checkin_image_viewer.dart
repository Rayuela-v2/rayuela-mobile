import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../utils/checkin_image_url.dart';

/// Full-screen image viewer for a check-in's photo strip. Pinch-to-zoom,
/// horizontal paging, tap to dismiss. Lifted into its own page route so it
/// gets a real back stack entry on iOS.
class CheckinImageViewer extends StatefulWidget {
  const CheckinImageViewer({
    super.key,
    required this.imageRefs,
    this.initialIndex = 0,
  });

  final List<String> imageRefs;
  final int initialIndex;

  static Future<void> push(
    BuildContext context, {
    required List<String> imageRefs,
    int initialIndex = 0,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => CheckinImageViewer(
          imageRefs: imageRefs,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  State<CheckinImageViewer> createState() => _CheckinImageViewerState();
}

class _CheckinImageViewerState extends State<CheckinImageViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.imageRefs.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final total = widget.imageRefs.length;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.4),
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          total > 1
              ? t.image_viewer_paged(_index + 1, total)
              : t.image_viewer_single,
        ),
      ),
      body: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: PageView.builder(
          controller: _controller,
          itemCount: total,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) {
            final url = resolveCheckinImageUrl(widget.imageRefs[i]);
            return InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                    child: CircularProgressIndicator(color: Colors.white70),
                  ),
                  errorWidget: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white70,
                    size: 64,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
