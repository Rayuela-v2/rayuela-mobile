import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../dashboard/domain/entities/project_detail.dart';

@immutable
class CheckinWizardState {
  const CheckinWizardState({
    required this.projectId,
    this.taskId,
    this.step = 0,
    this.taskType,
    this.availableTaskTypes = const [],
    this.taskTypeLocked = false,
    this.images = const [],
    this.position,
    this.manualLatLng,
    this.resolvingLocation = false,
    this.isSubmitting = false,
    this.error,
    this.customDateTime,
  });

  final String projectId;
  final String? taskId;
  final int step;
  final TaskType? taskType;
  final List<TaskType> availableTaskTypes;

  /// True when the task type was preselected (e.g. deep-linked from the tasks
  /// list), so step 1's picker is skipped and excluded from the progress UI.
  final bool taskTypeLocked;

  final List<XFile> images;
  final Position? position;
  final LatLng? manualLatLng;
  final bool resolvingLocation;
  final bool isSubmitting;
  final String? error;
  final DateTime? customDateTime;

  /// First navigable [step] — step 1 (task type) is skipped when locked.
  int get firstStep => taskTypeLocked ? 1 : 0;

  /// Number of steps shown in the progress UI (the task-type step is hidden
  /// when [taskTypeLocked]).
  int get visibleStepCount => taskTypeLocked ? 3 : 4;

  /// Zero-based index of the current step among the visible ones.
  int get visibleStepIndex => step - firstStep;

  CheckinWizardState copyWith({
    String? projectId,
    String? taskId,
    int? step,
    TaskType? taskType,
    List<TaskType>? availableTaskTypes,
    bool? taskTypeLocked,
    List<XFile>? images,
    Position? position,
    LatLng? manualLatLng,
    bool? resolvingLocation,
    bool? isSubmitting,
    String? error,
    DateTime? customDateTime,
    bool clearCustomDateTime = false,
    bool clearManualLatLng = false,
    bool clearError = false,
  }) {
    return CheckinWizardState(
      projectId: projectId ?? this.projectId,
      taskId: taskId ?? this.taskId,
      step: step ?? this.step,
      taskType: taskType ?? this.taskType,
      availableTaskTypes: availableTaskTypes ?? this.availableTaskTypes,
      taskTypeLocked: taskTypeLocked ?? this.taskTypeLocked,
      images: images ?? this.images,
      position: position ?? this.position,
      manualLatLng: clearManualLatLng ? null : (manualLatLng ?? this.manualLatLng),
      resolvingLocation: resolvingLocation ?? this.resolvingLocation,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      customDateTime: clearCustomDateTime ? null : (customDateTime ?? this.customDateTime),
    );
  }
}
