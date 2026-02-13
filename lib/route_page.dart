import 'dart:async';
import 'taxi_stands.dart'; 
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:math' show sin, cos, atan2, pi, sqrt;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'generated_polylines.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'profile_screen.dart';
import 'package:signalr_core/signalr_core.dart';
import 'stops_layer.dart';
import 'bus_simulator.dart';
import 'utils/stop_utils.dart';



class RoutePage extends StatefulWidget {
  final LatLng? startPoint;
  final LatLng? destination;
  final String? destinationName;

  const RoutePage({
    super.key,
    this.startPoint,
    this.destination,
    this.destinationName,
  });

  @override
  State<RoutePage> createState() => _RoutePageState();
}

class SegmentResult {
  final LatLng startPoint;
  final LatLng endPoint;
  final List<LatLng> segment;
  final double totalScore;

  SegmentResult({
    required this.startPoint,
    required this.endPoint,
    required this.segment,
    required this.totalScore,
  });
}

class _RoutePageState extends State<RoutePage> {

  List<LatLng>? bus1Segment;
  List<LatLng>? bus2Segment;
  TaxiStand? selectedTaxiStand; 
  bool showTaxiStands = false; 
  List<Marker> _taxiStandMarkers = []; 
  bool isRouteMode = false; 
  bool showBusStops = true;
  List<dynamic>? _cachedStops;
  HubConnection? _hubConnection;
bool _signalRConnected = false;
  final Distance _dist = const Distance();
  BusSimulationManager? _simulationManager;
  List<Marker> _busMarkers = [];
  String? _waitingRequestId;
BuildContext? _waitingDialogCtx;

  double progress = 0.0; 


void _showError(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

void _renderTaxiRouteOnMap(RouteOption opt) {
  final lines = <Polyline>[];

  if (opt.walk1.isNotEmpty) {
    lines.add(
      Polyline(
        points: opt.walk1,
        color: Colors.green,
        strokeWidth: 5,
      ),
    );
  }

  if (opt.bus1.isNotEmpty) {
    lines.add(
      Polyline(
        points: opt.bus1,
        color: const Color(0xFFFF6F00),
        strokeWidth: 7,
      ),
    );
  }

  setState(() {
    polylines = lines;
    suggestedLine = null; 
    transferLine = null;
    showBusStops = false;
    

    if (opt.taxiStand != null) {
      selectedTaxiStand = opt.taxiStand;
      showTaxiStands = true;
    }
  });


  final allPts = [...opt.walk1, ...opt.bus1];
  if (allPts.isNotEmpty) {
    final bounds = LatLngBounds.fromPoints(allPts);
    mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }
}



Future<List<RouteOption>> _calculateTaxiOptions() async {
  if (startPoint == null || endPoint == null) return [];

  final Distance dist = const Distance();
  final List<RouteOption> taxiOptions = [];


  final nearbyStands = TaxiStandUtils.findNearbyTaxiStands(
    startPoint!,
    3000, 
  );

  if (nearbyStands.isEmpty) {
    print("⚠️ Yakınlarda taksi durağı bulunamadı");
    return [];
  }


  nearbyStands.sort((a, b) {
    final distA = dist(startPoint!, a.location);
    final distB = dist(startPoint!, b.location);
    return distA.compareTo(distB);
  });

  final topStands = nearbyStands.take(3).toList();

  for (final stand in topStands) {
    try {

      final walkToStand = await _getRoute(
        startPoint!,
        stand.location,
        mode: "walking",
      );


      final taxiRoute = await _getRoute(
        stand.location,
        endPoint!,
        mode: "driving",
      );

      if (walkToStand.isEmpty || taxiRoute.isEmpty) continue;


      final walkDistance = _polylineLength(walkToStand);
      final taxiDistance = _polylineLength(taxiRoute);
      final totalDistance = walkDistance + taxiDistance;

    
      final fare = TaxiStandUtils.calculateEstimatedFare(taxiDistance);

      taxiOptions.add(
        RouteOption(
          lineName: "Taksi (${stand.name})",
          walk1: walkToStand,
          bus1: taxiRoute, 
          walk2: [], 
          totalDistance: totalDistance,
          isTransfer: false,
          isTaxi: true, 
          taxiStand: stand,
          estimatedFare: fare,
          startStopName: stand.address,
          endStopName: "Varış Noktası",
        ),
      );

      print(
        "🚕 Taksi seçeneği eklendi: ${stand.name} (${fare.toStringAsFixed(0)} TL)",
      );
    } catch (e) {
      print("Taksi rotası hesaplanamadı (${stand.name}): $e");
    }
  }

  return taxiOptions;
}


void _showTaxiSelector() {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(25),
              ),
              border: Border.all(
                color: const Color(0xFFFF6F00).withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.local_taxi, color: Color(0xFFFF6F00), size: 26),
                      SizedBox(width: 10),
                      Text(
                        "Taksi Durağı Seç",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: erzurumTaxiStands.length,
                    itemBuilder: (ctx, index) {
                      final stand = erzurumTaxiStands[index];

                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2E),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: const Color(0xFFFF6F00).withOpacity(0.25),
                          ),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6F00).withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.local_taxi,
                              color: Color(0xFFFF6F00),
                              size: 24,
                            ),
                          ),
                          title: Text(
                            stand.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            stand.address,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF6F00),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              elevation: 0,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              _callTaxi(stand);
                            },
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.phone, size: 15, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  "Çağır",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}



void _callTaxi(TaxiStand stand) async {

  if (startPoint == null) {

   showDialog(
  context: context,
  barrierDismissible: false,
  builder: (ctx) => Dialog(
    backgroundColor: Colors.transparent,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1565C0).withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  const SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 4,
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.15),
                    ),
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),

              const Text(
                'Konumunuz Alınıyor',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              
              const SizedBox(height: 8),

              Text(
                'Lütfen bekleyin...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

    try {
      final pos = await _getCurrentLocation();
      
      if (!mounted) return;
      Navigator.pop(context); 

      setState(() {
        startPoint = LatLng(pos.latitude, pos.longitude);
        _startController.text = "Mevcut Konumunuz";
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); 
      
      _showError("Konum alınamadı. Lütfen haritadan başlangıç noktası seçin.");
      return;
    }
  }

  if (_hubConnection?.state != HubConnectionState.connected) {
    await _connectSignalR();
  }

  final requestId = const Uuid().v4();
  _waitingRequestId = requestId;

  final fare = endPoint != null
      ? TaxiStandUtils.calculateEstimatedFare(
          const Distance()(startPoint!, endPoint!))
      : TaxiStandUtils.calculateEstimatedFare(
          const Distance()(startPoint!, stand.location) + 1000);

  try {
    await _hubConnection!.invoke("RequestTaxi", args: [{
      "requestId": requestId,
      "userId": "anonymous",
      "taxiStandId": stand.id,
      "fromLat": startPoint?.latitude ?? 0,
      "fromLng": startPoint?.longitude ?? 0,
      "toLat": endPoint?.latitude ?? startPoint?.latitude ?? 0,
      "toLng": endPoint?.longitude ?? startPoint?.longitude ?? 0,
      "estimatedFare": fare,
      "status": "Pending",
    }]);

    setState(() {
      selectedTaxiStand = stand;
      showTaxiStands = true;
      _taxiStandMarkers = [_buildSingleTaxiMarker(stand)];
    });
    
    mapController.move(stand.location, 16);
    _showWaitingDialog(requestId, stand);
  } catch (e) {
    _showError("İstek gönderilemedi: $e");
  }
}


Marker _buildSingleTaxiMarker(TaxiStand stand) {
  return Marker(
    point: stand.location,
    width: 70,
    height: 70,
    child: Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFA726), Color(0xFFFF6F00)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.orange.withOpacity(0.5),
                  blurRadius: 12,
                  spreadRadius: 2)
            ],
          ),
          child: const Icon(Icons.local_taxi, color: Colors.white, size: 28),
        ),
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
              color: Color(0xFFFF6F00), shape: BoxShape.circle),
        ),
      ],
    ),
  );
}

void _showWaitingDialog(String requestId, TaxiStand stand) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      _waitingDialogCtx = ctx; 
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFFFF8F00), Color(0xFFE65100)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.orange.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8))
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_taxi, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text("Taksi Aranıyor",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stand.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.location_on, color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text(stand.address,
                          style: const TextStyle(color: Colors.white70, fontSize: 13))),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.phone, color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Text(stand.phone,
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 48, height: 48,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 4),
              ),
              const SizedBox(height: 12),
              const Text("Sürücü onayı bekleniyor...",
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white54),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    _waitingRequestId = null;
                    _waitingDialogCtx = null;
                    Navigator.pop(ctx);
                  },
                  child: const Text("İptal Et",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _infoRow(IconData icon, String label, String value) {
  return Row(children: [
    Icon(icon, color: Colors.white70, size: 18),
    const SizedBox(width: 8),
    Text("$label: ", style: const TextStyle(color: Colors.white70, fontSize: 14)),
    Text(value,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
  ]);
}

void _showResultDialog({
  required bool accepted,
  String? driverName,
  String? plate,
}) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: accepted
                ? [const Color(0xFF2E7D32), const Color(0xFF1B5E20)]
                : [const Color(0xFFC62828), const Color(0xFF7F0000)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
                color: (accepted ? Colors.green : Colors.red).withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8))
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                accepted ? Icons.check_rounded : Icons.close_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),

            Text(
              accepted ? "Taksi Yolda!" : "İstek Reddedildi",
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            if (accepted) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _infoRow(Icons.person, "Sürücü", driverName ?? '-'),
                    const SizedBox(height: 8),
                    _infoRow(Icons.directions_car, "Plaka", plate ?? '-'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: Colors.white70, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Sürücünüz yola çıktı. Konumunuzda bekleyin.",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ]),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  "Bu duraktaki sürücüler şu an müsait değil.\nBaşka bir durak deneyebilirsiniz.",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: 20),

            Row(children: [
              if (!accepted) ...[
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white54),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showTaxiSelector();
                    },
                    child: const Text("Başka Durak",
                        style: TextStyle(color: Colors.white70)),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: accepted ? 1 : 1,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    "Tamam",
                    style: TextStyle(
                        color: accepted
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFC62828),
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    ),
  );
}



void _selectLineToView(String lineKey) {
  ensureBusLineLoaded(lineKey);

  if (busLines.containsKey(lineKey)) {
    final linePoints = busLines[lineKey]!;

    setState(() {
      suggestedLine = lineKey; 
      showBusStops = true;

      polylines = [
        Polyline(
          points: linePoints,
          color: Colors.blueAccent,
          strokeWidth: 5,
        ),
      ];

      bus1Segment = linePoints;
      bus2Segment = null;
      showBusStops = true;
    });

    _simulationManager?.setAllRoutes({lineKey: linePoints});
    _simulationManager?.startSimulation(lineKey);

    if (linePoints.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(linePoints);
      mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
      );
    }
  }
}

@override
void dispose() {
  _hubConnection?.stop();
  super.dispose();
}

void _updateTaxiStandMarkers() {
  if (!showTaxiStands) {
    setState(() => _taxiStandMarkers = []);
    return;
  }

  setState(() {
    _taxiStandMarkers = erzurumTaxiStands.map((stand) {
      final isSelected = selectedTaxiStand?.id == stand.id;

      return Marker(
        point: stand.location,
        width: isSelected ? 80 : 60,
        height: isSelected ? 80 : 60,
        child: GestureDetector(
          onTap: () {
            setState(() => selectedTaxiStand = stand);
            mapController.move(stand.location, 16);
            
         
            showDialog(
              context: context,
              barrierDismissible: true,
              builder: (dialogContext) => Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                backgroundColor: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFA726), Color(0xFFFF6F00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.local_taxi, color: Colors.white, size: 32),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Taksi Durağı",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stand.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: Colors.white70, size: 18),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    stand.address,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.phone, color: Colors.white70, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  stand.phone,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                "Kapat",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                _callTaxi(stand);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFFFF6F00),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.phone_forwarded, size: 20),
                              label: const Text(
                                "Taksi Çağır",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: isSelected ? 50 : 40,
                height: isSelected ? 50 : 40,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: isSelected ? 45 : 35,
                height: isSelected ? 45 : 35,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFA726), Color(0xFFFF6F00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_taxi,
                  color: Colors.white,
                  size: isSelected ? 26 : 20,
                ),
              ),
              if (isSelected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }).toList();
  });
    }
  String getExactStopName(LatLng point) {
 
    if (_cachedStops == null || _cachedStops!.isEmpty) {
      return StopUtils.stopNameFromLatLng(point);
    }

    final Distance distance = const Distance();

  
    for (var stop in _cachedStops!) {
 
      double lat = double.tryParse(stop['lat'].toString()) ?? 0;
      double lng = double.tryParse(stop['lon'].toString()) ?? 0;


      if (distance(point, LatLng(lat, lng)) < 15) {
        return stop['display'];
      }
    }


    return StopUtils.stopNameFromLatLng(point);
  }

  void _smartSelectLine(String baseLineName) {

    String targetLineKey = "${baseLineName}_Gidis";

    if (_simulationManager != null) {
      try {
   
        final activeBus = _simulationManager!.activeBuses.firstWhere(
          (b) => b.lineName.startsWith(baseLineName),
        );

        targetLineKey = activeBus.lineName;
      } catch (e) {
  
      }
    }
    _selectLineToView(targetLineKey);
  }

  void _clearSelectedLine() {
    setState(() {
      suggestedLine = null;
      polylines.clear();
      bus1Segment = null;
      bus2Segment = null;
      _busMarkers = []; 
      isRouteMode = false;
    });
  }

  SegmentResult? findBestSegment(
    LatLng userStart,
    LatLng userEnd,
    List<LatLng> linePoints,
    String lineName,
  ) {
    final Distance distance = const Distance();

    const double searchRadius = 2000;

    final List<int> startCandidates = [];
    final List<int> endCandidates = [];

    for (int i = 0; i < linePoints.length; i++) {
      if (distance(userStart, linePoints[i]) < searchRadius)
        startCandidates.add(i);
      if (distance(userEnd, linePoints[i]) < searchRadius) endCandidates.add(i);
    }

    if (startCandidates.isEmpty || endCandidates.isEmpty) return null;

    SegmentResult? bestResult;
    double minTotalScore = double.infinity;


    for (final sIdx in startCandidates) {
      for (final eIdx in endCandidates) {

        if (sIdx >= eIdx) continue;

  
        final walk1 = distance(userStart, linePoints[sIdx]);
        final walk2 = distance(userEnd, linePoints[eIdx]);


        final busScore = (eIdx - sIdx) * 10;

        final totalScore = walk1 + walk2 + busScore;

        if (totalScore < minTotalScore) {
          minTotalScore = totalScore;

          print(
            "$lineName Aday: Index $sIdx -> Index $eIdx (Skor: ${totalScore.toInt()})",
          );

          bestResult = SegmentResult(
            startPoint: linePoints[sIdx],
            endPoint: linePoints[eIdx],
            segment: linePoints.sublist(sIdx, eIdx + 1),
            totalScore: totalScore,
          );
        }
      }
    }

    return bestResult;
  }

  final Map<String, List<LatLng>> busLines = {};
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  bool isLoading = false;
  String randomTip = "";
  final List<String> loadingTips = [
    "Rotalarınızı analiz ediyoruz...",
    "En kısa yolu bulmak için hatları tarıyoruz...",
    "Biliyor muydunuz? Erzurum’daki en uzun hat G4’tür!",
    "Yürü bin yürü bin mantığıyla aktarma seçenekleri hesaplanıyor...",
    "Ortalama hesaplama süresi 10-15 saniye sürebilir.",
    "OSRM motoru rota geometrilerini çıkarıyor...",
  ];


 @override
void initState() {
  super.initState();
  _simulationManager = BusSimulationManager(
    onUpdate: (buses) {
      if (!mounted) return;

      final visibleBuses = buses.where((b) {
        if (suggestedLine != null) {
          if (b.lineName == suggestedLine) return true;
          if (!suggestedLine!.contains("_") &&
              b.lineName.startsWith(suggestedLine!)) return true;
        }
        if (transferLine != null) {
          if (b.lineName == transferLine) return true;
          if (!transferLine!.contains("_") &&
              b.lineName.startsWith(transferLine!)) return true;
        }
        return false;
      }).toList();
      
      setState(() {
        _busMarkers = visibleBuses.map((b) {
          return Marker(
            point: b.currentLocation,
            width: 45,
            height: 45,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 35,
                  height: 35,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(blurRadius: 5, color: Colors.black45)],
                  ),
                ),
                Icon(Icons.directions_bus_rounded, color: Colors.redAccent, size: 26),
              ],
            ),
          );
        }).toList();
      });
    },
  );

WidgetsBinding.instance.addPostFrameCallback((_) async {
    Future.microtask(() => StopUtils.loadAllStops());
      _connectSignalR();
    if (widget.startPoint != null && widget.destination != null) {
      setState(() {
        startPoint = widget.startPoint!;
        endPoint = widget.destination!;
        _startController.text = "Konumunuz";
        _endController.text = widget.destinationName ?? "Seçilen Konum";
      });
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Rotaları hesaplamak için haritaya dokunun"),
            action: SnackBarAction(
              label: "Hesapla",
              onPressed: _calculateRoutesAndShowDialog,
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  });
}
  void _resetRouteState() {
    setState(() {

      startPoint = null;
      endPoint = null;
      routePoints.clear();
      polylines.clear();
      bus1Segment = null;
      bus2Segment = null;
      suggestedLine = null;
      transferLine = null;
      suggestedOptions.clear();
      isLoading = false;
      progress = 0.0;

 
      _startController.clear();
      _endController.clear();
    });

 
    mapController.move(LatLng(39.9042, 41.2670), 13);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Yeni rota için başlangıç ve varış noktalarını seçin."),
      ),
    );
  }

  String _formatDuration(double meters, {bool isBus = false}) {
    final speed = isBus ? 6.9 : 1.4; 
    final seconds = meters / speed;
    final minutes = (seconds / 60).round();
    return "$minutes dk";
  }

  void _loadAndSimulateLine(String lineKey) {
    _simulationManager?.stop();
    setState(() {
      polylines.clear();
      _busMarkers.clear();
      suggestedLine = lineKey; 


      bus1Segment = null;
      bus2Segment = null;
    });


    ensureBusLineLoaded(lineKey);

    if (busLines.containsKey(lineKey)) {
      final linePoints = busLines[lineKey]!;


      setState(() {
        polylines = [
          Polyline(
            points: linePoints,
            color: Colors.blueAccent,
            strokeWidth: 5,
          ),
        ];
      });


      if (linePoints.isNotEmpty) {
        final bounds = LatLngBounds.fromPoints(linePoints);
        mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
        );
      }


      print("🚌 Hat Seçildi ve Başlatılıyor: $lineKey");
      _simulationManager?.startSimulation(lineKey, linePoints);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$lineKey hattı yüklendi."),
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      print("⚠️ HATA: $lineKey verisi bulunamadı!");
    }
  }

  void _showLineSelector() {
    final allTechnicalLines = [
      "A1_Gidis",
      "A1_Donus",
      "B1_Gidis",
      "B1_Donus",
      "B2_Gidis",
      "B2_Donus",
      "B3_Gidis",
      "B3_Donus",
      "G1_Gidis",
      "G1_Donus",
      "G2_Gidis",
      "G2_Donus",
      "G3_Gidis",
      "G3_Donus",
      "G4_Gidis",
      "G4_Donus",
      "G4A_Gidis",
      "G4A_Donus",
      "G4B_Gidis",
      "G4B_Donus",
      "G5_Gidis",
      "G5_Donus",
      "G6_Gidis",
      "G6_Donus",
      "G7_Gidis",
      "G7_Donus",
      "G7A_Gidis",
      "G7A_Donus",
      "G8_Gidis",
      "G8_Donus",
      "G9_Gidis",
      "G9_Donus",
      "G10_Gidis",
      "G10_Donus",
      "G11_Gidis",
      "G11_Donus",
      "G14_Gidis",
      "G14_Donus",
      "K1_Gidis",
      "K1_Donus",
      "K1A_Gidis",
      "K1A_Donus",
      "K2_Gidis",
      "K2_Donus",
      "K3_Gidis",
      "K3_Donus",
      "K4_Gidis",
      "K4_Donus",
      "K5_Gidis",
      "K5_Donus",
      "K6_Gidis",
      "K6_Donus",
      "K7_Gidis",
      "K7_Donus",
      "K7A_Gidis",
      "K7A_Donus",
      "K10_Gidis",
      "K10_Donus",
      "K11_Gidis",
      "K11_Donus",
      "M11_Gidis",
      "M11_Donus",
    ];

    final Set<String> uniqueLines = {};
    for (var line in allTechnicalLines) {
      if (line.contains("_")) {
        uniqueLines.add(line.split("_")[0]);
      } else {
        uniqueLines.add(line);
      }
    }

    final List<String> displayLines = uniqueLines.toList()..sort();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A237E).withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(25),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 15),
                  Container(width: 50, height: 5, color: Colors.white30),
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      "Hat Seçiniz",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: displayLines.length,
                      itemBuilder: (ctx, index) {
                        final lineBaseName = displayLines[index]; 

                        return ListTile(
                          leading: const Icon(
                            Icons.directions_bus,
                            color: Colors.lightBlueAccent,
                          ),
                          title: Text(
                            lineBaseName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Colors.white54,
                          ),
                          onTap: () {
                            Navigator.pop(context); 

                            _smartSelectLine(lineBaseName);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _toggleDirection() {
    if (suggestedLine == null) return;

    String newLineKey;
    if (suggestedLine!.endsWith("_Gidis")) {
      newLineKey = suggestedLine!.replaceAll("_Gidis", "_Donus");
    } else if (suggestedLine!.endsWith("_Donus")) {
      newLineKey = suggestedLine!.replaceAll("_Donus", "_Gidis");
    } else {
      return;
    }

    _selectLineToView(newLineKey);
  }

 void _showSelectedRouteSummary(RouteOption opt) {
  const double walkingSpeed = 1.4;
  const double busSpeed = 6.9;

  String displayName = opt.lineName.split('_')[0];
  if (opt.isTransfer && opt.transferLine != null) {
    displayName += " → ${opt.transferLine!.split('_')[0]}";
  }

  final totalWalk1 = _polylineLength(opt.walk1);
  final totalBus1 = _polylineLength(opt.bus1);
  final totalWalkTransfer = _polylineLength(opt.walkTransfer);
  final totalBus2 = _polylineLength(opt.bus2);
  final totalWalk2 = _polylineLength(opt.walk2);

  String? liveBusMsg;

  if (!opt.isTaxi && _simulationManager != null && opt.bus1.isNotEmpty) {
    final stopLoc = opt.bus1.first;
    String baseLine = opt.lineName.split('_')[0];
    
    final etaGidis = _simulationManager!.calculateEtaMinutes(
      "${baseLine}_Gidis",
      stopLoc,
    );
    final etaDonus = _simulationManager!.calculateEtaMinutes(
      "${baseLine}_Donus",
      stopLoc,
    );

    if (etaGidis != null) {
      liveBusMsg = "Canlı Takip: Otobüsünüz tahminen $etaGidis dk sonra durakta.";
    } else if (etaDonus != null) {
      liveBusMsg = "Canlı Takip: Otobüsünüz tahminen $etaDonus dk sonra durakta.";
    }
  }

  showModalBottomSheet(
  context: context,
  backgroundColor: Colors.transparent,
  isScrollControlled: false,
  builder: (context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
              border: Border.all(color: Colors.white.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.blueAccent.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

     
                  Text(
                    opt.isTaxi ? "🚕 $displayName" : "🚌 $displayName",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(height: 10),


                  if (opt.isTaxi && opt.estimatedFare != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_wallet, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Tahmini Tutar: ${opt.estimatedFare!.toStringAsFixed(0)} TL",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (liveBusMsg != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.sensors, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              liveBusMsg,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                
                  if (opt.isTaxi) ...[
                    _buildStep(
                      "${_formatDuration(totalWalk1)} yürü (${opt.startStopName ?? 'taksi durağına'})",
                    ),
                    _buildStep(
                      "${_formatDuration(totalBus1, isBus: true)} taksi ile git",
                    ),
                  ] else if (opt.isTransfer) ...[
                    _buildStep(
                      "${_formatDuration(totalWalk1)} yürü (${opt.startStopName ?? 'durağa'})",
                    ),
                    _buildStep(
                      "${_formatDuration(totalBus1, isBus: true)} otobüsle git (${displayName.split(' → ')[0]})",
                    ),
                    _buildStep(
                      "🔁 ${_formatDuration(totalWalkTransfer)} aktarma (${opt.transferStopName ?? 'aktarma durağı'})",
                    ),
                    _buildStep(
                      "${_formatDuration(totalBus2, isBus: true)} otobüsle git (${opt.transferLine?.split('_')[0] ?? '2. hat'})",
                    ),
                    _buildStep(
                      "${_formatDuration(totalWalk2)} yürü (${opt.endStopName ?? 'varışa'})",
                    ),
                  ] else ...[
                    _buildStep(
                      "${_formatDuration(totalWalk1)} yürü (${opt.startStopName ?? 'durağa'})",
                    ),
                    _buildStep(
                      "${_formatDuration(totalBus1, isBus: true)} otobüsle git",
                    ),
                    _buildStep(
                      "${_formatDuration(totalWalk2)} yürü (${opt.endStopName ?? 'varışa'})",
                    ),
                  ],

const SizedBox(height: 12),
Divider(color: Colors.blueAccent.withOpacity(0.3)),
Text(
  "Toplam mesafe: ${opt.totalDistance.toStringAsFixed(0)} m",
  style: TextStyle(
    color: Colors.indigo.shade700,
    fontSize: 14,
  ),
),
const SizedBox(height: 4),
Text(
  "Tahmini toplam süre: ${_formatDuration(opt.totalDistance, isBus: true)} - ${_formatDuration(opt.totalDistance, isBus: false)} arası",
  style: TextStyle(
    color: Colors.indigo.shade400,
    fontSize: 13,
  ),
),
if (opt.isTaxi && opt.taxiStand != null) ...[
  const SizedBox(height: 20),
  Container(
    width: double.infinity,
    height: 55,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFFA726), Color(0xFFFF6F00)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
          color: Colors.orange.withOpacity(0.4),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: ElevatedButton.icon(
      onPressed: () {
        Navigator.pop(context); 
        _callTaxi(opt.taxiStand!); 
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
      icon: const Icon(
        Icons.phone_forwarded,
        color: Colors.white,
        size: 26,
      ),
      label: const Text(
        "BU TAKSİYİ ÇAĞIR",
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    ),
  ),
],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  },
);
}
  Widget _buildStep(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.indigo,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  List<Polyline> polylines = [];


  String? suggestedLine;
  String? transferLine;


  List<RouteOption> suggestedOptions = [];

  LatLng? startPoint;
  LatLng? endPoint;
  List<LatLng> routePoints = [];

  final mapController = MapController();
  String? activeField;

  List<LatLng> _segmentBetween(List<LatLng> line, LatLng start, LatLng end) {
    final startIndex = line.indexOf(start);
    final endIndex = line.indexOf(end);
    if (startIndex < 0 || endIndex < 0) return [];

    if (startIndex < endIndex) {
      return line.sublist(startIndex, endIndex + 1);
    } else {
      final reversed = line.reversed.toList();
      final newStart = reversed.indexOf(start);
      final newEnd = reversed.indexOf(end);
      if (newStart < 0 || newEnd < 0) return [];
      return reversed.sublist(newStart, newEnd + 1);
    }
  }

  double _bearing(LatLng a, LatLng b) {
    final dLon = (b.longitude - a.longitude) * pi / 180;
    final y = sin(dLon) * cos(b.latitude * pi / 180);
    final x =
        cos(a.latitude * pi / 180) * sin(b.latitude * pi / 180) -
        sin(a.latitude * pi / 180) * cos(b.latitude * pi / 180) * cos(dLon);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  double _angleDiff(double a, double b) {
    final diff = (a - b).abs();
    return diff > 180 ? 360 - diff : diff;
  }

  LatLng? _findIntersectionPoint(
    List<LatLng> a,
    List<LatLng> b, {
    required Distance distance,
    double threshold = 80,
  }) {
    LatLng? best;
    double bestScore = double.infinity;

    for (int i = 0; i < a.length - 1; i++) {
      final dirA = _bearing(a[i], a[i + 1]);

      for (int j = 0; j < b.length - 1; j++) {
        final d = distance(a[i], b[j]);

        if (d < threshold) {
          final dirB = _bearing(b[j], b[j + 1]);
          final diff = _angleDiff(dirA, dirB);

          if (diff > 90) continue;

          final score = d + diff * 0.5; 

          if (score < bestScore) {
            bestScore = score;
            best = a[i];
          }
        }
      }
    }

    return best;
  }

  double _polylineLength(List<LatLng> pts) {
    final d = const Distance();
    double sum = 0;
    for (int i = 0; i < pts.length - 1; i++) {
      sum += d(pts[i], pts[i + 1]);
    }
    return sum;
  }

  LatLng findNearestStop(LatLng current, LatLng target, List<LatLng> polyline) {
    final Distance distance = const Distance();
    LatLng nearest = polyline.first;
    double bestScore = double.infinity;

    final userDir = _bearing(current, target);

    for (int i = 0; i < polyline.length - 2; i++) {
      final stop = polyline[i];
      final next = polyline[i + 1];
      final next2 = polyline[i + 2];

      final d = distance(current, stop);

      final dir1 = _bearing(stop, next);
      final dir2 = _bearing(next, next2);
      final avgDir = (dir1 + dir2) / 2;
      final diff = _angleDiff(userDir, avgDir);


      final directionPenalty = diff > 100 ? 9999 : diff;


      final proj = distance(target, next);
      final sameFlow = proj < distance(target, stop);


      final flowPenalty = sameFlow ? 0 : 300;


      final score = d + directionPenalty * 0.5 + flowPenalty;

      if (score < bestScore) {
        bestScore = score;
        nearest = stop;
      }
    }

    return nearest;
  }

  List<LatLng> getSegmentBetweenStops(
    List<LatLng> fullLine,
    LatLng start,
    LatLng end,
  ) {
    int startIndex = 0;
    int endIndex = 0;
    double minStartDist = double.infinity;
    double minEndDist = double.infinity;
    final distance = const Distance();

    for (int i = 0; i < fullLine.length; i++) {
      double dStart = distance(start, fullLine[i]);
      if (dStart < minStartDist) {
        minStartDist = dStart;
        startIndex = i;
      }

      double dEnd = distance(end, fullLine[i]);
      if (dEnd < minEndDist) {
        minEndDist = dEnd;
        endIndex = i;
      }
    }

    if (startIndex > endIndex) {
      int tmp = startIndex;
      startIndex = endIndex;
      endIndex = tmp;
    }

    return fullLine.sublist(startIndex, endIndex + 1);
  }

Future<void> _connectSignalR() async {
  try {
    _hubConnection = HubConnectionBuilder()
        .withUrl("https://jannette-acrogynous-allene.ngrok-free.dev/taxiHub")
        .withAutomaticReconnect()
        .build();
    _hubConnection!.off("TaxiAccepted");
    _hubConnection!.off("TaxiRejected");

_hubConnection!.on("TaxiAccepted", (args) {
  final data = Map<String, dynamic>.from(args?[0] as Map);
  if (data['requestId'] == _waitingRequestId && mounted) {
    _waitingRequestId = null;
    if (_waitingDialogCtx != null) {
      Navigator.of(_waitingDialogCtx!).pop();
      _waitingDialogCtx = null;
    }
    _showResultDialog(
      accepted: true,
      driverName: data['driverName'],
      plate: data['plate'],
    );
  }
});

_hubConnection!.on("TaxiRejected", (args) {
  final data = Map<String, dynamic>.from(args?[0] as Map);
  if (data['requestId'] == _waitingRequestId && mounted) {
    _waitingRequestId = null;
    if (_waitingDialogCtx != null) {
      Navigator.of(_waitingDialogCtx!).pop();
      _waitingDialogCtx = null;
    }
    _showResultDialog(accepted: false);
  }
});

    await _hubConnection!.start();
    setState(() => _signalRConnected = true);
    print("✅ SignalR bağlandı");
  } catch (e) {
    print("❌ SignalR bağlantı hatası: $e");
  }
}


void _showOptionsDialog(BuildContext context, List<RouteOption> options) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 50,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const Text(
                      "Alternatif Rota Önerileri",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 4,
                            color: Colors.black38,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: ListView.builder(
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final opt = options[index];
                          IconData icon;
                          List<Color> gradient;
                          String subtitle;

                          if (opt.isTaxi) {
                            icon = Icons.local_taxi;
                            gradient = [
                              const Color(0xFFFFA726),
                              const Color(0xFFFF6F00),
                            ];
                            subtitle = opt.estimatedFare != null
                                ? "Tahmini ücret: ${opt.estimatedFare!.toStringAsFixed(0)} TL • ${opt.totalDistance.toStringAsFixed(0)} m"
                                : "Taksi ile ulaşım (${opt.totalDistance.toStringAsFixed(0)} m)";
                          } else if (opt.lineName.contains("Yürüyüş")) {
                            icon = Icons.directions_walk;
                            gradient = [
                              Colors.greenAccent,
                              Colors.green.shade700,
                            ];
                            subtitle =
                                "Kısa mesafe yürüyüş (${opt.totalDistance.toStringAsFixed(0)} m)";
                          } else if (opt.lineName.contains("Araç")) {
                            icon = Icons.directions_car;
                            gradient = [Colors.redAccent, Colors.deepOrange];
                            subtitle =
                                "Araçla tahmini: ${opt.totalDistance.toStringAsFixed(0)} m";
                          } else if (opt.isTransfer) {
                            icon = Icons.swap_horiz;
                            gradient = [
                              Colors.orangeAccent,
                              Colors.deepOrange,
                            ];
                            subtitle =
                                "Aktarmalı rota (${opt.totalDistance.toStringAsFixed(0)} m)";
                          } else {
                            icon = Icons.directions_bus;
                            gradient = [
                              Colors.lightBlueAccent,
                              Colors.blueAccent,
                            ];
                            subtitle =
                                "Direkt hat (${opt.totalDistance.toStringAsFixed(0)} m)";
                          }

                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: Duration(
                              milliseconds: 400 + (index * 80),
                            ),
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: gradient,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: gradient.last.withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ListTile(
                                    leading: Icon(
                                      icon,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                    title: Text(
                                      opt.isTransfer
                                          ? "${opt.lineName.split('_')[0]} → ${opt.transferLine?.split('_')[0]}"
                                          : opt.lineName.split('_')[0],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    subtitle: Text(
                                      subtitle,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.pop(context);
                                      FocusScope.of(context).unfocus(); 

                                      if (opt.isTaxi) {
                                        _renderTaxiRouteOnMap(opt);
                                        _showSelectedRouteSummary(opt);
                                        return; 
                                      }

                               
                                      List<LatLng> fullLine1 = [];
                                      if (busLines.containsKey(opt.lineName)) {
                                        fullLine1 = busLines[opt.lineName]!;
                                      }

                                      List<LatLng> fullLine2 = [];
                                      if (opt.transferLine != null &&
                                          busLines.containsKey(opt.transferLine)) {
                                        fullLine2 = busLines[opt.transferLine]!;
                                      }

                                     
                                      _simulationManager?.startSimulation(opt.lineName);

                                      
                                      setState(() {
                                        suggestedLine = opt.lineName;
                                        transferLine = opt.transferLine;

                                        polylines = [
                                       
                                          if (fullLine1.isNotEmpty)
                                            Polyline(
                                              points: fullLine1,
                                              color: Colors.blueAccent.withOpacity(0.3),
                                              strokeWidth: 6,
                                            ),
                                          if (fullLine2.isNotEmpty)
                                            Polyline(
                                              points: fullLine2,
                                              color: Colors.purpleAccent.withOpacity(0.3),
                                              strokeWidth: 6,
                                            ),

                                     
                                          if (opt.walk1.isNotEmpty)
                                            Polyline(
                                              points: opt.walk1,
                                              color: Colors.green,
                                              strokeWidth: 5,
                                            ),

                                    
                                          if (opt.bus1.isNotEmpty)
                                            Polyline(
                                              points: opt.bus1,
                                              color: opt.lineName.contains("Araç")
                                                  ? Colors.redAccent
                                                  : Colors.blue,
                                              strokeWidth: 6,
                                            ),

                                     
                                          if (opt.walkTransfer.isNotEmpty)
                                            Polyline(
                                              points: opt.walkTransfer,
                                              color: Colors.orange,
                                              strokeWidth: 5,
                                            ),
                                          if (opt.bus2.isNotEmpty)
                                            Polyline(
                                              points: opt.bus2,
                                              color: Colors.purple,
                                              strokeWidth: 6,
                                            ),

                                    
                                          if (opt.walk2.isNotEmpty)
                                            Polyline(
                                              points: opt.walk2,
                                              color: Colors.green,
                                              strokeWidth: 5,
                                            ),
                                        ];

                                      
                                        bus1Segment = fullLine1.isNotEmpty
                                            ? fullLine1
                                            : opt.bus1;
                                        bus2Segment = fullLine2.isNotEmpty
                                            ? fullLine2
                                            : opt.bus2;
                                        showBusStops = !opt.lineName.contains("Araç");
                                      });

                              
                                      if (fullLine1.isNotEmpty) {
                                        final bounds = LatLngBounds.fromPoints(fullLine1);
                                        mapController.fitCamera(
                                          CameraFit.bounds(
                                            bounds: bounds,
                                            padding: const EdgeInsets.all(50),
                                          ),
                                        );
                                      }

                                      _showSelectedRouteSummary(opt);
                                    },
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

  List<LatLng> walkingToStop = [];
  List<LatLng> busRoute = [];
  List<LatLng> walkingToDestination = [];

  void _selectLineBasedOnDirection() {
    if (startPoint == null || endPoint == null) return;

    if (endPoint!.latitude > startPoint!.latitude) {
      setState(() => suggestedLine = "K10");
      print("✅ Önerilen hat: K10");
    } else {
      setState(() => suggestedLine = "B3");
      print("✅ Önerilen hat: B3");
    }
  }

  void _moveTo(LatLng point) {
    mapController.move(point, 15);
  }

  Future<List<LatLng>> _getRoute(
    LatLng start,
    LatLng end, {
    String mode = "driving",
  }) async {
    print(
      "→ _getRoute called (mode=$mode) start=${start.latitude},${start.longitude} end=${end.latitude},${end.longitude}",
    );

    await Future.delayed(const Duration(milliseconds: 300));

    final baseUrl = (mode == "walking")
        ? "https://ellyn-uncounteracted-semirebelliously.ngrok-free.dev"
        : "https://superelastic-rylee-tetramerous.ngrok-free.dev";

    final url =
        "$baseUrl/route/v1/$mode/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson";

    print("OSRM çağrısı ($mode): $url");

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5)); 

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List coords = data["routes"][0]["geometry"]["coordinates"];
        print("📦 OSRM route ($mode) geldi: ${coords.length} nokta");
        return coords.map((c) => LatLng(c[1], c[0])).toList();
      } else {
        print("⚠️ Rota alınamadı ($mode): ${response.statusCode}");
        return []; 
      }
    } catch (e) {
      print("❌ Rota isteği başarısız ($mode): $e");
      return []; 
    }
  }

  Future<Position> _getCurrentLocation() async {
  bool serviceEnabled;
  LocationPermission permission;
  
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return _fallbackErzurum();
  }
  
  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return _fallbackErzurum();
    }
  }

  if (permission == LocationPermission.deniedForever) {
    return _fallbackErzurum();
  }

  try {

    Position pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10), 
    );
    
    if (pos.latitude == 0.0 && pos.longitude == 0.0) {
      return _fallbackErzurum();
    }

    return pos;
  } catch (e) {
    print('❌ Konum alınamadı: $e');
    return _fallbackErzurum();
  }
}

  Position _fallbackErzurum() {
    return Position(
      latitude: 39.9042,
      longitude: 41.2670,
      timestamp: DateTime.now(),
      accuracy: 10.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );
  }

  List<Marker> getBusStopMarkers({
    List<LatLng>? bus1Segment, 
    List<LatLng>? bus2Segment, 

    String? currentRouteName, 
  }) {
    final markers = <Marker>[];

    if (currentRouteName != null &&
        (currentRouteName.contains("Araç") ||
            currentRouteName.contains("Yürüyüş"))) {
      return markers;
    }

    if (bus1Segment != null && bus1Segment.isNotEmpty) {
      for (final p in bus1Segment) {
        markers.add(
          Marker(
            point: p,
            width: 15,
            height: 15,
            child: Image.asset(
              "assets/icons/bus_stop.png",
              width: 15,
              height: 15,
              fit: BoxFit.contain,
            ),
          ),
        );
      }
    }

    if (bus2Segment != null && bus2Segment.isNotEmpty) {
      for (final p in bus2Segment) {
        markers.add(
          Marker(
            point: p,
            width: 15,
            height: 15,
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Colors.purpleAccent,
                BlendMode.modulate,
              ),
              child: Image.asset(
                "assets/icons/bus_stop.png",
                width: 15,
                height: 15,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      }
    }

    return markers;
  }

  void ensureBusLineLoaded(String lineName) {
    if (busLines.containsKey(lineName)) return;

    switch (lineName) {
      case "B3_Gidis":
        busLines["B3_Gidis"] = B3_Gidis;
        break;
      case "B3_Donus":
        busLines["B3_Donus"] = B3_Donus;
        break;

      case "B1_Gidis":
        busLines["B1_Gidis"] = B1_Gidis;
        break;
      case "B1_Donus":
        busLines["B1_Donus"] = B1_Donus;
        break;

      case "B2_Gidis":
        busLines["B2_Gidis"] = B2_Gidis;
        break;
      case "B2_Donus":
        busLines["B2_Donus"] = B2_Donus;
        break;

      case "B2A_Gidis":
        busLines["B2A_Gidis"] = B2A_Gidis;
        break;
      case "B2A_Donus":
        busLines["B2A_Donus"] = B2A_Donus;
        break;
      case "G1_Gidis":
        busLines["G1_Gidis"] = G1_Gidis;
        break;
      case "G1_Donus":
        busLines["G1_Donus"] = G1_Donus;
        break;

      case "G2_Gidis":
        busLines["G2_Gidis"] = G2_Gidis;
        break;
      case "G2_Donus":
        busLines["G2_Donus"] = G2_Donus;
        break;

      case "G3_Gidis":
        busLines["G3_Gidis"] = G3_Gidis;
        break;
      case "G3_Donus":
        busLines["G3_Donus"] = G3_Donus;
        break;

      case "G4_Gidis":
        busLines["G4_Gidis"] = G4_Gidis;
        break;
      case "G4_Donus":
        busLines["G4_Donus"] = G4_Donus;
        break;

      case "G4A_Gidis":
        busLines["G4A_Gidis"] = G4A_Gidis;
        break;
      case "G4A_Donus":
        busLines["G4A_Donus"] = G4A_Donus;
        break;

      case "G4B_Gidis":
        busLines["G4B_Gidis"] = G4B_Gidis;
        break;
      case "G4B_Donus":
        busLines["G4B_Donus"] = G4B_Donus;
        break;

      case "G5_Gidis":
        busLines["G5_Gidis"] = G5_Gidis;
        break;
      case "G5_Donus":
        busLines["G5_Donus"] = G5_Donus;
        break;

      case "G6_Gidis":
        busLines["G6_Gidis"] = G6_Gidis;
        break;
      case "G6_Donus":
        busLines["G6_Donus"] = G6_Donus;
        break;

      case "G7_Gidis":
        busLines["G7_Gidis"] = G7_Gidis;
        break;
      case "G7_Donus":
        busLines["G7_Donus"] = G7_Donus;
        break;
      case "G7A_Gidis":
        busLines["G7A_Gidis"] = G7A_Gidis;
        break;
      case "G7A_Donus":
        busLines["G7A_Donus"] = G7A_Donus;
        break;
      case "G8_Gidis":
        busLines["G8_Gidis"] = G8_Gidis;
        break;
      case "G8_Donus":
        busLines["G8_Donus"] = G8_Donus;
        break;
      case "G9_Gidis":
        busLines["G9_Gidis"] = G9_Gidis;
        break;
      case "G9_Donus":
        busLines["G9_Donus"] = G9_Donus;
        break;
      case "G10_Gidis":
        busLines["G10_Gidis"] = G10_Gidis;
        break;
      case "G10_Donus":
        busLines["G10_Donus"] = G10_Donus;
        break;
      case "G11_Gidis":
        busLines["G11_Gidis"] = G11_Gidis;
        break;
      case "G11_Donus":
        busLines["G11_Donus"] = G11_Donus;
        break;
      case "G14_Gidis":
        busLines["G14_Gidis"] = G14_Gidis;
        break;
      case "G14_Donus":
        busLines["G14_Donus"] = G14_Donus;
        break;
      case "K1_Gidis":
        busLines["K1_Gidis"] = K1_Gidis;
        break;
      case "K1_Donus":
        busLines["K1_Donus"] = K1_Donus;
        break;
      case "K1A_Gidis":
        busLines["K1A_Gidis"] = K1A_Gidis;
        break;
      case "K1A_Donus":
        busLines["K1A_Donus"] = K1A_Donus;
        break;
      case "K2_Gidis":
        busLines["K2_Gidis"] = K2_Gidis;
        break;
      case "K2_Donus":
        busLines["K2_Donus"] = K2_Donus;
        break;

      case "K3_Gidis":
        busLines["K3_Gidis"] = K3_Gidis;
        break;
      case "K3_Donus":
        busLines["K3_Donus"] = K3_Donus;
        break;
      case "K4_Gidis":
        busLines["K4_Gidis"] = K4_Gidis;
        break;
      case "K4_Donus":
        busLines["K4_Donus"] = K4_Donus;
        break;
      case "K5_Gidis":
        busLines["K5_Gidis"] = K5_Gidis;
        break;
      case "K5_Donus":
        busLines["K5_Donus"] = K5_Donus;
        break;
      case "K6_Gidis":
        busLines["K6_Gidis"] = K6_Gidis;
        break;
      case "K6_Donus":
        busLines["K6_Donus"] = K6_Donus;
        break;
      case "K7_Gidis":
        busLines["K7_Gidis"] = K7_Gidis;
        break;
      case "K7_Donus":
        busLines["K7_Donus"] = K7_Donus;
        break;
      case "K7A_Gidis":
        busLines["K7A_Gidis"] = K7A_Gidis;
        break;
      case "K7A_Donus":
        busLines["K7A_Donus"] = K7A_Donus;
        break;
      case "K10_Gidis":
        busLines["K10_Gidis"] = K10_Gidis;
        break;
      case "K10_Donus":
        busLines["K10_Donus"] = K10_Donus;
        break;
      case "K11_Gidis":
        busLines["K11_Gidis"] = K11_Gidis;
        break;
      case "K11_Donus":
        busLines["K11_Donus"] = K11_Donus;
        break;
      case "M11_Gidis":
        busLines["M11_Gidis"] = M11_Gidis;
        break;
      case "M11_Donus":
        busLines["M11_Donus"] = M11_Donus;
        break;
      case "A1_Gidis":
        busLines["A1_Gidis"] = A1_Gidis;
        break;
      case "A1_Donus":
        busLines["A1_Donus"] = A1_Donus;
        break;

      default:
        print("⚠️ Hat bulunamadı: $lineName");
    }
  }

  Future<List<LatLng>> getBusLineDrivingPath(List<LatLng> stops) async {
    List<LatLng> fullPath = [];

    for (int i = 0; i < stops.length - 1; i++) {
      final start = stops[i];
      final end = stops[i + 1];

      final segment = await _getRoute(start, end, mode: "driving");

      if (segment.isNotEmpty) {
        if (fullPath.isNotEmpty) segment.removeAt(0);
        fullPath.addAll(segment);
      }
    }

    return fullPath;
  }

  Future<void> _calculateRoutesAndShowDialog() async {
    FocusScope.of(context).unfocus();
    setState(() {
      polylines.clear();
      bus1Segment = null;
      bus2Segment = null;
      suggestedOptions.clear();
    });

    randomTip = (loadingTips..shuffle()).first;
    setState(() => isLoading = true);

    double progress = 0.0;
    const int MAX_SECONDS = 15; 
    const int MAX_DIRECT = 2; 
    const int MAX_TRANSFER = 4; 

    final stopwatch = Stopwatch()..start();
    final timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || !isLoading) {
        t.cancel();
      } else {
        final elapsed = stopwatch.elapsed.inSeconds;
        setState(() {
          progress = (elapsed / MAX_SECONDS).clamp(
            0.0,
            1.0,
          ); 
          randomTip = (loadingTips..shuffle()).first;
        });
      }
    });

    if (startPoint == null || endPoint == null) return;

    final Distance dist = const Distance();
    final double directDistance = dist(startPoint!, endPoint!);

    const double NEAR_STOP = 400;
    const double XFER_NEAR = 40;
    const double MAX_WALK_FOR_DIRECT = 1000;

    final List<MapEntry<String, List<LatLng>>> nearby = [];
    final allLineNames = [
      "A1_Gidis", "A1_Donus",
      "B1_Gidis", "B1_Donus",
      "B2_Gidis", "B2_Donus",
      "B2A_Gidis", "B2A_Donus",
      "B3_Gidis", "B3_Donus",
      "G1_Gidis", "G1_Donus",
      "G2_Gidis",
      "G2_Donus", 
      "G3_Gidis", "G3_Donus",
      "G4_Gidis", "G4_Donus",
      "G4A_Gidis", "G4A_Donus", 
      "G4B_Gidis", "G4B_Donus", 
      "G5_Gidis", "G5_Donus",
      "G6_Gidis", "G6_Donus",
      "G7_Gidis", "G7_Donus",
      "G7A_Gidis", "G7A_Donus",
      "G8_Gidis", "G8_Donus",
      "G9_Gidis", "G9_Donus",
      "G10_Gidis", "G10_Donus",
      "G11_Gidis", "G11_Donus", 
      "G14_Gidis", "G14_Donus", 
      "K1_Gidis", "K1_Donus",
      "K1A_Gidis", "K1A_Donus", 
      "K2_Gidis", "K2_Donus",
      "K3_Gidis", "K3_Donus",
      "K4_Gidis", "K4_Donus",
      "K5_Gidis", "K5_Donus",
      "K6_Gidis", "K6_Donus",
      "K7_Gidis", "K7_Donus",
      "K7A_Gidis", "K7A_Donus",
      "K10_Gidis", "K10_Donus",
      "K11_Gidis", "K11_Donus",
      "M11_Gidis", "M11_Donus",
    ];

    for (int i = 0; i < allLineNames.length; i++) {
  final name = allLineNames[i];
  ensureBusLineLoaded(name);
   if (i % 2 == 0) {
    await Future.delayed(Duration.zero);
  }
  final line = busLines[name];
      if (line == null || line.isEmpty) continue;
      final nearS = line.any((p) => dist(startPoint!, p) < NEAR_STOP);
      final nearE = line.any((p) => dist(endPoint!, p) < NEAR_STOP);
      if (nearS || nearE) nearby.add(MapEntry(name, line));
    }

    final startNearby = nearby
        .where((e) => e.value.any((p) => dist(startPoint!, p) < NEAR_STOP))
        .map((e) => e.key)
        .toSet();
    final endNearby = nearby
        .where((e) => e.value.any((p) => dist(endPoint!, p) < NEAR_STOP))
        .map((e) => e.key)
        .toSet();

    final List<RouteOption> options = [];
    if (directDistance < 1000) {
      final walkOnly = await _getRoute(startPoint!, endPoint!, mode: "walking");
      final total = _polylineLength(walkOnly);

      options.add(
        RouteOption(
          lineName: "Yürüyüş (Kısa Mesafe)",
          walk1: walkOnly,
          bus1: [],
          walk2: [],
          totalDistance: total,
          isTransfer: false,
          startStopName: "Binilecek Durak", 
          endStopName: "İnilecek Durak",
        ),
      );

      setState(() {
        isLoading = false;
        suggestedOptions = options;
      });
      _showOptionsDialog(context, options);
      print(
        "🚶‍♂️ Kısa mesafe yürüyüş rotası önerildi (${total.toStringAsFixed(0)} m)",
      );
    }

    final directCandidates = startNearby
        .intersection(endNearby)
        .take(MAX_DIRECT);

    for (final name in directCandidates) {
      if (stopwatch.elapsed.inSeconds > MAX_SECONDS) break;

      final line = busLines[name]!;

      final bestSegment = findBestSegment(startPoint!, endPoint!, line, name);

      if (bestSegment == null) {
        print("$name için uygun yönlü rota bulunamadı.");
        continue;
      }

      final ns = bestSegment.startPoint;
      final ne = bestSegment.endPoint;
      final bus1 = bestSegment.segment;
      final nsName = getExactStopName(ns);
      final neName = getExactStopName(ne);

      print("SEÇİLEN ROTA ($name): $nsName -> $neName");

      final results = await Future.wait([
        _getRoute(startPoint!, ns, mode: "walking"),
        _getRoute(ne, endPoint!, mode: "walking"),
      ]).timeout(const Duration(seconds: 5), onTimeout: () => [[], []]);

      final walk1 = results[0];
      final walk2 = results[1];
      final total =
          _polylineLength(walk1) +
          _polylineLength(bus1) +
          _polylineLength(walk2);

      String displayName = name;
      if (name.contains("_")) {
        displayName = name.split("_")[0];
      }

      options.add(
        RouteOption(
          lineName: name,
          walk1: walk1,
          bus1: bus1,
          walk2: walk2,
          totalDistance: total,
          isTransfer: false,
          startStopName: nsName,
          endStopName: neName,
        ),
      );

      setState(() => progress += 0.25);
    }
    int transferCount = 0;
    for (final sName in startNearby) {
      for (final eName in endNearby) {
        if (transferCount >= MAX_TRANSFER ||
            stopwatch.elapsed.inSeconds > MAX_SECONDS)
          break;
        if (sName == eName) continue;

        final sLine = busLines[sName]!;
        final eLine = busLines[eName]!;

        final xPoint = _findIntersectionPoint(
          sLine,
          eLine,
          distance: dist,
          threshold: XFER_NEAR,
        );
        if (xPoint == null) continue;

        final ns = findNearestStop(startPoint!, endPoint!, sLine);
        final nt1 = findNearestStop(xPoint, endPoint!, sLine);
        final nt2 = findNearestStop(xPoint, endPoint!, eLine);
        final ne = findNearestStop(endPoint!, startPoint!, eLine);

        final nsName = StopUtils.stopNameFromLatLng(ns);
        final nt1Name = StopUtils.stopNameFromLatLng(nt1);
        final nt2Name = StopUtils.stopNameFromLatLng(nt2);
        final neName = StopUtils.stopNameFromLatLng(ne);

        try {
          final walks = await Future.wait([
            _getRoute(startPoint!, ns, mode: "walking"),
            _getRoute(nt1, nt2, mode: "walking"),
            _getRoute(ne, endPoint!, mode: "walking"),
          ]).timeout(const Duration(seconds: 6));

          final bus1 = _segmentBetween(sLine, ns, nt1);
          final bus2 = _segmentBetween(eLine, nt2, ne);

          final total =
              _polylineLength(walks[0]) +
              _polylineLength(bus1) +
              _polylineLength(walks[1]) +
              _polylineLength(bus2) +
              _polylineLength(walks[2]);

          String displaySName = sName;
          if (sName.contains("_")) {
            displaySName = sName.split("_")[0];
          }

          String displayEName = eName;
          if (eName.contains("_")) {
            displayEName = eName.split("_")[0];
          }
          options.add(
            RouteOption(
              lineName: sName,
              transferLine: eName,
              walk1: walks[0],
              bus1: bus1,
              walkTransfer: walks[1],
              bus2: bus2,
              walk2: walks[2],
              totalDistance: total,
              isTransfer: true,
              startStopName: nsName, 
              transferStopName: "$nt1Name ↔ $nt2Name", 
              endStopName: neName, 
            ),
          );

          transferCount++;
          progress += 0.3;
          setState(() {});
        } catch (_) {}
      }
    }
    stopwatch.stop();
    timer.cancel();

    if (options.isEmpty && stopwatch.elapsed.inSeconds >= MAX_SECONDS) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("15 saniye içinde uygun rota bulunamadı."),
        ),
      );
      return;
    }

    try {
      final carRoute = await _getRoute(startPoint!, endPoint!, mode: "driving");
      final carDistance = _polylineLength(carRoute);

      options.add(
        RouteOption(
          lineName: "Araç (Otomobil)",
          walk1: [],
          bus1: carRoute,
          walk2: [],
          totalDistance: carDistance,
          isTransfer: false,
        ),
      );

      print("🚗 Araç rotası eklendi (${carDistance.toStringAsFixed(0)} m)");
    } catch (e) {
      print("Araç rotası alınamadı: $e");
    }
  try {
    print("🚕 Taksi seçenekleri hesaplanıyor...");
    final taxiOptions = await _calculateTaxiOptions();
    
    if (taxiOptions.isNotEmpty) {
      options.addAll(taxiOptions);
      print("✅ ${taxiOptions.length} taksi seçeneği eklendi");
    }
  } catch (e) {
    print("Taksi rotaları hesaplanamadı: $e");
  }

  options.sort((a, b) => a.totalDistance.compareTo(b.totalDistance));
  final limited = options.take(MAX_DIRECT + MAX_TRANSFER + 3).toList(); 

  setState(() {
    isLoading = false;
    suggestedOptions = limited;
  });

  _showOptionsDialog(context, limited);

  print(
    "${options.length} rota bulundu (${stopwatch.elapsed.inSeconds}s sürdü)",
  );
}

  Future<void> _renderOptionOnMap(RouteOption opt) async {
    final lines = <Polyline>[];

    if (opt.walk1.isNotEmpty)
      lines.add(
        Polyline(points: opt.walk1, color: Colors.green, strokeWidth: 3),
      );
    if (opt.bus1.isNotEmpty)
      lines.add(Polyline(points: opt.bus1, color: Colors.blue, strokeWidth: 5));
    if (opt.walkTransfer.isNotEmpty)
      lines.add(
        Polyline(
          points: opt.walkTransfer,
          color: Colors.orange,
          strokeWidth: 3,
        ),
      );
    if (opt.bus2.isNotEmpty)
      lines.add(
        Polyline(points: opt.bus2, color: Colors.indigo, strokeWidth: 5),
      );
    if (opt.walk2.isNotEmpty)
      lines.add(
        Polyline(points: opt.walk2, color: Colors.green, strokeWidth: 3),
      );

    setState(() {
      polylines = lines;
      suggestedLine = opt.lineName;
      transferLine = opt.transferLine;

      if (opt.lineName.contains("Araç")) {
        setState(() {
          showBusStops = false;
        });
      } else {
        setState(() {
          showBusStops = true;
        });
      }
    });


    final allPts = <LatLng>[
      ...opt.walk1,
      ...opt.bus1,
      ...opt.walkTransfer,
      ...opt.bus2,
      ...opt.walk2,
    ];
    if (allPts.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(allPts);
      mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    if (args != null && endPoint == null) {
      endPoint = LatLng(args["lat"], args["lng"]);
      widget.destinationName;
    }

    return Scaffold(
      backgroundColor: const Color(
        0xFFF4F6FA,
      ), 
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: AppBar(
                backgroundColor: Colors.transparent,
                centerTitle: true,
                titleSpacing: 0, 

                title: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ), 
                  child: widget.destinationName != null
                      ? Text(
                          widget.destinationName!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        )
   
                      : const _BillboardTitle(),
                ),
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.black87,
                  ),
                  onPressed: () {
           
                   Navigator.of(context).pop();
                  },
                ),
              ),
            ),
          ),
        ),
      ),

      body: Column(
        children: [
      
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SearchLocationField(
                          controller: _startController,
                          hintText: "Nereden",
                          showCurrentLocationOption: true,
                          onSelected: (lat, lng) {
                            print("→ start onSelected lat=$lat lng=$lng");
                            setState(() => startPoint = LatLng(lat, lng));
                            _moveTo(startPoint!);
                          },
                          onFocus: () => setState(() => activeField = "start"),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Colors.blueAccent, Colors.lightBlueAccent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueAccent.withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.swap_vert_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () async {
                            if (startPoint != null && endPoint != null) {
                              final oldStartText = _startController.text;
                              final oldEndText = _endController.text;

                              setState(() {
                                final temp = startPoint;
                                startPoint = endPoint;
                                endPoint = temp;
                                _startController.text = oldEndText;
                                _endController.text = oldStartText;
                              });

                              await _calculateRoutesAndShowDialog();
                              _selectLineBasedOnDirection();

                              final newRoute = await _getRoute(
                                startPoint!,
                                endPoint!,
                                mode: "walking",
                              );

                              setState(() => routePoints = newRoute);
                              _moveTo(endPoint!);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: SearchLocationField(
                      controller: _endController,
                      hintText: "Nereye",
                      showCurrentLocationOption: false,
                      onSelected: (lat, lng) async {
                        print("→ end onSelected lat=$lat lng=$lng");
                        setState(() => endPoint = LatLng(lat, lng));
                        if (startPoint != null && endPoint != null) {
                          await _calculateRoutesAndShowDialog();
                        }
                        _moveTo(endPoint!);
                        if (startPoint != null) {
                          _selectLineBasedOnDirection();
                        }
                      },
                      onFocus: () => setState(() => activeField = "end"),
                    ),
                  ),
                ),
              ),
            ),
          ),

       
          Expanded(
            child: Stack(
              children: [
    
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: LatLng(39.9042, 41.2670),
                    initialZoom: 13,
                    onTap: (tapPosition, point) async {
                      if (isLoading) return;

                      setState(() {
                        if (activeField == "start") {
                          startPoint = point;
                        } else if (activeField == "end") {
                          endPoint = point;
                        }
                      });

              
                      if (startPoint != null && endPoint != null) {
                        await _calculateRoutesAndShowDialog();
                      }
                    },
                  ),

                  children: [
             TileLayer(
  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
  userAgentPackageName: 'com.example.erzurum_rota',
),
            
                    if (polylines.isNotEmpty)
                      PolylineLayer(polylines: polylines),

             
                    if (bus1Segment != null)
                      StopsLayer(
                        routePoints: bus1Segment!,
                        currentRouteName: suggestedLine,
                        showBusStops: showBusStops,
                        simulationManager: _simulationManager,
                      ),

       
                    if (bus2Segment != null && transferLine != null)
                      StopsLayer(
                        routePoints: bus2Segment!,
                        currentRouteName: transferLine,
                        showBusStops: showBusStops,
                        simulationManager: _simulationManager,
                      ),

                       if (_taxiStandMarkers.isNotEmpty)
    MarkerLayer(markers: _taxiStandMarkers),

      
                    MarkerLayer(markers: _busMarkers),

  
                    if (startPoint != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: startPoint!,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.green,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    if (endPoint != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: endPoint!,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.flag,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                if (isLoading)
                  Positioned.fill(
                    child: AbsorbPointer(
                      absorbing: true,
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blueAccent.withOpacity(0.15),
                                Colors.indigo.withOpacity(0.25),
                                Colors.black.withOpacity(0.45),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 32,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.25),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blueAccent.withOpacity(0.2),
                                    blurRadius: 25,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        SizedBox(
                                          height: 80,
                                          width: 80,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 6,
                                            value: progress, 
                                            backgroundColor: Colors.white24,
                                            color: Colors.lightBlueAccent,
                                          ),
                                        ),
                                        Text(
                                          "${(progress * 100).clamp(0, 100).toInt()}%",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    const Text(
                                      "🚌 En iyi rotalar hazırlanıyor...",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      randomTip,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 15,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 8,
                                        backgroundColor: Colors.white10,
                                        color: Colors.lightBlueAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                if (suggestedOptions.isNotEmpty)
                  Positioned(
                    top: 15,
                    right: 15,
                    child: _buildGlassButton(
                      icon: Icons.list_alt_rounded,
                      text: "Önerilere Geri Dön",
                      color: const Color.fromARGB(255, 34, 57, 187),
                      onTap: () =>
                          _showOptionsDialog(context, suggestedOptions),
                    ),
                  ),
                if (suggestedOptions.isNotEmpty)
                  Positioned(
                    top: 80,
                    right: 15,
                    child: _buildGlassButton(
                      icon: Icons.refresh_rounded,
                      text: "Yeni Rota Önerisi",
                      color: const Color.fromARGB(255, 255, 50, 50),
                      onTap: _resetRouteState,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
floatingActionButton: isRouteMode
    ? null
    : Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (suggestedLine == null && !showTaxiStands)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FloatingActionButton.extended(
                heroTag: "btn_taxi",
                onPressed: () {
                  setState(() => showTaxiStands = true);
                  _updateTaxiStandMarkers();
                  _showTaxiSelector();
                },
                backgroundColor: const Color(0xFFFF6F00),
                icon: const Icon(Icons.local_taxi, color: Colors.white),
                label: const Text(
                  "Taksi Bul",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

 
          if (showTaxiStands && suggestedLine == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FloatingActionButton(
                heroTag: "btn_close_taxi",
                onPressed: () {
                  setState(() {
                    showTaxiStands = false;
                    selectedTaxiStand = null;
                    _taxiStandMarkers = [];
                  });
                },
                backgroundColor: Colors.red,
                child: const Icon(Icons.close, color: Colors.white),
              ),
            ),

  
          if (suggestedLine != null) ...[
  
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FloatingActionButton(
                heroTag: "btn_swap",
                onPressed: _toggleDirection,
                backgroundColor: Colors.orangeAccent,
                child: const Icon(
                  Icons.swap_vert_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),

            FloatingActionButton(
              heroTag: "btn_close",
              onPressed: _clearSelectedLine,
              backgroundColor: Colors.red,
              child: const Icon(Icons.close, color: Colors.white, size: 28),
            ),
          ]

          else if (!showTaxiStands)
            FloatingActionButton.extended(
              heroTag: "btn_select",
              onPressed: _showLineSelector,
              backgroundColor: Colors.blueAccent,
              icon: const Icon(Icons.directions_bus, color: Colors.white),
              label: const Text(
                "Hat Seç",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Widget _buildGlassButton({
  required IconData icon,
  required String text,
  required Color color,
  required VoidCallback onTap,
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(25),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.50),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white.withOpacity(0.7)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(25),
          splashColor: Colors.white24,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 2,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class SearchLocationField extends StatefulWidget {
  final String hintText;
  final VoidCallback onFocus;
  final void Function(double lat, double lng) onSelected;
  final bool showCurrentLocationOption;
  final TextEditingController? controller; 

  const SearchLocationField({
    super.key,
    required this.hintText,
    required this.onSelected,
    required this.onFocus,
    this.showCurrentLocationOption = false,
    this.controller, 
  });

  @override
  State<SearchLocationField> createState() => _SearchLocationFieldState();
}

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

class _SearchLocationFieldState extends State<SearchLocationField> {
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  late final TextEditingController _localController;

  @override
  void initState() {
    super.initState();
    _localController = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (widget.controller == null) _localController.dispose();
    super.dispose();
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _results = [];

        if (widget.showCurrentLocationOption) {
          _results.add({
            "display": "Konumunuz",
            "lat": null,
            "lon": null,
            "isCurrentLocation": true,
          });
        }
      });
      return;
    }

    setState(() => _loading = true);

    final encodedQuery = Uri.encodeComponent(query);
    const apiKey =
        "";
    final url = Uri.parse(
      "https://maps.googleapis.com/maps/api/place/textsearch/json?query=$encodedQuery&key=$apiKey",
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data["status"] == "OK") {
        final results = data["results"] as List;
        setState(() {
          _results = results
              .map(
                (e) => {
                  "display": e["name"],
                  "lat": e["geometry"]["location"]["lat"],
                  "lon": e["geometry"]["location"]["lng"],
                },
              )
              .toList();
        });
      } else {
        setState(() => _results = []);
      }
    }

    setState(() => _loading = false);
  }

  final Distance _dist = const Distance();
  List<Map<String, dynamic>> _allStops = [];


  @override
  Widget build(BuildContext context) {

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _localController, 
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixIcon: Icon(
                Icons.search,
                color: Colors.grey.shade500,
                size: 22,
              ),
              hintStyle: TextStyle(
                color: Colors.grey.shade900,
                fontWeight: FontWeight.w400,
                fontFamily: 'ProductSans',
              ),

              border:
                  InputBorder.none, 
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: true,
              fillColor: Colors.white.withOpacity(
                0.15,
              ), 
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),

            onChanged: _searchPlaces,
            onTap: () {
              widget.onFocus();
              _searchPlaces(
                "",
              ); 
            },
            onSubmitted: (value) async {
              if (value.isEmpty) return;

       
              final encodedQuery = Uri.encodeComponent(value);
              const apiKey =
                  ""; 
              final url = Uri.parse(
                "https://maps.googleapis.com/maps/api/place/textsearch/json?query=$encodedQuery&key=$apiKey",
              );

              final response = await http.get(url);
              if (response.statusCode == 200) {
                final data = jsonDecode(response.body);
                if (data["results"] != null && data["results"].isNotEmpty) {
                  final loc = data["results"][0]["geometry"]["location"];
                  final lat = loc["lat"];
                  final lon = loc["lng"];

                  widget.onSelected(lat, lon);
                  _localController.text = data["results"][0]["name"];
                  setState(() => _results.clear());

      
                  if (widget.hintText.contains("Nereye")) {
                    Future.delayed(const Duration(milliseconds: 300), () async {
                   
                      final state = context
                          .findAncestorStateOfType<_RoutePageState>();
                      if (state?.startPoint != null &&
                          state?.endPoint != null) {
                        await state!._calculateRoutesAndShowDialog();
                      }
                    });
                  }
                }
              }
            },
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_results.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(
                0.15,
              ), 
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.transparent,
              ), 
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06), 
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.blue.withOpacity(
                    0.03,
                  ), 
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),

            

            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final item = _results[index];


          if (item["isCurrentLocation"] == true) {
  return ListTile(
    leading: const Icon(Icons.my_location, color: Colors.blue),
    title: Text(item["display"]),
    onTap: () async {

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      widget.onSelected(pos.latitude, pos.longitude);
      _localController.text = "Mevcut konumunuz";
      setState(() => _results.clear());
    },
  );
}
              
                return ListTile(
                  title: Text(
                    item["display"],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () async {
                    double lat = item["lat"];
                    double lon = item["lon"];
                    final snapUrl = Uri.parse(
                      "https://ellyn-uncounteracted-semirebelliously.ngrok-free.dev/nearest/v1/walking/$lon,$lat",
                    );

                    final snapResponse = await http.get(snapUrl);
                    if (snapResponse.statusCode == 200) {
                      final data = jsonDecode(snapResponse.body);
                      if (data["waypoints"] != null &&
                          data["waypoints"].isNotEmpty) {
                        final snapped = data["waypoints"][0]["location"];
                        lon = snapped[0];
                        lat = snapped[1];
                        print("📍 snapped to road: $lat, $lon");
                      }
                    }

                    widget.onSelected(lat, lon);
                    _localController.text = item["display"];
                    setState(() => _results.clear());
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

class _BillboardTitle extends StatefulWidget {
  const _BillboardTitle();

  @override
  State<_BillboardTitle> createState() => _BillboardTitleState();
}

class _BillboardTitleState extends State<_BillboardTitle> {
  int _index = 0;
  Timer? _timer;

  final List<String> _messages = [
    "Rota Öneri Sistemi",
    "Senin Sehrin, Senin Rehberin.",
    "Erzurum Büyüksehir Belediyesi",
  ];

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(milliseconds: 3500), (timer) {
      if (mounted) {
        setState(() {
          _index = (_index + 1) % _messages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(
          0.95,
        ), 
        borderRadius: BorderRadius.circular(12), 
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
       
          Image.asset(
            "assets/icons/erzbblogoformain.png",
            height: 28,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 12), 
 
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
     
              transitionBuilder: (Widget child, Animation<double> animation) {
                return SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0.0, 1.0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutBack,
                        ),
                      ),
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: Text(
                _messages[_index],
                key: ValueKey<String>(_messages[_index]),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'ProductSans', 
                  color: Color(0xFF1A237E), 
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.4, 
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
