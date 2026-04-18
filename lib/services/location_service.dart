import 'package:geolocator/geolocator.dart';

class LocationService {
  static const double _fallbackLat = 39.9042;
  static const double _fallbackLng = 41.2670;

  Future<Position> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return _fallbackErzurum();

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return _fallbackErzurum();
    }
    if (permission == LocationPermission.deniedForever) {
      return _fallbackErzurum();
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      if (pos.latitude == 0.0 && pos.longitude == 0.0) {
        return _fallbackErzurum();
      }
      return pos;
    } catch (e) {
      print('❌ Konum alınamadı: $e');
      return _fallbackErzurum();
    }
  }

  Position _fallbackErzurum() {
    return Position(
      latitude: _fallbackLat,
      longitude: _fallbackLng,
      timestamp: DateTime.now(),
      accuracy: 10.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );
  }
}