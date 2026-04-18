import 'dart:async';
import 'dart:convert';
import 'dart:math' show sin, cos, atan2;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:signalr_core/signalr_core.dart';
import 'package:uuid/uuid.dart';

import '../models/route_option.dart';
import '../models/taxi_stand.dart'; 
import '../models/segment_result.dart'; 
import '../data/taxi_stands.dart';
import '../data/generated_polylines.dart';
import '../services/bus_simulator.dart';
import '../core/utils/stop_utils.dart';

class RouteViewModel extends ChangeNotifier {
  final Map<String, List<LatLng>> busLines = {};
  final BusSimulationManager? simulationManager;

  HubConnection? hubConnection;
  bool signalRConnected = false;
  String? waitingRequestId;

  RouteViewModel({this.simulationManager});
  Future<List<LatLng>> getRoute(
    LatLng start,
    LatLng end, {
    String mode = "driving",
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final baseUrl = (mode == "walking")
        ? "https://ellyn-uncounteracted-semirebelliously.ngrok-free.dev"
        : "https://superelastic-rylee-tetramerous.ngrok-free.dev";

    final url =
        "$baseUrl/route/v1/$mode/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson";

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List coords = data["routes"][0]["geometry"]["coordinates"];
        return coords.map((c) => LatLng(c[1], c[0])).toList();
      }
      return [];
    } catch (e) {
      print("❌ Rota isteği başarısız ($mode): $e");
      return [];
    }
  }

  Future<Position> getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return _fallbackErzurum();

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return _fallbackErzurum();
    }
    if (permission == LocationPermission.deniedForever)
      return _fallbackErzurum();

    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      if (pos.latitude == 0.0 && pos.longitude == 0.0)
        return _fallbackErzurum();
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

  void ensureBusLineLoaded(String lineName) {
    if (busLines.containsKey(lineName)) return;

    final map = {
      "A1_Gidis": A1_Gidis,
      "A1_Donus": A1_Donus,
      "B1_Gidis": B1_Gidis,
      "B1_Donus": B1_Donus,
      "B2_Gidis": B2_Gidis,
      "B2_Donus": B2_Donus,
      "B2A_Gidis": B2A_Gidis,
      "B2A_Donus": B2A_Donus,
      "B3_Gidis": B3_Gidis,
      "B3_Donus": B3_Donus,
      "G1_Gidis": G1_Gidis,
      "G1_Donus": G1_Donus,
      "G2_Gidis": G2_Gidis,
      "G2_Donus": G2_Donus,
      "G3_Gidis": G3_Gidis,
      "G3_Donus": G3_Donus,
      "G4_Gidis": G4_Gidis,
      "G4_Donus": G4_Donus,
      "G4A_Gidis": G4A_Gidis,
      "G4A_Donus": G4A_Donus,
      "G4B_Gidis": G4B_Gidis,
      "G4B_Donus": G4B_Donus,
      "G5_Gidis": G5_Gidis,
      "G5_Donus": G5_Donus,
      "G6_Gidis": G6_Gidis,
      "G6_Donus": G6_Donus,
      "G7_Gidis": G7_Gidis,
      "G7_Donus": G7_Donus,
      "G7A_Gidis": G7A_Gidis,
      "G7A_Donus": G7A_Donus,
      "G8_Gidis": G8_Gidis,
      "G8_Donus": G8_Donus,
      "G9_Gidis": G9_Gidis,
      "G9_Donus": G9_Donus,
      "G10_Gidis": G10_Gidis,
      "G10_Donus": G10_Donus,
      "G11_Gidis": G11_Gidis,
      "G11_Donus": G11_Donus,
      "G14_Gidis": G14_Gidis,
      "G14_Donus": G14_Donus,
      "K1_Gidis": K1_Gidis,
      "K1_Donus": K1_Donus,
      "K1A_Gidis": K1A_Gidis,
      "K1A_Donus": K1A_Donus,
      "K2_Gidis": K2_Gidis,
      "K2_Donus": K2_Donus,
      "K3_Gidis": K3_Gidis,
      "K3_Donus": K3_Donus,
      "K4_Gidis": K4_Gidis,
      "K4_Donus": K4_Donus,
      "K5_Gidis": K5_Gidis,
      "K5_Donus": K5_Donus,
      "K6_Gidis": K6_Gidis,
      "K6_Donus": K6_Donus,
      "K7_Gidis": K7_Gidis,
      "K7_Donus": K7_Donus,
      "K7A_Gidis": K7A_Gidis,
      "K7A_Donus": K7A_Donus,
      "K10_Gidis": K10_Gidis,
      "K10_Donus": K10_Donus,
      "K11_Gidis": K11_Gidis,
      "K11_Donus": K11_Donus,
      "M11_Gidis": M11_Gidis,
      "M11_Donus": M11_Donus,
    };

    if (map.containsKey(lineName)) {
      busLines[lineName] = map[lineName]!;
    } else {
      print("⚠️ Hat bulunamadı: $lineName");
    }
  }

  double bearing(LatLng a, LatLng b) {
    final dLon = (b.longitude - a.longitude) * pi / 180;
    final y = sin(dLon) * cos(b.latitude * pi / 180);
    final x =
        cos(a.latitude * pi / 180) * sin(b.latitude * pi / 180) -
        sin(a.latitude * pi / 180) * cos(b.latitude * pi / 180) * cos(dLon);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  double angleDiff(double a, double b) {
    final diff = (a - b).abs();
    return diff > 180 ? 360 - diff : diff;
  }

  double polylineLength(List<LatLng> pts) {
    final d = const Distance();
    double sum = 0;
    for (int i = 0; i < pts.length - 1; i++) {
      sum += d(pts[i], pts[i + 1]);
    }
    return sum;
  }

  LatLng? findIntersectionPoint(
    List<LatLng> a,
    List<LatLng> b, {
    required Distance distance,
    double threshold = 80,
  }) {
    LatLng? best;
    double bestScore = double.infinity;

    for (int i = 0; i < a.length - 1; i++) {
      final dirA = bearing(a[i], a[i + 1]);
      for (int j = 0; j < b.length - 1; j++) {
        final d = distance(a[i], b[j]);
        if (d < threshold) {
          final dirB = bearing(b[j], b[j + 1]);
          final diff = angleDiff(dirA, dirB);
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

  SegmentResult? findBestSegment(
    LatLng userStart,
    LatLng userEnd,
    List<LatLng> linePoints,
    String lineName,
  ) {
    final distance = const Distance();
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

  LatLng findNearestStop(LatLng current, LatLng target, List<LatLng> polyline) {
    final distance = const Distance();
    LatLng nearest = polyline.first;
    double bestScore = double.infinity;
    final userDir = bearing(current, target);

    for (int i = 0; i < polyline.length - 2; i++) {
      final stop = polyline[i];
      final next = polyline[i + 1];
      final next2 = polyline[i + 2];
      final d = distance(current, stop);
      final dir1 = bearing(stop, next);
      final dir2 = bearing(next, next2);
      final avgDir = (dir1 + dir2) / 2;
      final diff = angleDiff(userDir, avgDir);
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

  List<LatLng> segmentBetween(List<LatLng> line, LatLng start, LatLng end) {
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

  Future<List<RouteOption>> calculateTaxiOptions(
    LatLng startPoint,
    LatLng endPoint,
  ) async {
    final dist = const Distance();
    final List<RouteOption> taxiOptions = [];
    final nearbyStands = TaxiStandUtils.findNearbyTaxiStands(startPoint, 3000);

    if (nearbyStands.isEmpty) return [];

    nearbyStands.sort(
      (a, b) =>
          dist(startPoint, a.location).compareTo(dist(startPoint, b.location)),
    );

    for (final stand in nearbyStands.take(3)) {
      try {
        final walkToStand = await getRoute(
          startPoint,
          stand.location,
          mode: "walking",
        );
        final taxiRoute = await getRoute(
          stand.location,
          endPoint,
          mode: "driving",
        );
        if (walkToStand.isEmpty || taxiRoute.isEmpty) continue;

        final walkDistance = polylineLength(walkToStand);
        final taxiDistance = polylineLength(taxiRoute);
        final fare = TaxiStandUtils.calculateEstimatedFare(taxiDistance);

        taxiOptions.add(
          RouteOption(
            lineName: "Taksi (${stand.name})",
            walk1: walkToStand,
            bus1: taxiRoute,
            walk2: [],
            totalDistance: walkDistance + taxiDistance,
            isTransfer: false,
            isTaxi: true,
            taxiStand: stand,
            estimatedFare: fare,
            startStopName: stand.address,
            endStopName: "Varış Noktası",
          ),
        );
      } catch (e) {
        print("Taksi rotası hesaplanamadı (${stand.name}): $e");
      }
    }
    return taxiOptions;
  }

  Future<void> connectSignalR({
    required Function(String driverName, String plate) onAccepted,
    required Function() onRejected,
  }) async {
    try {
      hubConnection = HubConnectionBuilder()
          .withUrl("https://jannette-acrogynous-allene.ngrok-free.dev/taxiHub")
          .withAutomaticReconnect()
          .build();

      hubConnection!.off("TaxiAccepted");
      hubConnection!.off("TaxiRejected");

      hubConnection!.on("TaxiAccepted", (args) {
        final data = Map<String, dynamic>.from(args?[0] as Map);
        if (data['requestId'] == waitingRequestId) {
          waitingRequestId = null;
          onAccepted(data['driverName'] ?? '-', data['plate'] ?? '-');
        }
      });

      hubConnection!.on("TaxiRejected", (args) {
        final data = Map<String, dynamic>.from(args?[0] as Map);
        if (data['requestId'] == waitingRequestId) {
          waitingRequestId = null;
          onRejected();
        }
      });

      await hubConnection!.start();
      signalRConnected = true;
      print("✅ SignalR bağlandı");
    } catch (e) {
      print("❌ SignalR bağlantı hatası: $e");
    }
  }

  Future<void> requestTaxi({
    required TaxiStand stand,
    required LatLng startPoint,
    LatLng? endPoint,
    required double fare,
  }) async {
    final requestId = const Uuid().v4();
    waitingRequestId = requestId;

    await hubConnection!.invoke(
      "RequestTaxi",
      args: [
        {
          "requestId": requestId,
          "userId": "anonymous",
          "taxiStandId": stand.id,
          "fromLat": startPoint.latitude,
          "fromLng": startPoint.longitude,
          "toLat": endPoint?.latitude ?? startPoint.latitude,
          "toLng": endPoint?.longitude ?? startPoint.longitude,
          "estimatedFare": fare,
          "status": "Pending",
        },
      ],
    );
  }

  Future<List<RouteOption>> calculateRoutes({
    required LatLng startPoint,
    required LatLng endPoint,
    required Function(double progress) onProgress,
    required int maxSeconds,
  }) async {
    final dist = const Distance();
    final double directDistance = dist(startPoint, endPoint);
    const double NEAR_STOP = 400;
    const double XFER_NEAR = 40;
    const int MAX_DIRECT = 2;
    const int MAX_TRANSFER = 4;

    final allLineNames = busLines.keys.toList();
    final allNames = [
      "A1_Gidis",
      "A1_Donus",
      "B1_Gidis",
      "B1_Donus",
      "B2_Gidis",
      "B2_Donus",
      "B2A_Gidis",
      "B2A_Donus",
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

    final stopwatch = Stopwatch()..start();
    final List<MapEntry<String, List<LatLng>>> nearby = [];

    for (int i = 0; i < allNames.length; i++) {
      ensureBusLineLoaded(allNames[i]);
      if (i % 2 == 0) await Future.delayed(Duration.zero);
      final line = busLines[allNames[i]];
      if (line == null || line.isEmpty) continue;
      final nearS = line.any((p) => dist(startPoint, p) < NEAR_STOP);
      final nearE = line.any((p) => dist(endPoint, p) < NEAR_STOP);
      if (nearS || nearE) nearby.add(MapEntry(allNames[i], line));
    }

    final startNearby = nearby
        .where((e) => e.value.any((p) => dist(startPoint, p) < NEAR_STOP))
        .map((e) => e.key)
        .toSet();
    final endNearby = nearby
        .where((e) => e.value.any((p) => dist(endPoint, p) < NEAR_STOP))
        .map((e) => e.key)
        .toSet();

    final List<RouteOption> options = [];

    if (directDistance < 1000) {
      final walkOnly = await getRoute(startPoint, endPoint, mode: "walking");
      options.add(
        RouteOption(
          lineName: "Yürüyüş (Kısa Mesafe)",
          walk1: walkOnly,
          bus1: [],
          walk2: [],
          totalDistance: polylineLength(walkOnly),
          isTransfer: false,
          startStopName: "Başlangıç",
          endStopName: "Varış",
        ),
      );
    }

    for (final name in startNearby.intersection(endNearby).take(MAX_DIRECT)) {
      if (stopwatch.elapsed.inSeconds > maxSeconds) break;
      final line = busLines[name]!;
      final bestSegment = findBestSegment(startPoint, endPoint, line, name);
      if (bestSegment == null) continue;

      final results = await Future.wait([
        getRoute(startPoint, bestSegment.startPoint, mode: "walking"),
        getRoute(bestSegment.endPoint, endPoint, mode: "walking"),
      ]).timeout(const Duration(seconds: 5), onTimeout: () => [[], []]);

      final total =
          polylineLength(results[0]) +
          polylineLength(bestSegment.segment) +
          polylineLength(results[1]);

      options.add(
        RouteOption(
          lineName: name,
          walk1: results[0],
          bus1: bestSegment.segment,
          walk2: results[1],
          totalDistance: total,
          isTransfer: false,
          startStopName: StopUtils.stopNameFromLatLng(bestSegment.startPoint),
          endStopName: StopUtils.stopNameFromLatLng(bestSegment.endPoint),
        ),
      );
      onProgress(0.25);
    }

    int transferCount = 0;
    for (final sName in startNearby) {
      for (final eName in endNearby) {
        if (transferCount >= MAX_TRANSFER ||
            stopwatch.elapsed.inSeconds > maxSeconds)
          break;
        if (sName == eName) continue;

        final sLine = busLines[sName]!;
        final eLine = busLines[eName]!;
        final xPoint = findIntersectionPoint(
          sLine,
          eLine,
          distance: dist,
          threshold: XFER_NEAR,
        );
        if (xPoint == null) continue;

        final ns = findNearestStop(startPoint, endPoint, sLine);
        final nt1 = findNearestStop(xPoint, endPoint, sLine);
        final nt2 = findNearestStop(xPoint, endPoint, eLine);
        final ne = findNearestStop(endPoint, startPoint, eLine);

        try {
          final walks = await Future.wait([
            getRoute(startPoint, ns, mode: "walking"),
            getRoute(nt1, nt2, mode: "walking"),
            getRoute(ne, endPoint, mode: "walking"),
          ]).timeout(const Duration(seconds: 6));

          final bus1 = segmentBetween(sLine, ns, nt1);
          final bus2 = segmentBetween(eLine, nt2, ne);
          final total =
              polylineLength(walks[0]) +
              polylineLength(bus1) +
              polylineLength(walks[1]) +
              polylineLength(bus2) +
              polylineLength(walks[2]);

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
              startStopName: StopUtils.stopNameFromLatLng(ns),
              transferStopName:
                  "${StopUtils.stopNameFromLatLng(nt1)} ↔ ${StopUtils.stopNameFromLatLng(nt2)}",
              endStopName: StopUtils.stopNameFromLatLng(ne),
            ),
          );
          transferCount++;
          onProgress(0.3);
        } catch (_) {}
      }
    }

    try {
      final carRoute = await getRoute(startPoint, endPoint, mode: "driving");
      options.add(
        RouteOption(
          lineName: "Araç (Otomobil)",
          walk1: [],
          bus1: carRoute,
          walk2: [],
          totalDistance: polylineLength(carRoute),
          isTransfer: false,
        ),
      );
    } catch (_) {}

    try {
      final taxiOptions = await calculateTaxiOptions(startPoint, endPoint);
      options.addAll(taxiOptions);
    } catch (_) {}

    stopwatch.stop();
    options.sort((a, b) => a.totalDistance.compareTo(b.totalDistance));
    return options.take(MAX_DIRECT + MAX_TRANSFER + 3).toList();
  }

  void dispose() {
    hubConnection?.stop();
    super.dispose();
  }
}
