import 'package:latlong2/latlong.dart';
import 'package:erzurum_rota/models/taxi_stand.dart';
 
class RouteOption {
  final String lineName;
  final String? transferLine;
  final List<LatLng> walk1;
  final List<LatLng> bus1;
  final List<LatLng> walkTransfer;
  final List<LatLng> bus2;
  final List<LatLng> walk2;
  final double totalDistance;
  final bool isTransfer;
  final String? startStopName;
  final String? endStopName;
  final String? transferStopName;
  final bool isTaxi;
  final TaxiStand? taxiStand;
  final double? estimatedFare;
 
  RouteOption({
    required this.lineName,
    required this.walk1,
    required this.bus1,
    required this.walk2,
    required this.totalDistance,
    this.transferLine,
    this.walkTransfer = const [],
    this.bus2 = const [],
    this.isTransfer = false,
    this.startStopName,
    this.endStopName,
    this.transferStopName,
    this.isTaxi = false,
    this.taxiStand,
    this.estimatedFare,
  });
}