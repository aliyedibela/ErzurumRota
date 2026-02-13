import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'utils/stop_utils.dart';
import 'bus_simulator.dart'; 

class StopsLayer extends StatelessWidget {
  final List<LatLng> routePoints;
  final String? currentRouteName;
  final bool showBusStops;
  final BusSimulationManager? simulationManager;

  const StopsLayer({
    super.key,
    required this.routePoints,
    this.currentRouteName,
    this.showBusStops = true,
    this.simulationManager,
  });

  @override
  Widget build(BuildContext context) {
    if (!showBusStops) return const SizedBox.shrink();

    final markers = <Marker>[];
    final Distance distance = const Distance();
    if (StopUtils.allStops.isNotEmpty) {
      for (var stop in StopUtils.allStops) {
        double lat = double.tryParse(stop['lat'].toString()) ?? 0;
        double lng = double.tryParse(stop['lng'].toString()) ?? 0;
        if (lat == 0 && lng == 0) continue;

        LatLng stopLoc = LatLng(lat, lng);

        bool isOnRoute = false;
        for (var p in routePoints) {
          if (distance(p, stopLoc) < 20) {
            isOnRoute = true;
            break;
          }
        }

        if (isOnRoute) {
          markers.add(
            Marker(
              point: stopLoc,
              width: 24,
              height: 24,
              child: GestureDetector(
                onTap: () => _showStopInfo(context, stop, stopLoc),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blueAccent, width: 2),
                    boxShadow: const [
                      BoxShadow(blurRadius: 4, color: Colors.black26),
                    ],
                  ),
                  child: const Icon(
                    Icons.directions_bus,
                    size: 14,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    return MarkerLayer(markers: markers);
  }

  void _showStopInfo(
    BuildContext context,
    Map<String, dynamic> stopData,
    LatLng stopLoc,
  ) {

    String stopName =
        stopData['stopName'] ??
        stopData['display'] ??
        stopData['ad'] ??
        stopData['name'] ??
        "Durak";
    String linesStr = "";
    if (stopData.containsKey('lines')) {
      linesStr = stopData['lines'].toString();
    } else if (stopData.containsKey('hatlar')) {
      linesStr = stopData['hatlar'].toString();
    } else if (stopData.containsKey('routes')) {
      linesStr = stopData['routes'].toString();
    } else if (stopData.containsKey('Lines')) {
      linesStr = stopData['Lines'].toString();
    }

    linesStr = linesStr.replaceAll('[', '').replaceAll(']', '');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(

            color: const Color(0xFF1A237E).withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, color: Colors.white54),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  const Icon(Icons.place, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      stopName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 30),
              const Text(
                "Bu Duraktan Geçen Hatlar:",
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 10),
              if (linesStr.isNotEmpty && linesStr.trim() != "")
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: linesStr.split(',').map((line) {
                    String cleanLine = line.trim();
                    if (cleanLine.isEmpty) return const SizedBox.shrink();

                    String? etaInfo;
                    Color boxColor = Colors.white.withOpacity(0.1);
                    Color borderColor = Colors.white30;
                    Color textColor = Colors.white;

                    if (simulationManager != null) {

                      int? minGidis = simulationManager!.calculateEtaMinutes(
                        "${cleanLine}_Gidis",
                        stopLoc,
                      );

                      int? minDonus = simulationManager!.calculateEtaMinutes(
                        "${cleanLine}_Donus",
                        stopLoc,
                      );

                      if (minGidis != null) {
                        etaInfo = "$minGidis dk (Gidiş)";
                      } else if (minDonus != null) {
                        etaInfo = "$minDonus dk (Dönüş)";
                      }

                      if (etaInfo != null) {
                        boxColor = Colors.green.withOpacity(0.2);
                        borderColor = Colors.green;
                        textColor = Colors.white; 
                      }
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: boxColor,
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            cleanLine,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (etaInfo != null) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.sensors,
                              size: 14,
                              color: Colors.greenAccent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              etaInfo!,
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                )
              else
                const Text(
                  "Hat bilgisi bulunamadı.",
                  style: TextStyle(color: Colors.white54),
                ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
