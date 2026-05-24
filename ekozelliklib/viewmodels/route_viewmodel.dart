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
import '../data/bus_stop_sequences.dart';
import '../services/bus_simulator.dart';
import '../core/utils/stop_utils.dart';

// Railway.app backend base URL
const String _kRailwayBaseUrl =
    "https://taksiappbackendnet-production.up.railway.app";
const String _kHubUrl = "$_kRailwayBaseUrl/taxiHub";

class RouteViewModel extends ChangeNotifier {
  final Map<String, List<LatLng>> busLines = {};
  // Durak seviyesinde veriler — routing hesaplamaları için
  final Map<String, List<LatLng>> busStopLines = {};
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

    const String baseUrl = "https://router.project-osrm.org";
    // OSRM public API: "walking" profili "foot" olarak geçer
    final String osrmMode = mode == "walking" ? "foot" : mode;

    final url =
        "$baseUrl/route/v1/$osrmMode/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson";

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
      "B3Dogru": B3Dogru,
      "B3_Gidis": B3_Gidis,
      "B3_Donus": B3_Donus,
      "B7_Gidis": B7_Gidis,
      "B7_Donus": B7_Donus,
      "B8Dogru": B8Dogru,
      "D1Dogru": D1Dogru,
      "D2Dogru": D2Dogru,
      "G1_Gidis": G1_Gidis,
      "G1_Donus": G1_Donus,
      "G1A_Gidis": G1A_Gidis,
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
      "M2Dogru": M2Dogru,
      "M10Dogru": M10Dogru,
      "M11_Gidis": M11_Gidis,
      "M11_Donus": M11_Donus,
      "M16Dogru": M16Dogru,
    };

    if (map.containsKey(lineName)) {
      busLines[lineName] = map[lineName]!;
    } else {
      print("⚠️ Hat bulunamadı: $lineName");
    }
  }

  /// Routing hesaplamaları için durak seviyesinde verileri yükler.
  void ensureBusStopLineLoaded(String lineName) {
    if (busStopLines.containsKey(lineName)) return;

    final map = {
      "A1_Gidis": stops_A1_Gidis,
      "A1_Donus": stops_A1_Donus,
      "B1_Gidis": stops_B1_Gidis,
      "B1_Donus": stops_B1_Donus,
      "B2_Gidis": stops_B2_Gidis,
      "B2_Donus": stops_B2_Donus,
      "B2A_Gidis": stops_B2A_Gidis,
      "B2A_Donus": stops_B2A_Donus,
      "B3Dogru": stops_B3Dogru,
      "B3_Gidis": stops_B3_Gidis,
      "B3_Donus": stops_B3_Donus,
      "B7_Gidis": stops_B7_Gidis,
      "B7_Donus": stops_B7_Donus,
      "B8Dogru": stops_B8Dogru,
      "D1Dogru": stops_D1Dogru,
      "D2Dogru": stops_D2Dogru,
      "G1_Gidis": stops_G1_Gidis,
      "G1_Donus": stops_G1_Donus,
      "G1A_Gidis": stops_G1A_Gidis,
      "G2_Gidis": stops_G2_Gidis,
      "G2_Donus": stops_G2_Donus,
      "G3_Gidis": stops_G3_Gidis,
      "G3_Donus": stops_G3_Donus,
      "G4_Gidis": stops_G4_Gidis,
      "G4_Donus": stops_G4_Donus,
      "G4A_Gidis": stops_G4A_Gidis,
      "G4A_Donus": stops_G4A_Donus,
      "G4B_Gidis": stops_G4B_Gidis,
      "G4B_Donus": stops_G4B_Donus,
      "G5_Gidis": stops_G5_Gidis,
      "G5_Donus": stops_G5_Donus,
      "G6_Gidis": stops_G6_Gidis,
      "G6_Donus": stops_G6_Donus,
      "G7_Gidis": stops_G7_Gidis,
      "G7_Donus": stops_G7_Donus,
      "G7A_Gidis": stops_G7A_Gidis,
      "G7A_Donus": stops_G7A_Donus,
      "G8_Gidis": stops_G8_Gidis,
      "G8_Donus": stops_G8_Donus,
      "G9_Gidis": stops_G9_Gidis,
      "G9_Donus": stops_G9_Donus,
      "G10_Gidis": stops_G10_Gidis,
      "G10_Donus": stops_G10_Donus,
      "G11_Gidis": stops_G11_Gidis,
      "G11_Donus": stops_G11_Donus,
      "G14_Gidis": stops_G14_Gidis,
      "G14_Donus": stops_G14_Donus,
      "K1_Gidis": stops_K1_Gidis,
      "K1_Donus": stops_K1_Donus,
      "K1A_Gidis": stops_K1A_Gidis,
      "K1A_Donus": stops_K1A_Donus,
      "K2_Gidis": stops_K2_Gidis,
      "K2_Donus": stops_K2_Donus,
      "K3_Gidis": stops_K3_Gidis,
      "K3_Donus": stops_K3_Donus,
      "K4_Gidis": stops_K4_Gidis,
      "K4_Donus": stops_K4_Donus,
      "K5_Gidis": stops_K5_Gidis,
      "K5_Donus": stops_K5_Donus,
      "K6_Gidis": stops_K6_Gidis,
      "K6_Donus": stops_K6_Donus,
      "K7_Gidis": stops_K7_Gidis,
      "K7_Donus": stops_K7_Donus,
      "K7A_Gidis": stops_K7A_Gidis,
      "K7A_Donus": stops_K7A_Donus,
      "K10_Gidis": stops_K10_Gidis,
      "K10_Donus": stops_K10_Donus,
      "K11_Gidis": stops_K11_Gidis,
      "K11_Donus": stops_K11_Donus,
      "M2Dogru": stops_M2Dogru,
      "M10Dogru": stops_M10Dogru,
      "M11_Gidis": stops_M11_Gidis,
      "M11_Donus": stops_M11_Donus,
      "M16Dogru": stops_M16Dogru,
    };

    if (map.containsKey(lineName)) {
      busStopLines[lineName] = map[lineName]!;
    } else {
      print("⚠️ Durak verisi bulunamadı: $lineName");
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
        // Küçük tie-breaker: durak sayısı yürüyüş mesafesini geçersiz kılmamalı
        final busScore = (eIdx - sIdx).toDouble();
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

  /// Durak listesinde start→end arasındaki segmenti döndürür.
  /// indexOf yerine en yakın nokta araması kullanır — daha sağlam.
  List<LatLng> segmentBetween(List<LatLng> line, LatLng start, LatLng end) {
    if (line.isEmpty) return [];
    final distance = const Distance();

    int startIdx = 0;
    double bestStart = double.infinity;
    for (int i = 0; i < line.length; i++) {
      final d = distance(start, line[i]);
      if (d < bestStart) {
        bestStart = d;
        startIdx = i;
      }
    }

    int endIdx = line.length - 1;
    double bestEnd = double.infinity;
    for (int i = startIdx; i < line.length; i++) {
      final d = distance(end, line[i]);
      if (d < bestEnd) {
        bestEnd = d;
        endIdx = i;
      }
    }

    if (startIdx >= endIdx) return [line[startIdx]];
    return line.sublist(startIdx, endIdx + 1);
  }

  /// Yol geometrisinden (road polyline), iki durak koordinatına en yakın
  /// noktalar arasındaki alt segmenti çıkarır (harita gösterimi için).
  List<LatLng> extractRoadSegment(
    List<LatLng> roadLine,
    LatLng startStop,
    LatLng endStop,
  ) {
    if (roadLine.isEmpty) return [];
    if (roadLine.length <= 1) return roadLine;
    final distance = const Distance();

    int startIdx = 0;
    double bestStart = double.infinity;
    for (int i = 0; i < roadLine.length; i++) {
      final d = distance(startStop, roadLine[i]);
      if (d < bestStart) {
        bestStart = d;
        startIdx = i;
      }
    }

    int endIdx = roadLine.length - 1;
    double bestEnd = double.infinity;
    for (int i = startIdx; i < roadLine.length; i++) {
      final d = distance(endStop, roadLine[i]);
      if (d < bestEnd) {
        bestEnd = d;
        endIdx = i;
      }
    }

    if (startIdx >= endIdx) {
      // Yol geometrisinde startStop, endStop'tan sonra görünüyor —
      // bu olmamalı ama olduysa tüm kalan segmenti döndür
      return roadLine.sublist(startIdx);
    }
    return roadLine.sublist(startIdx, endIdx + 1);
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

  /// Railway.app backend'i uyandırmak için önce ping atar.
  Future<void> _pingBackend() async {
    try {
      await http
          .get(Uri.parse("$_kRailwayBaseUrl/health"))
          .timeout(const Duration(seconds: 8));
      print("✅ Backend ping başarılı");
    } catch (e) {
      print("⚠️ Backend ping timeout (uyku modunda olabilir): $e");
    }
  }

  void _registerHubHandlers({
    required Function(String driverName, String plate) onAccepted,
    required Function() onRejected,
  }) {
    hubConnection!.off("TaxiAccepted");
    hubConnection!.off("TaxiRejected");
    hubConnection!.on("TaxiAccepted", (args) {
      final data = Map<String, dynamic>.from(args?[0] as Map);
      if (data['requestId'] == waitingRequestId) {
        waitingRequestId = null;
        onAccepted(data['driverName']?.toString() ?? '-', data['plate']?.toString() ?? '-');
      }
    });
    hubConnection!.on("TaxiRejected", (args) {
      final data = Map<String, dynamic>.from(args?[0] as Map);
      if (data['requestId'] == waitingRequestId) {
        waitingRequestId = null;
        onRejected();
      }
    });
  }

  Future<void> connectSignalR({
    required Function(String driverName, String plate) onAccepted,
    required Function() onRejected,
  }) async {
    // Önce Railway.app backend'i uyandır
    await _pingBackend();

    // WebSocket ile dene (skipNegotiation — Railway.app için gerekli)
    try {
      hubConnection = HubConnectionBuilder()
          .withUrl(
            _kHubUrl,
            HttpConnectionOptions(
              transport: HttpTransportType.webSockets,
              skipNegotiation: true,
            ),
          )
          .withAutomaticReconnect([0, 2000, 5000, 10000])
          .build();

      _registerHubHandlers(onAccepted: onAccepted, onRejected: onRejected);
      await hubConnection!.start();
      signalRConnected = true;
      print("✅ SignalR (WebSocket) bağlandı");
    } catch (e) {
      print("❌ SignalR WebSocket hatası: $e — LongPolling ile deneniyor...");
      // Fallback: LongPolling
      try {
        hubConnection = HubConnectionBuilder()
            .withUrl(
              _kHubUrl,
              HttpConnectionOptions(
                transport: HttpTransportType.longPolling,
              ),
            )
            .withAutomaticReconnect([0, 2000, 5000, 10000])
            .build();

        _registerHubHandlers(onAccepted: onAccepted, onRejected: onRejected);
        await hubConnection!.start();
        signalRConnected = true;
        print("✅ SignalR (LongPolling) bağlandı");
      } catch (e2) {
        print("❌ SignalR LongPolling de başarısız: $e2");
      }
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
    // Aktarma noktası için iki hattın birbirine yakınlık eşiği (metre)
    // 40m çok dar — gerçek durak yakınlığı 100-200m olabilir
    const double XFER_NEAR = 120;
    const int MAX_DIRECT = 2;
    const int MAX_TRANSFER = 4;

    final allNames = [
      "A1_Gidis",
      "A1_Donus",
      "B1_Gidis",
      "B1_Donus",
      "B2_Gidis",
      "B2_Donus",
      "B2A_Gidis",
      "B2A_Donus",
      "B3Dogru",
      "B3_Gidis",
      "B3_Donus",
      "B7_Gidis",
      "B7_Donus",
      "B8Dogru",
      "D1Dogru",
      "D2Dogru",
      "G1_Gidis",
      "G1_Donus",
      "G1A_Gidis",
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
      "M2Dogru",
      "M10Dogru",
      "M11_Gidis",
      "M11_Donus",
      "M16Dogru",
    ];

    final stopwatch = Stopwatch()..start();

    // ─── Hat yükleme + yakın hat filtreleme (durak verisi üzerinden) ───
    final Set<String> startNearby = {};
    final Set<String> endNearby = {};

    for (int i = 0; i < allNames.length; i++) {
      ensureBusLineLoaded(allNames[i]);
      ensureBusStopLineLoaded(allNames[i]);
      if (i % 2 == 0) await Future.delayed(Duration.zero);

      // Filtreleme için durak verisi kullanılır (10-80 nokta, hızlı)
      final stopLine = busStopLines[allNames[i]];
      if (stopLine == null || stopLine.isEmpty) continue;

      if (stopLine.any((p) => dist(startPoint, p) < NEAR_STOP)) {
        startNearby.add(allNames[i]);
      }
      if (stopLine.any((p) => dist(endPoint, p) < NEAR_STOP)) {
        endNearby.add(allNames[i]);
      }
    }

    final List<RouteOption> options = [];

    // ─── Yürüyüş seçeneği (1km altı) ───
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

    // ─── Direkt otobüs rotaları ───
    for (final name in startNearby.intersection(endNearby).take(MAX_DIRECT)) {
      if (stopwatch.elapsed.inSeconds > maxSeconds) break;

      // Routing: durak verisi (az nokta, doğru skor)
      final stopLine = busStopLines[name]!;
      final bestSegment = findBestSegment(startPoint, endPoint, stopLine, name);
      if (bestSegment == null) continue;

      // Display: yol geometrisi (düzgün çizgi)
      final roadLine = busLines[name]!;
      final busDisplay = extractRoadSegment(
        roadLine,
        bestSegment.startPoint,
        bestSegment.endPoint,
      );

      // Yürüyüş: kuşbakışı düz çizgi — OSRM'nin saçma detour'larını önler
      final walk1 = [startPoint, bestSegment.startPoint];
      final walk2 = [bestSegment.endPoint, endPoint];

      final total =
          polylineLength(walk1) +
          polylineLength(busDisplay) +
          polylineLength(walk2);

      options.add(
        RouteOption(
          lineName: name,
          walk1: walk1,
          bus1: busDisplay,
          walk2: walk2,
          totalDistance: total,
          isTransfer: false,
          startStopName: StopUtils.stopNameFromLatLng(bestSegment.startPoint),
          endStopName: StopUtils.stopNameFromLatLng(bestSegment.endPoint),
        ),
      );
      onProgress(0.25);
    }

    // ─── Aktarmalı rotalar ───
    int transferCount = 0;
    for (final sName in startNearby) {
      if (transferCount >= MAX_TRANSFER ||
          stopwatch.elapsed.inSeconds > maxSeconds) break;
      for (final eName in endNearby) {
        if (transferCount >= MAX_TRANSFER ||
            stopwatch.elapsed.inSeconds > maxSeconds) break;
        if (sName == eName) continue;

        // Routing: durak verisi üzerinden kesişim bul
        final sStopLine = busStopLines[sName]!;
        final eStopLine = busStopLines[eName]!;
        final xPoint = findIntersectionPoint(
          sStopLine,
          eStopLine,
          distance: dist,
          threshold: XFER_NEAR,
        );
        if (xPoint == null) continue;

        // 1. Hat üzerinde başlangıca en yakın durak (yön: endPoint'e doğru)
        final ns = findNearestStop(startPoint, endPoint, sStopLine);

        // ns'nin hat listesindeki indexini bul
        int nsIdx = 0;
        {
          double _best = double.infinity;
          for (int i = 0; i < sStopLine.length; i++) {
            final d = dist(ns, sStopLine[i]);
            if (d < _best) { _best = d; nsIdx = i; }
          }
        }

        // nt1: 1. hatta aktarma durağı — ns'den SONRA xPoint'e en yakın durak
        LatLng nt1 = sStopLine[nsIdx];
        {
          double _best = double.infinity;
          for (int i = nsIdx; i < sStopLine.length; i++) {
            final d = dist(xPoint, sStopLine[i]);
            if (d < _best) { _best = d; nt1 = sStopLine[i]; }
          }
        }

        // nt2: 2. hatta aktarma noktasına en yakın durak (yön: endPoint'e doğru)
        final nt2 = findNearestStop(xPoint, endPoint, eStopLine);

        // nt2'nin hat listesindeki indexini bul
        int nt2Idx = 0;
        {
          double _best = double.infinity;
          for (int i = 0; i < eStopLine.length; i++) {
            final d = dist(nt2, eStopLine[i]);
            if (d < _best) { _best = d; nt2Idx = i; }
          }
        }

        // ne: 2. hatta varış durağı — nt2'den SONRA endPoint'e en yakın durak
        LatLng ne = eStopLine[nt2Idx];
        {
          double _best = double.infinity;
          for (int i = nt2Idx; i < eStopLine.length; i++) {
            final d = dist(endPoint, eStopLine[i]);
            if (d < _best) { _best = d; ne = eStopLine[i]; }
          }
        }

        // Yürüyüş segmentleri: kuşbakışı düz çizgi
        final walkToBoard = [startPoint, ns];
        final walkTransfer = [nt1, nt2];
        final walkToEnd = [ne, endPoint];

        // Display: yol geometrisinden ilgili segmentleri çıkar
        final bus1 = extractRoadSegment(busLines[sName]!, ns, nt1);
        final bus2 = extractRoadSegment(busLines[eName]!, nt2, ne);

        final total =
            polylineLength(walkToBoard) +
            polylineLength(bus1) +
            polylineLength(walkTransfer) +
            polylineLength(bus2) +
            polylineLength(walkToEnd);

        options.add(
          RouteOption(
            lineName: sName,
            transferLine: eName,
            walk1: walkToBoard,
            bus1: bus1,
            walkTransfer: walkTransfer,
            bus2: bus2,
            walk2: walkToEnd,
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
      }
    }

    // ─── Araç rotası ───
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

    // ─── Taksi seçenekleri ───
    try {
      final taxiOptions = await calculateTaxiOptions(startPoint, endPoint);
      options.addAll(taxiOptions);
    } catch (_) {}

    stopwatch.stop();

    // Yürüyüş mesafesini 2.5x ağırlıklandır — az yürüyüş daha iyi
    double _weightedScore(RouteOption o) {
      final walkDist =
          polylineLength(o.walk1) +
          polylineLength(o.walk2) +
          polylineLength(o.walkTransfer);
      final busDist = polylineLength(o.bus1) + polylineLength(o.bus2);
      return busDist + walkDist * 2.5;
    }

    options.sort((a, b) => _weightedScore(a).compareTo(_weightedScore(b)));
    return options.take(MAX_DIRECT + MAX_TRANSFER + 3).toList();
  }

  void dispose() {
    hubConnection?.stop();
    super.dispose();
  }
}
