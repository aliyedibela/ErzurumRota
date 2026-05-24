import 'package:latlong2/latlong.dart';

class TaxiStand {
  final String id;
  final String name;
  final String address;
  final String phone;
  final LatLng location;

  const TaxiStand({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.location,
  });
}
