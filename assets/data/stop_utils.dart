import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

class Stop {
  final String name;
  final LatLng coord;

  Stop({required this.name, required this.coord});

  factory Stop.fromJson(Map<String, dynamic> json) {
    return Stop(
      name: json["stopName"] ?? "Bilinmeyen Durak",
      coord: LatLng(
        double.parse(json["lat"].toString()),
        double.parse(json["lng"].toString()),
      ),
    );
  }
}

List<Stop> allStops = [];

Future<void> loadAllStops() async {
  if (allStops.isNotEmpty) return; // zaten yüklüyse tekrar yükleme
  final data = await rootBundle.loadString("assets/data/all_stops.json");
  final jsonList = json.decode(data) as List;
  allStops = jsonList.map((e) => Stop.fromJson(e)).toList();
}

String stopNameFromLatLng(LatLng point) {
  if (allStops.isEmpty) return "Bilinmeyen Durak";
  final distance = const Distance();
  Stop? closest;
  double minDist = double.infinity;

  for (final stop in allStops) {
    final d = distance(stop.coord, point);
    if (d < minDist) {
      minDist = d;
      closest = stop;
    }
  }

  return (minDist < 50) ? closest!.name : "Bilinmeyen Durak";
}
