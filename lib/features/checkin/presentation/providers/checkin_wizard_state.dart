import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

@immutable
class CheckinWizardState {
  const CheckinWizardState({
    required this.projectId,
    this.taskId,
    this.step = 0,
    this.taskType,
    this.availableTaskTypes = const [],
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
  final String? taskType;
  final List<String> availableTaskTypes;
  final List<XFile> images;
  final Position? position;
  final LatLng? manualLatLng;
  final bool resolvingLocation;
  final bool isSubmitting;
  final String? error;
  final DateTime? customDateTime;

  CheckinWizardState copyWith({
    String? projectId,
    String? taskId,
    int? step,
    String? taskType,
    List<String>? availableTaskTypes,
    List<XFile>? images,
    Position? position,
    LatLng? manualLatLng,
    bool? resolvingLocation,
    bool? isSubmitting,
    String? error,
    DateTime? customDateTime,
    bool clearCustomDateTime = false,
  }) {
    return CheckinWizardState(
      projectId: projectId ?? this.projectId,
      taskId: taskId ?? this.taskId,
      step: step ?? this.step,
      taskType: taskType ?? this.taskType,
      availableTaskTypes: availableTaskTypes ?? this.availableTaskTypes,
      images: images ?? this.images,
      position: position ?? this.position,
      manualLatLng: manualLatLng ?? this.manualLatLng,
      resolvingLocation: resolvingLocation ?? this.resolvingLocation,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error ?? this.error,
      customDateTime: clearCustomDateTime ? null : (customDateTime ?? this.customDateTime),
    );
  }
}
