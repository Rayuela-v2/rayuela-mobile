import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/error/app_exception.dart';
import '../../../dashboard/domain/entities/project_detail.dart';
import '../../domain/entities/checkin_request.dart';
import '../../domain/entities/checkin_submission_outcome.dart';
import '../../domain/repositories/checkins_repository.dart';
import '../services/location_service.dart';
import 'checkin_providers.dart';
import 'checkin_wizard_state.dart';

class CheckinWizardController extends StateNotifier<CheckinWizardState> {
  CheckinWizardController({
    required CheckinsRepository repository,
    required LocationService locationService,
    required String projectId,
    String? taskId,
    String? initialTaskType,
    List<TaskType> availableTaskTypes = const [],
  })  : _repository = repository,
        _locationService = locationService,
        super(CheckinWizardState(
          projectId: projectId,
          taskId: taskId,
          // A preselected task type means the user already picked the task
          // (deep-link from the tasks list), so start past step 1 and lock it.
          step: initialTaskType != null ? 1 : 0,
          taskTypeLocked: initialTaskType != null,
          taskType: _resolveTaskType(initialTaskType, availableTaskTypes),
          availableTaskTypes:
              _resolveAvailableTaskTypes(initialTaskType, availableTaskTypes),
        ),);

  /// Resolves the preselected task type from the [initialTaskType] name,
  /// preferring the matching entry in [available] (which carries the
  /// description) and falling back to a name-only [TaskType].
  static TaskType? _resolveTaskType(
    String? initialTaskType,
    List<TaskType> available,
  ) {
    if (initialTaskType == null) return null;
    for (final t in available) {
      if (t.name == initialTaskType) return t;
    }
    return TaskType(name: initialTaskType);
  }

  /// The list backing step 1's picker. When the catalog is empty but a task
  /// type is preselected — e.g. deep-linked from the tasks list, which passes
  /// a `taskType` without the project's catalog — fall back to that single
  /// type so step 1 has something to show instead of the "no task types"
  /// empty state.
  static List<TaskType> _resolveAvailableTaskTypes(
    String? initialTaskType,
    List<TaskType> available,
  ) {
    if (available.isNotEmpty) return available;
    final resolved = _resolveTaskType(initialTaskType, available);
    return resolved == null ? const [] : [resolved];
  }

  final CheckinsRepository _repository;
  final LocationService _locationService;
  final _picker = ImagePicker();

  Future<void> initLocation() async {
    if (state.resolvingLocation) return;
    state = state.copyWith(resolvingLocation: true, clearError: true);
    try {
      final position = await _locationService.currentPosition();
      state = state.copyWith(
        position: position,
        resolvingLocation: false,
      );
    } catch (e) {
      state = state.copyWith(
        resolvingLocation: false,
        error: e is AppException ? e.message : e.toString(),
      );
    }
  }

  void nextStep() {
    state = state.copyWith(step: state.step + 1);
  }

  void previousStep() {
    if (state.step > state.firstStep) {
      state = state.copyWith(step: state.step - 1);
    }
  }

  void setTaskType(TaskType type) {
    state = state.copyWith(taskType: type);
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final shot = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
          maxWidth: 1920,
        );
        if (shot != null) {
          state = state.copyWith(images: [...state.images, shot]);
        }
      } else {
        final remaining = 3 - state.images.length;
        if (remaining <= 0) return;
        final picked = await _picker.pickMultiImage(
          imageQuality: 80,
          maxWidth: 1920,
          limit: remaining,
        );
        state = state.copyWith(
          images: [...state.images, ...picked.take(remaining)],
        );
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void removeImage(int index) {
    final newImages = List<XFile>.from(state.images)..removeAt(index);
    state = state.copyWith(images: newImages);
  }

  void setManualLocation(LatLng latLng) {
    state = state.copyWith(
      manualLatLng: latLng,
      clearError: true,
    );
  }

  void clearManualLocation() {
    state = state.copyWith(clearManualLatLng: true);
  }

  void setCustomDateTime(DateTime dateTime) {
    if (dateTime.isAfter(DateTime.now())) {
      state = state.copyWith(
        error: "wizard_error_future_date",
      );
      return;
    }
    state = state.copyWith(
      customDateTime: dateTime,
      clearError: true,
    );
  }

  void clearCustomDateTime() {
    state = state.copyWith(clearCustomDateTime: true);
  }

  Future<CheckinSubmissionOutcome?> submit() async {
    if (state.isSubmitting) return null;

    final taskType = state.taskType;
    if (taskType == null) {
      state = state.copyWith(error: "wizard_error_select_type");
      return null;
    }

    LatLng? coords;
    if (state.manualLatLng != null) {
      coords = state.manualLatLng;
    } else if (state.position != null) {
      coords = LatLng(state.position!.latitude, state.position!.longitude);
    }

    if (coords == null) {
      state = state.copyWith(error: "wizard_error_waiting_location");
      return null;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
    );

    debugPrint("[Wizard] Starting submission for project ${state.projectId}...");
    try {
      final request = CheckinRequest(
        projectId: state.projectId,
        taskType: taskType.name,
        taskId: state.taskId,
        latitude: coords.latitude.toString(),
        longitude: coords.longitude.toString(),
        datetime: state.customDateTime ?? DateTime.now(),
        imagePaths: state.images.map((x) => x.path).toList(growable: false),
      );
      
      debugPrint("[Wizard] Calling repository.submitCheckin...");
      final result = await _repository.submitCheckin(request);
      debugPrint("[Wizard] Repository returned result: ${result.isSuccess ? 'Success' : 'Failure'}");

      return result.fold(
        onSuccess: (outcome) {
          debugPrint("[Wizard] Submission successful: $outcome");
          state = state.copyWith(isSubmitting: false);
          return outcome;
        },
        onFailure: (appError) {
          debugPrint("[Wizard] Submission failed: ${appError.message}");
          state = state.copyWith(
            isSubmitting: false,
            error: appError.message,
          );
          return null;
        },
      );
    } catch (e, stack) {
      debugPrint("[Wizard] FATAL ERROR during submission: $e");
      debugPrint(stack.toString());
      state = state.copyWith(
        isSubmitting: false,
        error: "Error inesperado: ${e.toString()}",
      );
      return null;
    }
  }
}

class CheckinWizardArgs {
  const CheckinWizardArgs({
    required this.projectId,
    this.taskId,
    this.initialTaskType,
    this.availableTaskTypes = const [],
  });

  final String projectId;
  final String? taskId;
  final String? initialTaskType;
  final List<TaskType> availableTaskTypes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CheckinWizardArgs &&
          runtimeType == other.runtimeType &&
          projectId == other.projectId &&
          taskId == other.taskId &&
          initialTaskType == other.initialTaskType &&
          listEquals(availableTaskTypes, other.availableTaskTypes);

  @override
  int get hashCode =>
      projectId.hashCode ^
      taskId.hashCode ^
      initialTaskType.hashCode ^
      availableTaskTypes.hashCode;
}

final checkinWizardProvider = StateNotifierProvider.autoDispose.family<
    CheckinWizardController, CheckinWizardState, CheckinWizardArgs>((ref, args) {
  return CheckinWizardController(
    repository: ref.watch(checkinsRepositoryProvider),
    locationService: ref.watch(locationServiceProvider),
    projectId: args.projectId,
    taskId: args.taskId,
    initialTaskType: args.initialTaskType,
    availableTaskTypes: args.availableTaskTypes,
  );
});
