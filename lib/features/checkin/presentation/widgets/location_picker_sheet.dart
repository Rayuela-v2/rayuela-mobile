import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../l10n/app_localizations.dart';

/// Modal map picker for overriding the auto-resolved GPS location of a
/// check-in. Mirrors the web app's `LocationPicker.vue` (OpenLayers there,
/// flutter_map + OSM here).
///
/// UX:
///   * Drop a pin by tapping anywhere on the map.
///   * "Use this location" returns the LatLng to the caller.
///   * Initial center is the auto-resolved GPS position when present.
///
/// Returns the chosen [LatLng] via Navigator.pop, or null if dismissed.
class LocationPickerSheet extends StatefulWidget {
  const LocationPickerSheet({
    super.key,
    this.initial,
  });

  final LatLng? initial;

  /// Convenience launcher. Shows the sheet at ~85% screen height.
  static Future<LatLng?> show(BuildContext context, {LatLng? initial}) {
    return showModalBottomSheet<LatLng>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: LocationPickerSheet(initial: initial),
        ),
      ),
    );
  }

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final _mapController = MapController();
  late LatLng _picked;

  @override
  void initState() {
    super.initState();
    // Madrid as a safe global default — better than (0,0).
    _picked = widget.initial ?? const LatLng(40.4168, -3.7038);
  }

  void _onTap(TapPosition _, LatLng latLng) {
    setState(() => _picked = latLng);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t.location_picker_title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: t.location_picker_recenter,
                icon: const Icon(Icons.my_location),
                onPressed: () {
                  if (widget.initial != null) {
                    _mapController.move(widget.initial!, 16);
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _picked,
                  initialZoom: widget.initial == null ? 6 : 16,
                  minZoom: 2,
                  maxZoom: 19,
                  onTap: _onTap,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom |
                        InteractiveFlag.drag |
                        InteractiveFlag.doubleTapZoom |
                        InteractiveFlag.flingAnimation,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.rayuela.mobile',
                    // OSM's tile policy asks us to identify ourselves; the
                    // package name above is the canonical channel.
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 44,
                        height: 44,
                        point: _picked,
                        alignment: Alignment.topCenter,
                        child: Icon(
                          Icons.location_on,
                          color: theme.colorScheme.primary,
                          size: 44,
                          shadows: const [
                            Shadow(
                              color: Colors.black54,
                              offset: Offset(0, 1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Tiny coordinate readout — handy when the user isn't sure
              // they tapped the right spot.
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Text(
                    '${_picked.latitude.toStringAsFixed(5)}, '
                    '${_picked.longitude.toStringAsFixed(5)}',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ),
              // Attribution — required by OSM's tile policy.
              Positioned(
                right: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2,),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '© OpenStreetMap',
                    style: TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(t.common_cancel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(_picked),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.check),
                  label: Text(t.location_picker_use_this),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
