import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

class StopUtils {
  static List<Map<String, dynamic>> allStops = [];

  static bool _loading = false;
  
  static List<Map<String, dynamic>> _parseStopsJson(String jsonString) {
    final raw = jsonDecode(jsonString) as List;
    return raw.map((e) => Map<String, dynamic>.from(e)).toList();
  }
  
  static Future<void> loadAllStops() async {
    if (_loading || allStops.isNotEmpty) return;
    _loading = true;
    
    try {
      final data = await rootBundle.loadString('assets/data/all_stops.json');
      
      await Future.delayed(Duration.zero);
      
      allStops = await compute(_parseStopsJson, data);
      
      debugPrint("✅ all_stops.json yüklendi (${allStops.length} durak)");
    } catch (e) {
      debugPrint("❌ Duraklar yüklenemedi: $e");
    } finally {
      _loading = false;
    }
  }
  
  static String stopNameFromLatLng(LatLng point, {double threshold = 150}) {
    if (allStops.isEmpty) return "Durak";
    final dist = const Distance();

    double best = double.infinity;
    String name = "Durak";

    for (final stop in allStops) {
      final lat = double.parse(stop["lat"].toString());
      final lng = double.parse(stop["lng"].toString());
      final d = dist(point, LatLng(lat, lng));
      if (d < best) {
        best = d;
        name = (stop["stopName"] ?? "Durak").toString();
      }
    }
    return best < threshold ? name : "Durak";
  }
}