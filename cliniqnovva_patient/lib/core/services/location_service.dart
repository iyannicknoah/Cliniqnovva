import 'package:geolocator/geolocator.dart';

/// Best-effort device location for "distance to clinic" (Part 20). Every
/// method here fails soft — a denied permission, disabled location service,
/// or platform error all just mean "no distance shown," never a crash or a
/// blocking prompt; Browse is fully usable without location.
abstract final class LocationService {
  static Future<Position?> getCurrentPositionIfPermitted() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
    } catch (_) {
      return null;
    }
  }

  static double distanceKm({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) {
    return Geolocator.distanceBetween(fromLat, fromLng, toLat, toLng) / 1000;
  }
}
