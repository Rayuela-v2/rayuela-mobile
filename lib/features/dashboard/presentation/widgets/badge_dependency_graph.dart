import 'dart:convert';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/project_detail.dart';

/// Sugiyama-style top-down DAG of badge dependencies. Mirrors the web app's
/// `BadgeDependencyGraph.vue` (custom SVG), drawn here with [CustomPaint]
/// for the edges and a [Stack] of [Positioned] avatars for the nodes.
///
/// Layout rules (kept consistent with `utils/badgeGraphLayout.js`):
///   * Each badge is placed on the layer **one below its deepest parent**.
///   * Roots (no `previousBadges`) sit on layer 0.
///   * Within a layer, nodes are evenly spaced and the layer is horizontally
///     centered.
///
/// Edges are quadratic Bézier curves with a subtle dashed style. Earned
/// badges get a green halo + checkmark; locked ones are desaturated. Tap a
/// node to surface its description in a snack bar (parent screen can opt in
/// to a heavier sheet by overriding [onBadgeTap]).
class BadgeDependencyGraph extends StatelessWidget {
  const BadgeDependencyGraph({
    super.key,
    required this.badges,
    this.onBadgeTap,
    this.nodeRadius = 30,
    this.layerGapY = 120,
    this.nodeGapX = 110,
    this.padding = 32,
  });

  final List<ProjectBadge> badges;
  final void Function(ProjectBadge)? onBadgeTap;

  final double nodeRadius;
  final double layerGapY;
  final double nodeGapX;
  final double padding;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    final layout = _BadgeGraphLayout.compute(
      badges: badges,
      nodeRadius: nodeRadius,
      layerGapY: layerGapY,
      nodeGapX: nodeGapX,
      padding: padding,
    );

    final theme = Theme.of(context);
    return SizedBox(
      width: layout.width,
      height: layout.height,
      child: Stack(
        children: [
          // Edges layer.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _EdgePainter(
                  edges: layout.edges,
                  nodeRadius: nodeRadius,
                  color: theme.colorScheme.outline.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
          // Node layer.
          for (final node in layout.nodes)
            Positioned(
              left: node.x - nodeRadius,
              top: node.y - nodeRadius,
              width: nodeRadius * 2,
              height: nodeRadius * 2,
              child: _BadgeNode(
                badge: node.badge,
                radius: nodeRadius,
                onTap: onBadgeTap == null
                    ? null
                    : () => onBadgeTap!(node.badge),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Layout
// ---------------------------------------------------------------------------

class _BadgeGraphLayout {
  _BadgeGraphLayout({
    required this.nodes,
    required this.edges,
    required this.width,
    required this.height,
  });

  final List<_BadgeNodePos> nodes;
  final List<_BadgeEdge> edges;
  final double width;
  final double height;

  static _BadgeGraphLayout compute({
    required List<ProjectBadge> badges,
    required double nodeRadius,
    required double layerGapY,
    required double nodeGapX,
    required double padding,
  }) {
    final byName = <String, ProjectBadge>{
      for (final b in badges) b.name: b,
    };

    // Depth = max(parent depth) + 1. Roots → 0. Cyclic / missing parents
    // are tolerated (treated as depth 0 to avoid infinite recursion).
    final depthCache = <String, int>{};
    final visiting = <String>{};

    int depthOf(ProjectBadge b) {
      final cached = depthCache[b.name];
      if (cached != null) return cached;
      if (visiting.contains(b.name)) return 0; // cycle guard.
      visiting.add(b.name);
      int max = 0;
      for (final p in b.previousBadges) {
        final parent = byName[p];
        if (parent == null) continue;
        final d = depthOf(parent) + 1;
        if (d > max) max = d;
      }
      visiting.remove(b.name);
      depthCache[b.name] = max;
      return max;
    }

    // Bucket by layer.
    final byLayer = <int, List<ProjectBadge>>{};
    int maxLayer = 0;
    for (final b in badges) {
      final d = depthOf(b);
      (byLayer[d] ??= []).add(b);
      if (d > maxLayer) maxLayer = d;
    }

    // Width = widest layer. Each slot is `nodeGapX` wide.
    final maxPerLayer = byLayer.values
        .map((l) => l.length)
        .fold<int>(0, math.max);
    final width = padding * 2 + math.max(1, maxPerLayer) * nodeGapX;
    final height = padding * 2 + (maxLayer + 1) * layerGapY;

    final nodes = <_BadgeNodePos>[];
    final byNamePos = <String, _BadgeNodePos>{};

    for (var layer = 0; layer <= maxLayer; layer++) {
      final layerBadges = byLayer[layer] ?? const <ProjectBadge>[];
      // Horizontally center the layer's nodes.
      final totalLayerWidth = layerBadges.length * nodeGapX;
      final startX = (width - totalLayerWidth) / 2 + nodeGapX / 2;
      final y = padding + layer * layerGapY + nodeRadius;
      for (var i = 0; i < layerBadges.length; i++) {
        final b = layerBadges[i];
        final pos = _BadgeNodePos(
          badge: b,
          x: startX + i * nodeGapX,
          y: y,
        );
        nodes.add(pos);
        byNamePos[b.name] = pos;
      }
    }

    // Edges: parent → child for each declared dependency that we can resolve.
    final edges = <_BadgeEdge>[];
    for (final b in badges) {
      final to = byNamePos[b.name];
      if (to == null) continue;
      for (final p in b.previousBadges) {
        final from = byNamePos[p];
        if (from == null) continue;
        edges.add(_BadgeEdge(from: from, to: to, earned: b.earned));
      }
    }

    return _BadgeGraphLayout(
      nodes: nodes,
      edges: edges,
      width: width,
      height: height,
    );
  }
}

class _BadgeNodePos {
  _BadgeNodePos({required this.badge, required this.x, required this.y});
  final ProjectBadge badge;
  final double x;
  final double y;
}

class _BadgeEdge {
  _BadgeEdge({required this.from, required this.to, required this.earned});
  final _BadgeNodePos from;
  final _BadgeNodePos to;
  final bool earned;
}

// ---------------------------------------------------------------------------
// Painting
// ---------------------------------------------------------------------------

/// Draws each edge as a quadratic Bézier (smooth top-down sweep) with a
/// small arrowhead near the child. Edges leading into earned badges get a
/// brighter, solid stroke; the rest stay dashed and muted.
class _EdgePainter extends CustomPainter {
  _EdgePainter({
    required this.edges,
    required this.nodeRadius,
    required this.color,
  });

  final List<_BadgeEdge> edges;
  final double nodeRadius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in edges) {
      final start = Offset(e.from.x, e.from.y + nodeRadius);
      final end = Offset(e.to.x, e.to.y - nodeRadius);
      final controlY = (start.dy + end.dy) / 2;
      final c1 = Offset(e.from.x, controlY);
      final c2 = Offset(e.to.x, controlY);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = e.earned
            ? const Color(0xFF4CAF50).withValues(alpha: 0.85)
            : color;

      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);

      if (e.earned) {
        canvas.drawPath(path, paint);
      } else {
        _drawDashed(canvas, path, paint, dash: 6, gap: 4);
      }

      _drawArrowhead(canvas, c2, end, paint..style = PaintingStyle.fill);
    }
  }

  void _drawDashed(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dash, metric.length);
        canvas.drawPath(
          metric.extractPath(distance, next),
          paint,
        );
        distance = next + gap;
      }
    }
  }

  void _drawArrowhead(Canvas canvas, Offset from, Offset tip, Paint paint) {
    const arrowSize = 7.0;
    final dir = tip - from;
    final len = dir.distance;
    if (len == 0) return;
    final unit = Offset(dir.dx / len, dir.dy / len);
    final perp = Offset(-unit.dy, unit.dx);
    final base = tip - unit * arrowSize;
    final p1 = base + perp * (arrowSize * 0.55);
    final p2 = base - perp * (arrowSize * 0.55);
    final triangle = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    canvas.drawPath(triangle, paint);
  }

  @override
  bool shouldRepaint(_EdgePainter old) =>
      old.edges != edges ||
      old.nodeRadius != nodeRadius ||
      old.color != color;
}

// ---------------------------------------------------------------------------
// Node
// ---------------------------------------------------------------------------

/// A single circular avatar in the graph. Earned badges glow green and show
/// a checkmark overlay; locked ones are desaturated.
class _BadgeNode extends StatelessWidget {
  const _BadgeNode({
    required this.badge,
    required this.radius,
    required this.onTap,
  });

  final ProjectBadge badge;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final earned = badge.earned;
    final ring = earned ? const Color(0xFF4CAF50) : theme.colorScheme.outline;

    return Tooltip(
      message: badge.description == null
          ? badge.name
          : '${badge.name} — ${badge.description!}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.surface,
            border: Border.all(color: ring, width: earned ? 3 : 2),
            boxShadow: earned
                ? [
                    BoxShadow(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.45),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipOval(
                child: _media(badge, radius, theme, earned: earned),
              ),
              if (!earned)
                // Subtle lock veil so depth still reads "not yet".
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.surface.withValues(alpha: 0.25),
                  ),
                ),
              if (earned)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF4CAF50),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              // Caption underneath isn't ideal inside the circle — show the
              // first letters as a fallback when there's no image.
            ],
          ),
        ),
      ),
    );
  }

  Widget _media(
    ProjectBadge badge,
    double radius,
    ThemeData theme, {
    required bool earned,
  }) {
    final url = badge.imageUrl;
    if (url == null || url.isEmpty) {
      return Container(
        color: theme.colorScheme.primaryContainer,
        alignment: Alignment.center,
        child: Icon(
          Icons.emoji_events_outlined,
          size: radius * 0.95,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      );
    }
    Widget image;

    if (url.startsWith('data:image/')) {
      try {
        final base64String = url.split(',').last;
        image = Image.memory(
          base64Decode(base64String),
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: theme.colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: Icon(
              Icons.broken_image_outlined,
              size: radius * 0.8,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        );
      } catch (e) {
        image = Container(
          color: theme.colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Icon(
            Icons.broken_image_outlined,
            size: radius * 0.8,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        );
      }
    } else {
      image = CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: radius * 2,
        height: radius * 2,
        placeholder: (_, __) => Container(
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        errorWidget: (_, __, ___) => Container(
          color: theme.colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Icon(
            Icons.broken_image_outlined,
            size: radius * 0.8,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (earned) return image;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0, 0, 0, 1, 0,
      ]),
      child: image,
    );
  }
}

