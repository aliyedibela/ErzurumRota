// utils/stop_utils.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

class StopUtils {
  /// Tüm duraklar (JSON’dan yüklenir)
  static List<Map<String, dynamic>> allStops = [];

  static bool _loading = false;

  /// JSON'u bir kez yükler (idempotent)
  static Future<void> loadAllStops() async {
    if (_loading || allStops.isNotEmpty) return;
    _loading = true;
    try {
      final data = await rootBundle.loadString('assets/data/all_stops.json');
      final raw = jsonDecode(data) as List;
      allStops = raw.map((e) => Map<String, dynamic>.from(e)).toList();
      debugPrint("✅ all_stops.json yüklendi (${allStops.length} durak)");
    } catch (e) {
      debugPrint("❌ Duraklar yüklenemedi: $e");
    } finally {
      _loading = false;
    }
  }

  /// LatLng'e en yakın durak adını döndür (150 m eşiği ile)
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
