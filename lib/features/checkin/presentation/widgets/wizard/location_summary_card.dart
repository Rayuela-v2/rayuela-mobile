import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../../../l10n/app_localizations.dart';

class LocationSummaryCard extends StatelessWidget {
  const LocationSummaryCard({
    super.key,
    this.position,
    this.manualLatLng,
    required this.resolving,
    this.errorMessage,
    required this.onRetry,
    required this.onPickOnMap,
    required this.onClearManual,
  });

  final Position? position;
  final LatLng? manualLatLng;
  final bool resolving;
  final String? errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onPickOnMap;
  final VoidCallback onClearManual;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;

    if (resolving) {
      return _Card(
        background: Colors.white,
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(t.location_resolving),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return _Card(
        background: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: theme.colorScheme.error),
                const SizedBox(width: 12),
                Expanded(child: Text(errorMessage!)),
              ],
            ),
            TextButton(onPressed: onRetry, child: Text(t.location_btn_retry)),
          ],
        ),
      );
    }

    if (manualLatLng != null) {
      return _Card(
        background: Colors.white,
        child: Row(
          children: [
            const Icon(Icons.location_on, color: Color(0xFFC0392B), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t.location_pinned_manual,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF37474F)),
              ),
            ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5EDD6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF3A2810)),
              ),
              onPressed: onPickOnMap,
            ),
          ],
        ),
      );
    }

    return _Card(
      background: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Color(0xFFC0392B), size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "GPS activo",
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF37474F)),
            ),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5EDD6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF3A2810)),
            ),
            onPressed: onPickOnMap,
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.background});
  final Widget child;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background ?? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: child,
    );
  }
}
