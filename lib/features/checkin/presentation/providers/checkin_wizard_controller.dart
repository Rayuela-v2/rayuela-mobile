import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

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
    List<String> availableTaskTypes = const [],
  })  : _repository = repository,
        _locationService = locationService,
        super(CheckinWizardState(
          projectId: projectId,
          taskId: taskId,
          taskType: initialTaskType,
          availableTaskTypes: availableTaskTypes,
        )) {
    initLocation();
  }

  final CheckinsRepository _repository;
  final LocationService _locationService;
  final _picker = ImagePicker();

  Future<void> initLocation() async {
    if (state.resolvingLocation) return;
    state = state.copyWith(resolvingLocation: true, error: null);
    try {
      final position = await _locationService.currentPosition();
      state = state.copyWith(
        position: position,
        resolvingLocation: false,
      );
    } catch (e) {
      state = state.copyWith(resolvingLocation: false);
    }
  }

  void nextStep() {
    state = state.copyWith(step: state.step + 1);
  }

  void previousStep() {
    if (state.step > 0) {
      state = state.copyWith(step: state.step - 1);
    }
  }

  void setTaskType(String type) {
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
      error: null,
    );
  }

  void clearManualLocation() {
    state = state.copyWith(manualLatLng: null);
  }

  void setCustomDateTime(DateTime dateTime) {
    state = state.copyWith(
      customDateTime: dateTime,
      error: null,
    );
  }

  void clearCustomDateTime() {
    state = state.copyWith(clearCustomDateTime: true);
  }

  Future<CheckinSubmissionOutcome?> submit() async {
    if (state.isSubmitting) return null;

    final taskType = state.taskType;
    if (taskType == null) {
      state = state.copyWith(error: "Elegí qué tipo de check-in es.");
      return null;
    }

    LatLng? coords;
    if (state.manualLatLng != null) {
      coords = state.manualLatLng;
    } else if (state.position != null) {
      coords = LatLng(state.position!.latitude, state.position!.longitude);
    }

    if (coords == null) {
      state = state.copyWith(error: "Esperando tu ubicación.");
      return null;
    }

    state = state.copyWith(
      isSubmitting: true,
      error: null,
    );

    debugPrint("[Wizard] Starting submission for project ${state.projectId}...");
    try {
      final request = CheckinRequest(
        projectId: state.projectId,
        taskType: taskType,
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
  final List<String> availableTaskTypes;

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
