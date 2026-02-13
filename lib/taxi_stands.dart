import 'package:latlong2/latlong.dart';

class TaxiStand {
  final String id;
  final String name;
  final LatLng location;
  final String phone;
  final String address;

  TaxiStand({
    required this.id,
    required this.name,
    required this.location,
    required this.phone,
    required this.address,
  });
}


final List<TaxiStand> erzurumTaxiStands = [
  TaxiStand(
    id: "diyanet_egitim",
    name: "Diyanet Eğitim Taksi",
    location: LatLng(39.9042, 41.2670),
    phone: "+90 442 XXX XX XX",
    address: "Diyanet Eğitim Durağı",
  ),
  TaxiStand(
    id: "kongre_2nolu",
    name: "2 Nolu Kongre Taksi",
    location: LatLng(39.9050, 41.2680),
    phone: "+90 442 XXX XX XX",
    address: "Kongre Caddesi 2 Nolu Durak",
  ),
  TaxiStand(
    id: "abdurrahman_gazi",
    name: "Abdurrahman Gazi Taksi",
    location: LatLng(39.9100, 41.2700),
    phone: "+90 442 XXX XX XX",
    address: "Abdurrahman Gazi Caddesi",
  ),
  TaxiStand(
    id: "azel_park",
    name: "Azel Park Taksi",
    location: LatLng(39.9020, 41.2650),
    phone: "+90 442 XXX XX XX",
    address: "Azel Park Durağı",
  ),
  TaxiStand(
    id: "aziziye_belediye",
    name: "Aziziye Belediyesi Taksi",
    location: LatLng(39.9080, 41.2720),
    phone: "+90 442 XXX XX XX",
    address: "Aziziye Belediyesi Önü",
  ),
  TaxiStand(
    id: "aziziye_taksi",
    name: "Aziziye Taksi",
    location: LatLng(39.9090, 41.2730),
    phone: "+90 442 XXX XX XX",
    address: "Aziziye Mahallesi",
  ),
  TaxiStand(
    id: "big_yellow",
    name: "Big Yellow Taxi",
    location: LatLng(39.9060, 41.2690),
    phone: "+90 442 XXX XX XX",
    address: "Merkez",
  ),
  TaxiStand(
    id: "bostancioglu",
    name: "Bostancıoğlu Taksi",
    location: LatLng(39.9070, 41.2710),
    phone: "+90 442 XXX XX XX",
    address: "Merkez Bölge",
  ),
  TaxiStand(
    id: "dadasken_erzurum",
    name: "Dadaşkent Erzurum Taksi",
    location: LatLng(39.9110, 41.2740),
    phone: "+90 442 XXX XX XX",
    address: "Dadaşkent",
  ),
  TaxiStand(
    id: "dadasken_lokka",
    name: "Dadaşkent Lökka Taksi",
    location: LatLng(39.9120, 41.2750),
    phone: "+90 442 XXX XX XX",
    address: "Dadaşkent Lökka Durağı",
  ),
];


class TaxiStandUtils {

  static TaxiStand? findNearestTaxiStand(LatLng userLocation) {
    if (erzurumTaxiStands.isEmpty) return null;
    
    final distance = const Distance();
    TaxiStand? nearest;
    double minDistance = double.infinity;
    
    for (final stand in erzurumTaxiStands) {
      final d = distance(userLocation, stand.location);
      if (d < minDistance) {
        minDistance = d;
        nearest = stand;
      }
    }
    
    return nearest;
  }
  
  static List<TaxiStand> findNearbyTaxiStands(
    LatLng userLocation, 
    double radiusInMeters,
  ) {
    final distance = const Distance();
    return erzurumTaxiStands.where((stand) {
      return distance(userLocation, stand.location) <= radiusInMeters;
    }).toList();
  }
  
  static double calculateEstimatedFare(double distanceInMeters) {
    const double openingFee = 50.0;
    const double perKmRate = 25.0;  
    
    final distanceInKm = distanceInMeters / 1000;
    return openingFee + (distanceInKm * perKmRate);
  }
}