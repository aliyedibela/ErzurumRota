import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

const String baseUrl = "https://superelastic-rylee-tetramerous.ngrok-free.dev";

Future<List<LatLng>> getDrivingRoute(LatLng start, LatLng end) async {
  const String mode = "driving"; // walking, cycling de olabilir

  final url =
      "$baseUrl/route/v1/$mode/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson";

  try {
    final res = await http.get(Uri.parse(url));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final coords = data["routes"][0]["geometry"]["coordinates"] as List;
      return coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
    } else {
      throw Exception(
        "❌ OSRM isteği başarısız: ${res.statusCode} - ${res.reasonPhrase}",
      );
    }
  } catch (e) {
    print("⚠️ OSRM rota alınamadı: $e");
    return [];
  }
}
