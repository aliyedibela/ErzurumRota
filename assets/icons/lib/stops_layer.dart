import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'utils/stop_utils.dart';

class StopsLayer extends StatefulWidget {
  final List<LatLng> routePoints;
  final String? currentRouteName;
  final bool showBusStops;

  const StopsLayer({
    super.key,
    required this.routePoints,
    this.currentRouteName,
    this.showBusStops = true,
  });

  @override
  State<StopsLayer> createState() => _StopsLayerState();
}

class _StopsLayerState extends State<StopsLayer> {
  List<dynamic> allStops = [];
  final Distance distance = const Distance();

  @override
  void initState() {
    super.initState();
    _loadStops();
  }

  Future<void> _loadStops() async {
    try {
      final data = await rootBundle.loadString('assets/data/all_stops.json');
      setState(() => allStops = jsonDecode(data));
      print("✅ all_stops.json yüklendi (${allStops.length} durak)");
    } catch (e) {
      print("❌ Duraklar yüklenemedi: $e");
    }
  }

  Map<String, dynamic>? _findNearestStop(LatLng point) {
    double bestDist = double.infinity;
    Map<String, dynamic>? bestStop;

    for (final stop in allStops) {
      final d = distance(
        point,
        LatLng(double.parse(stop["lat"]), double.parse(stop["lng"])),
      );
      if (d < bestDist) {
        bestDist = d;
        bestStop = stop;
      }
    }

    // 150 m üzerindeyse durak olarak alma
    if (bestDist > 150) return null;
    return bestStop;
  }

  @override
  Widget build(BuildContext context) {
    if (allStops.isEmpty || widget.routePoints.isEmpty) {
      return const SizedBox.shrink();
    }
    if (!widget.showBusStops) {
      return const SizedBox.shrink();
    }

    final matchedStops = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final point in widget.routePoints) {
      final nearest = _findNearestStop(point);
      if (nearest != null && !seen.contains(nearest["stopId"])) {
        matchedStops.add(nearest);
        seen.add(nearest["stopId"]);
      }
    }

    return MarkerLayer(
      markers: matchedStops.map((stop) {
        final lat = double.parse(stop["lat"]);
        final lng = double.parse(stop["lng"]);
        final stopName = stop["stopName"];
        final stopId = stop["stopId"];
        final routes = (stop["routes"] as List).join(", ");

        return Marker(
          point: LatLng(lat, lng),
          width: 45,
          height: 45,
          child: GestureDetector(
            onTap: () => showDialog(
              context: context,
              builder: (_) => Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueAccent.withOpacity(0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stopName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 1),
                                blurRadius: 0.5,
                                color: Colors.black45,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Durak ID: $stopId",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text.rich(
                          TextSpan(
                            text: "Geçen Hatlar:\n",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                            children: (stop["routes"] as List).map<TextSpan>((
                              r,
                            ) {
                              final isActive =
                                  widget.currentRouteName != null &&
                                  r.trim().toUpperCase() ==
                                      widget.currentRouteName!
                                          .trim()
                                          .toUpperCase();
                              return TextSpan(
                                text: "$r ",
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.blueAccent
                                      : Colors.white,
                                  fontWeight: isActive
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.blueAccent.withOpacity(
                                0.3,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Kapat"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: Image.asset(
                "assets/icons/busstop.png",
                width: 18,
                height: 18,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
