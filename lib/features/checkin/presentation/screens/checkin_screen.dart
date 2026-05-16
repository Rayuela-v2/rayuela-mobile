import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/result.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/sync/connectivity_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../domain/entities/checkin_request.dart';
import '../../domain/entities/checkin_submission_outcome.dart';
import '../providers/checkin_providers.dart';
import '../widgets/location_picker_sheet.dart';

const int _maxImages = 3;

/// Capture screen for a check-in: photos + GPS + optional notes, then
/// submit. We push the user to [CheckinResultScreen] on success.
///
/// Two entry points:
///   * Tasks list → opens with [taskType] pre-set (and [taskName]/[taskId]
///     for the result screen).
///   * Project detail "Add a check-in" → opens with [taskType] null and
///     [availableTaskTypes] populated; the user picks from a chip group.
class CheckinScreen extends ConsumerStatefulWidget {
  const CheckinScreen({
    super.key,
    required this.projectId,
    this.taskType,
    this.availableTaskTypes = const [],
    this.taskName,
    this.taskId,
    this.projectName,
  });

  final String projectId;

  /// Pre-selected when the user arrived from a specific task. Null when
  /// opened generically — the screen renders a picker.
  final String? taskType;

  /// Catalog of task types this project supports. Used to populate the
  /// picker. May be empty (older projects, or when navigated to without
  /// the project's task-type list).
  final List<String> availableTaskTypes;

  final String? taskName;
  final String? taskId;
  final String? projectName;

  @override
  ConsumerState<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends ConsumerState<CheckinScreen> {
  final _picker = ImagePicker();
  final _notesController = TextEditingController();
  final _customTaskTypeController = TextEditingController();
  final List<XFile> _images = [];

  /// Currently-selected taskType. Seeded from widget.taskType if provided.
  String? _taskType;

  Position? _position;
  bool _resolvingLocation = false;
  String? _locationError;

  /// User override placed via [LocationPickerSheet]. When non-null this
  /// takes precedence over [_position] for the submission payload.
  LatLng? _manualLatLng;

  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _taskType = widget.taskType;
    // Kick off location resolution as soon as the screen opens — by the time
    // the user has their photos, the GPS reading is usually already in.
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveLocation());
  }

  @override
  void dispose() {
    _notesController.dispose();
    _customTaskTypeController.dispose();
    super.dispose();
  }

  Future<void> _resolveLocation() async {
    if (_resolvingLocation) return;
    final t = AppLocalizations.of(context)!;
    setState(() {
      _resolvingLocation = true;
      _locationError = null;
    });
    try {
      final pos = await ref.read(locationServiceProvider).currentPosition();
      if (!mounted) return;
      setState(() {
        _position = pos;
        _resolvingLocation = false;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _resolvingLocation = false;
        _locationError = localizeAppException(e, t);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resolvingLocation = false;
        _locationError = t.location_unknown_error;
      });
    }
  }

  Future<void> _pickFromCamera() async {
    final t = AppLocalizations.of(context)!;
    if (_images.length >= _maxImages) return;
    try {
      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
      );
      if (shot != null && mounted) {
        setState(() => _images.add(shot));
      }
    } catch (e) {
      _toast(t.checkin_camera_error(e.toString()));
    }
  }

  Future<void> _pickFromGallery() async {
    final t = AppLocalizations.of(context)!;
    final remaining = _maxImages - _images.length;
    if (remaining <= 0) return;
    try {
      final picked = await _picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1920,
        limit: remaining,
      );
      if (picked.isEmpty || !mounted) return;
      setState(() {
        _images.addAll(picked.take(remaining));
      });
    } catch (e) {
      _toast(t.checkin_gallery_error(e.toString()));
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Effective task type for submission. Combines an explicit selection
  /// with the free-text fallback (used when the project has no catalog).
  String? get _effectiveTaskType {
    if (_taskType != null && _taskType!.isNotEmpty) return _taskType;
    final custom = _customTaskTypeController.text.trim();
    return custom.isEmpty ? null : custom;
  }

  /// Coordinates to submit. Manual override > GPS reading.
  LatLng? get _effectiveLatLng {
    if (_manualLatLng != null) return _manualLatLng;
    final p = _position;
    if (p == null) return null;
    return LatLng(p.latitude, p.longitude);
  }

  Future<void> _pickLocationOnMap() async {
    final initial = _effectiveLatLng;
    final picked = await LocationPickerSheet.show(context, initial: initial);
    if (!mounted || picked == null) return;
    setState(() {
      _manualLatLng = picked;
      // If we'd surfaced an error trying to resolve GPS, clear it — the
      // user has handed us coordinates by hand.
      _locationError = null;
      _submitError = null;
    });
  }

  void _clearManualLocation() {
    setState(() {
      _manualLatLng = null;
      _submitError = null;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final t = AppLocalizations.of(context)!;
    final taskType = _effectiveTaskType;
    if (taskType == null) {
      setState(() => _submitError = t.checkin_validation_pick_kind);
      return;
    }
    if (_images.isEmpty) {
      setState(() => _submitError = t.checkin_validation_add_photo);
      return;
    }
    final coords = _effectiveLatLng;
    if (coords == null) {
      setState(() => _submitError = t.checkin_validation_waiting_location);
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    final repo = ref.read(checkinsRepositoryProvider);
    final result = await repo.submitCheckin(
      CheckinRequest(
        projectId: widget.projectId,
        taskType: taskType,
        taskId: widget.taskId,
        latitude: coords.latitude.toString(),
        longitude: coords.longitude.toString(),
        datetime: DateTime.now(),
        imagePaths: _images.map((x) => x.path).toList(growable: false),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      ),
    );

    if (!mounted) return;

    switch (result) {
      case Success<CheckinSubmissionOutcome>(:final value):
        switch (value) {
          case CheckinSubmissionAccepted() || CheckinSubmissionQueued():
            // Either way the user's "My check-ins" list should refresh —
            // pending entries appear inline in the same view as accepted
            // ones (Sprint C will surface them).
            ref.invalidate(userCheckinsProvider(widget.projectId));
            // Replace the form so "back" returns to the project detail
            // rather than the stale form.
            context.pushReplacementNamed(
              AppRoute.checkinResult,
              pathParameters: {'projectId': widget.projectId},
              extra: value,
            );
          case CheckinSubmissionRejected(:final error):
            setState(() {
              _submitting = false;
              _submitError = localizeAppException(error, t);
            });
        }
      case Failure<CheckinSubmissionOutcome>(:final error):
        setState(() {
          _submitting = false;
          _submitError = localizeAppException(error, t);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    final canSubmit = !_submitting &&
        _images.isNotEmpty &&
        _effectiveLatLng != null &&
        _effectiveTaskType != null;

    // Reachability is read live so the offline chip appears/disappears
    // as the user moves in and out of coverage while filling the form.
    // We watch the service rather than its stream so we still get a
    // value before the first stream tick.
    final reachability = ref.watch(connectivityServiceProvider).current;
    final showOfflineChip = reachability != NetworkReachability.online;

    // Don't show the picker if we already arrived with an explicit
    // taskType (came from the Tasks list — the chosen task is the source
    // of truth). Otherwise let the user pick.
    final showPicker = widget.taskType == null || widget.taskType!.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.taskName ??
            widget.projectName ??
            t.checkin_screen_title_default,),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (showPicker) ...[
              _SectionLabel(label: t.checkin_section_kind),
              const SizedBox(height: 8),
              _TaskTypePicker(
                options: widget.availableTaskTypes,
                selected: _taskType,
                customController: _customTaskTypeController,
                onSelect: (v) => setState(() {
                  _taskType = v;
                  if (v != null) _customTaskTypeController.clear();
                  _submitError = null;
                }),
                onCustomChanged: () => setState(() {
                  if (_customTaskTypeController.text.isNotEmpty) {
                    _taskType = null; // free-text takes over.
                  }
                }),
              ),
              const SizedBox(height: 24),
            ],
            _SectionLabel(
              label: t.checkin_section_photos(_images.length, _maxImages),
            ),
            const SizedBox(height: 8),
            _PhotoGrid(
              images: _images,
              onRemove: (i) => setState(() => _images.removeAt(i)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _images.length >= _maxImages
                        ? null
                        : _pickFromCamera,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(t.checkin_btn_camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _images.length >= _maxImages
                        ? null
                        : _pickFromGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(t.checkin_btn_gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SectionLabel(label: t.checkin_section_location),
            const SizedBox(height: 8),
            _LocationCard(
              position: _position,
              manualLatLng: _manualLatLng,
              resolving: _resolvingLocation,
              errorMessage: _locationError,
              onRetry: _resolveLocation,
              onPickOnMap: _pickLocationOnMap,
              onClearManual: _clearManualLocation,
            ),
            const SizedBox(height: 24),
            _SectionLabel(label: t.checkin_section_notes),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              minLines: 3,
              maxLines: 6,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: t.checkin_notes_hint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (showOfflineChip) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10,),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer
                      .withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 18,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t.checkin_offline_chip,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (_submitError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _submitError!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            FilledButton(
              onPressed: canSubmit ? _submit : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _submitting
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(t.checkin_btn_submit),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label.toUpperCase(),
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.images, required this.onRemove});

  final List<XFile> images;
  final void Function(int) onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    if (images.isEmpty) {
      return Container(
        height: 96,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          t.checkin_photos_hint(_maxImages),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(images[i].path),
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => onRemove(i),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.position,
    required this.manualLatLng,
    required this.resolving,
    required this.errorMessage,
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

    // Manual override always wins — render a distinct "pinned by you" card.
    if (manualLatLng != null) {
      final m = manualLatLng!;
      return _Card(
        background: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
        child: Row(
          children: [
            Icon(Icons.push_pin, color: theme.colorScheme.tertiary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${m.latitude.toStringAsFixed(5)}, '
                    '${m.longitude.toStringAsFixed(5)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    t.location_pinned_manual,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: t.location_btn_edit_on_map,
              icon: const Icon(Icons.edit_location_alt_outlined),
              onPressed: onPickOnMap,
            ),
            IconButton(
              tooltip: t.location_btn_use_gps_instead,
              icon: const Icon(Icons.gps_fixed),
              onPressed: onClearManual,
            ),
          ],
        ),
      );
    }

    if (resolving) {
      return _Card(
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t.location_resolving,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            TextButton.icon(
              onPressed: onPickOnMap,
              icon: const Icon(Icons.map_outlined, size: 18),
              label: Text(t.location_btn_pick_on_map),
            ),
          ],
        ),
      );
    }
    if (errorMessage != null) {
      return _Card(
        background: theme.colorScheme.errorContainer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.location_off_outlined,
                    color: theme.colorScheme.onErrorContainer,),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    errorMessage!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onPickOnMap,
                  child: Text(t.location_btn_pick_on_map),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onRetry,
                  child: Text(t.location_btn_retry),
                ),
              ],
            ),
          ],
        ),
      );
    }
    if (position == null) {
      return _Card(
        child: Row(
          children: [
            const Icon(Icons.location_searching),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                t.location_unavailable,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            TextButton(
              onPressed: onPickOnMap,
              child: Text(t.location_btn_pick_on_map),
            ),
            TextButton(
              onPressed: onRetry,
              child: Text(t.location_btn_locate),
            ),
          ],
        ),
      );
    }
    return _Card(
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${position!.latitude.toStringAsFixed(5)}, '
                  '${position!.longitude.toStringAsFixed(5)}',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  t.location_accuracy(position!.accuracy.toStringAsFixed(0)),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: t.location_btn_pick_on_map,
            icon: const Icon(Icons.map_outlined),
            onPressed: onPickOnMap,
          ),
          IconButton(
            tooltip: t.location_btn_refresh_gps,
            icon: const Icon(Icons.refresh),
            onPressed: onRetry,
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
        color: background ??
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

/// Chip group + free-text fallback. The project's `taskTypes` catalog is
/// the primary source of options; if it's empty we just show a text field.
class _TaskTypePicker extends StatelessWidget {
  const _TaskTypePicker({
    required this.options,
    required this.selected,
    required this.customController,
    required this.onSelect,
    required this.onCustomChanged,
  });

  final List<String> options;
  final String? selected;
  final TextEditingController customController;
  final ValueChanged<String?> onSelect;
  final VoidCallback onCustomChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    if (options.isEmpty) {
      // Free-text fallback. Backwards-compat with projects that don't yet
      // ship a taskTypes catalog.
      return TextField(
        controller: customController,
        onChanged: (_) => onCustomChanged(),
        decoration: InputDecoration(
          hintText: t.checkin_picker_freetext_hint,
          border: const OutlineInputBorder(),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final type in options)
          ChoiceChip(
            label: Text(type),
            selected: selected == type,
            onSelected: (v) => onSelect(v ? type : null),
            selectedColor: theme.colorScheme.primaryContainer,
            labelStyle: theme.textTheme.bodyMedium?.copyWith(
              color: selected == type
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurface,
              fontWeight:
                  selected == type ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
      ],
    );
  }
}
