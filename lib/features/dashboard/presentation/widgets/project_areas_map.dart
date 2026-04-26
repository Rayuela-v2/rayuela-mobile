import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../checkin/domain/entities/checkin_history_item.dart';
import '../../../checkin/presentation/providers/checkin_providers.dart';
import '../../../tasks/domain/entities/task_item.dart';
import '../../../tasks/presentation/providers/tasks_providers.dart';
import '../../domain/entities/project_area.dart';

/// Project map mirrors `views/Admin/GeoMap.vue` from the web app, scaled
/// down for mobile. Renders the project's [areas] (GeoJSON polygons),
/// the user's check-ins, and the device location on top of OSM tiles.
///
/// Areas are colored by pending-task state (matches the web app's
/// `createAreaStyle`):
///   * blue fill + dark-blue border → at least one open task
///   * gray fill  + light-gray border → no open tasks (or no tasks at all)
///
/// Check-ins use the same glyphs as the web app:
///   * green ✓ → check-in was attached to a task (`contributesToTaskId`)
///   * red hollow circle → no contribution
///
/// User location is a lightblue dot. Resolved on first build and refreshed
/// only on user request — we don't poll, mobile would burn battery.
///
/// Tap an area → calls [onAreaTap] with the area name, so the parent can
/// navigate to a filtered Tasks screen.
class ProjectAreasMap extends ConsumerStatefulWidget {
  const ProjectAreasMap({
    super.key,
    required this.projectId,
    required this.areas,
    required this.onAreaTap,
    this.height = 280,
    this.isFullscreen = false,
  });

  final String projectId;
  final List<ProjectArea> areas;
  final void Function(String areaName) onAreaTap;
  final double height;
  final bool isFullscreen;

  @override
  ConsumerState<ProjectAreasMap> createState() => _ProjectAreasMapState();
}

class _ProjectAreasMapState extends ConsumerState<ProjectAreasMap> {
  final _mapController = MapController();
  LatLng? _userLocation;
  String? _selectedAreaId;
  bool _locationDenied = false;

  @override
  void initState() {
    super.initState();
    // Fire-and-forget: we don't want the map to block on permissions.
    // A successful resolve triggers a setState; a failure leaves the
    // user-location layer empty and shows the locate button as actionable.
    unawaited(_resolveLocation());
  }

  Future<void> _resolveLocation() async {
    try {
      final position =
          await ref.read(locationServiceProvider).currentPosition();
      if (!mounted) return;
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _locationDenied = false;
      });
    } catch (_) {
      // Permission denied or location service off — silent. The legend
      // explains why the dot is missing and the locate button stays
      // available so the user can grant access later.
      if (!mounted) return;
      setState(() => _locationDenied = true);
    }
  }

  Future<void> _recenterOnUser() async {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 16);
      return;
    }
    await _resolveLocation();
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 16);
    }
  }

  void _fitToAreas() {
    final bounds = _boundsFromAreas(widget.areas);
    if (bounds == null) return;
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(24),
        maxZoom: 17,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasksAsync = ref.watch(projectTasksProvider(widget.projectId));
    final checkinsAsync = ref.watch(userCheckinsProvider(widget.projectId));

    final tasks = tasksAsync.maybeWhen(
      data: (list) => list,
      orElse: () => const <TaskItem>[],
    );
    final checkins = checkinsAsync.maybeWhen(
      data: (list) => list,
      orElse: () => const <CheckinHistoryItem>[],
    );

    // Pending-task counts per area, used by the polygon styling AND the
    // tooltip banner. Tasks without an areaName are simply ignored — they
    // don't belong to any polygon.
    final pendingByArea = <String, int>{};
    final totalByArea = <String, int>{};
    for (final t in tasks) {
      final name = t.areaName;
      if (name == null || name.isEmpty) continue;
      totalByArea[name] = (totalByArea[name] ?? 0) + 1;
      if (!t.solved) {
        pendingByArea[name] = (pendingByArea[name] ?? 0) + 1;
      }
    }

    final initialBounds = _boundsFromAreas(widget.areas);
    final initialCenter = initialBounds?.center ?? const LatLng(40.4168, -3.7038);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: initialBounds == null ? 4 : 12,
                initialCameraFit: initialBounds == null
                    ? null
                    : CameraFit.bounds(
                        bounds: initialBounds,
                        padding: const EdgeInsets.all(24),
                        maxZoom: 17,
                      ),
                minZoom: 2,
                maxZoom: 19,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom |
                      InteractiveFlag.drag |
                      InteractiveFlag.doubleTapZoom |
                      InteractiveFlag.flingAnimation,
                ),
                onTap: (_, point) => _handleMapTap(point, pendingByArea),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.rayuela.mobile',
                ),
                PolygonLayer(
                  polygons: _buildPolygons(
                    theme: theme,
                    pendingByArea: pendingByArea,
                  ),
                ),
                MarkerLayer(
                  markers: _buildAreaLabels(theme),
                ),
                MarkerLayer(
                  markers: _buildCheckinMarkers(checkins),
                ),
                if (_userLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 22,
                        height: 22,
                        point: _userLocation!,
                        child: const _UserLocationDot(),
                      ),
                    ],
                  ),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Column(
                children: [
                  if (!widget.isFullscreen) ...[
                    _MapButton(
                      icon: Icons.fullscreen,
                      tooltip: 'Full screen',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            fullscreenDialog: true,
                            builder: (context) => Scaffold(
                              appBar: AppBar(
                                title: const Text('Map'),
                                leading: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ),
                              body: ProjectAreasMap(
                                projectId: widget.projectId,
                                areas: widget.areas,
                                onAreaTap: (areaName) {
                                  Navigator.of(context).pop();
                                  widget.onAreaTap(areaName);
                                },
                                height: double.infinity,
                                isFullscreen: true,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                  ],
                  _MapButton(
                    icon: Icons.my_location,
                    tooltip: _locationDenied
                        ? 'Location permission needed'
                        : 'Center on me',
                    onPressed: _recenterOnUser,
                  ),
                  const SizedBox(height: 6),
                  _MapButton(
                    icon: Icons.fit_screen_outlined,
                    tooltip: 'Fit to project areas',
                    onPressed:
                        widget.areas.isEmpty ? null : _fitToAreas,
                  ),
                ],
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              right: 8,
              child: _Legend(
                pendingByArea: pendingByArea,
                totalByArea: totalByArea,
                hasUserLocation: _userLocation != null,
              ),
            ),
            const Positioned(
              right: 6,
              bottom: 6,
              child: _Attribution(),
            ),
            if (_selectedAreaId != null)
              Positioned(
                top: 8,
                left: 8,
                child: _AreaInfoBanner(
                  areaId: _selectedAreaId!,
                  totalTasks: totalByArea[_selectedAreaId!] ?? 0,
                  pendingTasks: pendingByArea[_selectedAreaId!] ?? 0,
                  onOpen: () => widget.onAreaTap(_selectedAreaId!),
                  onClose: () => setState(() => _selectedAreaId = null),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleMapTap(LatLng point, Map<String, int> pendingByArea) {
    // Polygon hit-testing: walk the area list, find the first one that
    // contains the tapped point. flutter_map doesn't expose feature
    // picking, so we run our own ray-cast against each ring.
    for (final area in widget.areas) {
      for (final ring in area.rings) {
        if (_pointInRing(point, ring)) {
          setState(() => _selectedAreaId = area.id);
          return;
        }
      }
    }
    // Tap outside any polygon: dismiss the banner.
    if (_selectedAreaId != null) {
      setState(() => _selectedAreaId = null);
    }
  }

  // ---------------------------------------------------------------------
  // Layer builders
  // ---------------------------------------------------------------------

  List<Polygon> _buildPolygons({
    required ThemeData theme,
    required Map<String, int> pendingByArea,
  }) {
    // Web app colors (GeoMap.vue createAreaStyle):
    //   - has-pending  → fill rgba(0,0,255,0.3) + border #319FD3
    //   - no-pending   → fill rgba(128,128,128,.5) + border lightgray
    const pendingFill = Color(0x4D0000FF); // rgba(0,0,255,0.30) ≈ 77 alpha
    const pendingStroke = Color(0xFF319FD3);
    const idleFill = Color(0x80808080); // rgba(128,128,128,.5) ≈ 128 alpha
    const idleStroke = Color(0xFFCCCCCC); // "lightgray"

    final polygons = <Polygon>[];
    for (final area in widget.areas) {
      final hasPending = (pendingByArea[area.id] ?? 0) > 0;
      final isSelected = area.id == _selectedAreaId;
      for (final ring in area.rings) {
        polygons.add(
          Polygon(
            points: ring,
            color: hasPending ? pendingFill : idleFill,
            borderColor: isSelected
                ? theme.colorScheme.primary
                : (hasPending ? pendingStroke : idleStroke),
            borderStrokeWidth: isSelected ? 3 : 2,
          ),
        );
      }
    }
    return polygons;
  }

  List<Marker> _buildAreaLabels(ThemeData theme) {
    // Cheap label markers on each polygon's centroid — same as the web's
    // Text style on the area features. Helps the user discover the area
    // names without having to tap.
    final markers = <Marker>[];
    for (final area in widget.areas) {
      final centroid = area.centroid;
      if (centroid == null) continue;
      markers.add(
        Marker(
          width: 120,
          height: 24,
          point: centroid,
          child: IgnorePointer(
            child: _AreaLabel(name: area.id),
          ),
        ),
      );
    }
    return markers;
  }

  List<Marker> _buildCheckinMarkers(List<CheckinHistoryItem> checkins) {
    final markers = <Marker>[];
    for (final c in checkins) {
      if (!c.hasLocation) continue;
      final lat = double.tryParse(c.latitude ?? '');
      final lng = double.tryParse(c.longitude ?? '');
      if (lat == null || lng == null) continue;

      final hasContribution = c.solvesATask;
      markers.add(
        Marker(
          width: 26,
          height: 26,
          point: LatLng(lat, lng),
          child: hasContribution
              ? const _CheckinSuccessGlyph()
              : const _CheckinNoContribGlyph(),
        ),
      );
    }
    return markers;
  }
}

// -----------------------------------------------------------------------
// Geometry helpers
// -----------------------------------------------------------------------

/// Closed-ring point-in-polygon (ray casting). Good enough for the modest
/// admin-drawn polygons projects ship with — no need to drag in a CAD-
/// grade library.
bool _pointInRing(LatLng p, List<LatLng> ring) {
  if (ring.length < 3) return false;
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final yi = ring[i].latitude, xi = ring[i].longitude;
    final yj = ring[j].latitude, xj = ring[j].longitude;
    final intersect = ((yi > p.latitude) != (yj > p.latitude)) &&
        (p.longitude <
            (xj - xi) * (p.latitude - yi) / ((yj - yi) == 0 ? 1e-12 : (yj - yi)) +
                xi);
    if (intersect) inside = !inside;
  }
  return inside;
}

/// Computes the bounding LatLngBounds for a list of areas. Returns null
/// when there isn't enough data to draw a useful camera.
LatLngBounds? _boundsFromAreas(List<ProjectArea> areas) {
  double? minLat, minLng, maxLat, maxLng;
  for (final a in areas) {
    for (final ring in a.rings) {
      for (final p in ring) {
        minLat = (minLat == null || p.latitude < minLat) ? p.latitude : minLat;
        maxLat = (maxLat == null || p.latitude > maxLat) ? p.latitude : maxLat;
        minLng = (minLng == null || p.longitude < minLng) ? p.longitude : minLng;
        maxLng = (maxLng == null || p.longitude > maxLng) ? p.longitude : maxLng;
      }
    }
  }
  if (minLat == null || maxLat == null || minLng == null || maxLng == null) {
    return null;
  }
  // Zero-area projects still need a non-degenerate bounds; pad by a tiny
  // amount so the camera fit doesn't throw.
  if (minLat == maxLat && minLng == maxLng) {
    return LatLngBounds(
      LatLng(minLat - 0.001, minLng - 0.001),
      LatLng(maxLat + 0.001, maxLng + 0.001),
    );
  }
  return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
}

// -----------------------------------------------------------------------
// Sub-widgets
// -----------------------------------------------------------------------

class _UserLocationDot extends StatelessWidget {
  const _UserLocationDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFADD8E6), // "lightblue" — matches web
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

class _CheckinSuccessGlyph extends StatelessWidget {
  const _CheckinSuccessGlyph();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '✔',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2E7D32),
          shadows: [
            Shadow(color: Colors.white, blurRadius: 3),
            Shadow(color: Colors.white, blurRadius: 3),
          ],
        ),
      ),
    );
  }
}

class _CheckinNoContribGlyph extends StatelessWidget {
  const _CheckinNoContribGlyph();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
          border: Border.all(color: Colors.red, width: 2),
        ),
      ),
    );
  }
}

class _AreaLabel extends StatelessWidget {
  const _AreaLabel({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: Colors.black87, size: 20),
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.pendingByArea,
    required this.totalByArea,
    required this.hasUserLocation,
  });

  final Map<String, int> pendingByArea;
  final Map<String, int> totalByArea;
  final bool hasUserLocation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        children: [
          const _LegendChip(
            swatch: _SquareSwatch(
              fill: Color(0x4D0000FF),
              border: Color(0xFF319FD3),
            ),
            label: 'Has open tasks',
          ),
          const _LegendChip(
            swatch: _SquareSwatch(
              fill: Color(0x80808080),
              border: Color(0xFFCCCCCC),
            ),
            label: 'No open tasks',
          ),
          const _LegendChip(
            swatch: _GlyphSwatch(
              child: Text(
                '✔',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            label: 'Check-in solved a task',
          ),
          _LegendChip(
            swatch: _GlyphSwatch(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red, width: 2),
                ),
              ),
            ),
            label: 'Check-in (no task)',
          ),
          _LegendChip(
            swatch: const _DotSwatch(color: Color(0xFFADD8E6)),
            label: hasUserLocation ? 'You are here' : 'Your location',
          ),
        ]
            .map(
              (c) => DefaultTextStyle.merge(
                style: theme.textTheme.labelSmall ?? const TextStyle(),
                child: c,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.swatch, required this.label});
  final Widget swatch;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(width: 5),
        Text(label),
      ],
    );
  }
}

class _SquareSwatch extends StatelessWidget {
  const _SquareSwatch({required this.fill, required this.border});
  final Color fill;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 12,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: border, width: 2),
      ),
    );
  }
}

class _DotSwatch extends StatelessWidget {
  const _DotSwatch({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }
}

class _GlyphSwatch extends StatelessWidget {
  const _GlyphSwatch({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 16, height: 16, child: Center(child: child));
  }
}

class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        '© OpenStreetMap',
        style: TextStyle(fontSize: 10),
      ),
    );
  }
}

/// Tap-on-area summary banner. Shows "X open / Y total" and an "Open
/// tasks" CTA that navigates to the filtered Tasks screen. Mirrors the
/// web app's tooltip from `tasksForFeature`.
class _AreaInfoBanner extends StatelessWidget {
  const _AreaInfoBanner({
    required this.areaId,
    required this.totalTasks,
    required this.pendingTasks,
    required this.onOpen,
    required this.onClose,
  });

  final String areaId;
  final int totalTasks;
  final int pendingTasks;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final solved = totalTasks - pendingTasks;
    final summary = totalTasks == 0
        ? 'No tasks in this area'
        : pendingTasks == 0
            ? 'All $totalTasks tasks completed'
            : (solved == 0
                ? '$pendingTasks task${pendingTasks == 1 ? "" : "s"} pending'
                : '$pendingTasks pending · $solved done');

    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  areaId,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close, size: 16, color: Colors.black54),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            summary,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.black87),
          ),
          if (totalTasks > 0) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 30,
              child: FilledButton.tonalIcon(
                onPressed: onOpen,
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Open tasks'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                  textStyle: theme.textTheme.labelMedium,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

