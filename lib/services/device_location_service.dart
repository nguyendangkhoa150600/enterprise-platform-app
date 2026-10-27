import 'package:geolocator/geolocator.dart';

enum DeviceLocationStatus { ok, serviceDisabled, permissionDenied, permissionDeniedForever, failed }

class DeviceLocationFix {
  final DeviceLocationStatus status;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final DateTime? at;

  const DeviceLocationFix.failure(this.status)
      : latitude = null,
        longitude = null,
        accuracy = null,
        at = null;

  const DeviceLocationFix.ok({required double this.latitude, required double this.longitude, required double this.accuracy, required DateTime this.at})
      : status = DeviceLocationStatus.ok;

  bool get isOk => status == DeviceLocationStatus.ok;
}

/// Reads the real device position (the web portal does the same via navigator.geolocation).
class DeviceLocationService {
  static Future<DeviceLocationFix> getFix({bool requestPermission = true}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const DeviceLocationFix.failure(DeviceLocationStatus.serviceDisabled);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const DeviceLocationFix.failure(DeviceLocationStatus.permissionDeniedForever);
      }
      if (permission == LocationPermission.denied) {
        return const DeviceLocationFix.failure(DeviceLocationStatus.permissionDenied);
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, timeLimit: Duration(seconds: 15)),
      );
      return DeviceLocationFix.ok(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracy: pos.accuracy,
        at: DateTime.now(),
      );
    } catch (_) {
      return const DeviceLocationFix.failure(DeviceLocationStatus.failed);
    }
  }
}
