import 'package:geolocator/geolocator.dart';

import '../../../../core/error/app_exception.dart';

/// Thin wrapper around Geolocator that translates platform errors and
/// permission states into our typed [AppException] hierarchy. UI code
/// never sees Geolocator types.
class LocationService {
  const LocationService();

  /// Resolves the device's current position. Throws an [AppException]
  /// subclass if location is disabled or permission is denied.
  Future<Position> currentPosition() async {
    final servicesEnabled = await Geolocator.isLocationServiceEnabled();
    if (!servicesEnabled) {
      throw const LocationDisabledException();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    switch (permission) {
      case LocationPermission.denied:
        throw const LocationDeniedException();
      case LocationPermission.deniedForever:
        throw const LocationDeniedForeverException();
      case LocationPermission.always:
      case LocationPermission.whileInUse:
      case LocationPermission.unableToDetermine:
        // Proceed; if we can't determine, the actual call will surface it.
        break;
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }
}

/// Thrown when device location services are turned off entirely.
/// The UI translates this via [localizeAppException]; the [message] field
/// keeps an English fallback for non-UI consumers (logs, crash reports).
class LocationDisabledException extends ForbiddenException {
  const LocationDisabledException()
      : super(
          message:
              'Location services are turned off. Enable them to check in.',
        );
}

/// Thrown when the user denied the location permission this run.
class LocationDeniedException extends ForbiddenException {
  const LocationDeniedException()
      : super(
          message:
              'Location permission is required to attach your check-in to '
              'the project area.',
        );
}

/// Thrown when the user denied location permission permanently — the OS
/// won't re-prompt; they have to flip the toggle in Settings.
class LocationDeniedForeverException extends ForbiddenException {
  const LocationDeniedForeverException()
      : super(
          message:
              'Location is permanently denied. Open Settings to grant '
              'access and try again.',
        );
}
