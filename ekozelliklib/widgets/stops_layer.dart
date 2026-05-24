import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:erzurum_rota/services/bus_simulator.dart';
import 'package:erzurum_rota/services/favorite_stop_service.dart';
import '../core/utils/stop_utils.dart';

class StopsLayer extends StatelessWidget {
  final List<LatLng> routePoints;
  final String? currentRouteName;
  final bool showBusStops;
  final BusSimulationManager? simulationManager;
  final Map<String, List<LatLng>> busLines;
  final void Function(String lineKey)? onEnsureLineLoaded; 

  const StopsLayer({
    super.key,
    required this.routePoints,
    this.currentRouteName,
    this.showBusStops = true,
    this.simulationManager,
    this.busLines = const {},
    this.onEnsureLineLoaded,
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

  Widget _etaRow(IconData icon, String label, int etaMins) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.greenAccent),
        const SizedBox(width: 4),
        Text(
          "$label: $etaMins dk",
          style: const TextStyle(
            color: Colors.greenAccent,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
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
    final favSvc = FavoriteStopService();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return FutureBuilder<bool>(
              future: favSvc.isFavorite(stopData['stopId'].toString()),
              builder: (context, snapshot) {
                final isFav = snapshot.data ?? false;
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
                          const Spacer(),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              backgroundColor: isFav ? Colors.redAccent.withOpacity(0.1) : Colors.white.withOpacity(0.1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            icon: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              color: isFav ? Colors.redAccent : Colors.white,
                              size: 20,
                            ),
                            label: Text(
                              isFav ? "Favorilerden Çıkar" : "Favorilere Ekle",
                              style: TextStyle(
                                color: isFav ? Colors.redAccent : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            onPressed: () async {
                              if (isFav) {
                                await favSvc.toggleFavorite(stopData);
                              } else {
                                final nameController = TextEditingController(text: stopName);
                                await showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: const Color(0xFF1A237E),
                                    title: const Text("Favoriye Ekle", style: TextStyle(color: Colors.white)),
                                    content: TextField(
                                      controller: nameController,
                                      style: const TextStyle(color: Colors.white),
                                      decoration: const InputDecoration(
                                        labelText: "Durak Adı",
                                        labelStyle: TextStyle(color: Colors.white70),
                                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("İptal", style: TextStyle(color: Colors.white70))),
                                      ElevatedButton(
                                        onPressed: () async {
                                          await favSvc.toggleFavorite(stopData, customName: nameController.text);
                                          Navigator.pop(ctx);
                                        },
                                        child: const Text("Ekle"),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              setSheetState(() {});
                            },
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


                            cleanLine = cleanLine
                                .replaceAll('/', '')
                                .replaceAll('-', '');

                            onEnsureLineLoaded?.call("${cleanLine}_Gidis");
                            onEnsureLineLoaded?.call("${cleanLine}_Donus");

                            int? etaGidis =
                                simulationManager?.calculateEtaMinutes(
                                  "${cleanLine}_Gidis",
                                  stopLoc,
                                ) ??
                                simulationManager?.getGhostEta(
                                  "${cleanLine}_Gidis",
                                  stopLoc,
                                  busLines,
                                );

                            int? etaDonus =
                                simulationManager?.calculateEtaMinutes(
                                  "${cleanLine}_Donus",
                                  stopLoc,
                                ) ??
                                simulationManager?.getGhostEta(
                                  "${cleanLine}_Donus",
                                  stopLoc,
                                  busLines,
                                );

                            int? eta;
                            if (etaGidis != null && etaDonus != null) {
                              eta = etaGidis < etaDonus ? etaGidis : etaDonus;
                            } else {
                              eta = etaGidis ?? etaDonus;
                            }

                            bool hasEta = eta != null;

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: hasEta
                                    ? Colors.green.withOpacity(0.15)
                                    : Colors.white.withOpacity(0.08),
                                border: Border.all(
                                  color: hasEta ? Colors.green : Colors.white30,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.directions_bus,
                                        size: 14,
                                        color: Colors.white70,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        cleanLine,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (hasEta) ...[
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.access_time,
                                          size: 12,
                                          color: Colors.greenAccent,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          "$eta dk",
                                          style: const TextStyle(
                                            color: Colors.greenAccent,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (!hasEta)
                                    const Text(
                                      "Veri yok",
                                      style: TextStyle(
                                        color: Colors.white38,
                                        fontSize: 11,
                                      ),
                                    ),
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
          },
        );
      },
    );
  }
}

