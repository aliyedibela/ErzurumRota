import 'dart:async';
import 'dart:math';
import 'package:latlong2/latlong.dart';

class SimulatedBus {
  String id;
  String lineName;
  List<LatLng> routePath;
  double cachedTotalLength;
  int durationMs; 
  int timeOffsetMs; 
  LatLng currentLocation;

  SimulatedBus({
    required this.id,
    required this.lineName,
    required this.routePath,
    required this.cachedTotalLength,
    required this.durationMs,
    required this.timeOffsetMs,
  }) : currentLocation = routePath.isNotEmpty
           ? routePath[0]
           : const LatLng(0, 0);
}

class BusSimulationManager {
  final List<SimulatedBus> activeBuses = [];
  Timer? _timer;
  final Function(List<SimulatedBus>) onUpdate;
  final Distance _dist = const Distance();
  Map<String, List<LatLng>> allRouteData = {};
  Map<String, double> _cachedRouteLengths = {};

  BusSimulationManager({required this.onUpdate});

  void setAllRoutes(Map<String, List<LatLng>> data) {
    allRouteData = data;
    _cacheRouteLengths();
  }

  void _cacheRouteLengths() {
    for (final entry in allRouteData.entries) {
      double totalLen = 0;
      final path = entry.value;
      for (int i = 0; i < path.length - 1; i++) {
        totalLen += _dist(path[i], path[i + 1]);
      }
      _cachedRouteLengths[entry.key] = totalLen;
    }
  }

  void startSimulation(String lineKey, [List<LatLng>? initialPath]) {
    if (initialPath != null) {
      allRouteData[lineKey] = initialPath;
      double totalLen = 0;
      for (int i = 0; i < initialPath.length - 1; i++) {
        totalLen += _dist(initialPath[i], initialPath[i + 1]);
      }
      _cachedRouteLengths[lineKey] = totalLen;
    }

    if (activeBuses.any((b) => b.lineName == lineKey)) return;
    _spawnBusesForDirection(lineKey);

    if (_timer == null || !_timer!.isActive) {
      _startTimer();
    }
  }

  void _spawnBusesForDirection(String key) {
    if (!allRouteData.containsKey(key)) {
      print("⚠️ $key için rota verisi henüz yok, otobüs oluşturulamadı.");
      return;
    }

    final path = allRouteData[key]!;
    final cachedLength = _cachedRouteLengths[key] ?? 0.1;

    Random random = Random(key.hashCode);
    int durationMins = 75 + random.nextInt(31); 
    int durationMs = durationMins * 60 * 1000;

    for (int i = 0; i < 3; i++) {
      int offsetMs = (durationMs ~/ 3) * i;

      activeBuses.add(
        SimulatedBus(
          id: "${key}_Bus_$i",
          lineName: key,
          routePath: path,
          cachedTotalLength: cachedLength,
          durationMs: durationMs,
          timeOffsetMs: offsetMs,
        ),
      );
    }
    print(
      "✅ $key yönü için 2 otobüs oluşturuldu. Sefer süresi: $durationMins dk",
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (activeBuses.isEmpty) return;

      int nowMs = DateTime.now().millisecondsSinceEpoch;

      for (var bus in activeBuses) {
        _updateBusPosition(bus, nowMs);
      }

      onUpdate(activeBuses);
    });
  }

  void _updateBusPosition(SimulatedBus bus, int nowMs) {
    if (bus.routePath.isEmpty) return;

    int logicalTimeMs = nowMs + bus.timeOffsetMs;


    double progress = (logicalTimeMs % bus.durationMs) / bus.durationMs;


    double targetDist = progress * bus.cachedTotalLength;


    bus.currentLocation = _getPositionAtDistance(bus.routePath, targetDist);
  }

  LatLng _getPositionAtDistance(List<LatLng> path, double targetDist) {
    if (targetDist <= 0) return path.first;

    double accumulated = 0.0;
    for (int i = 0; i < path.length - 1; i++) {
      double segLen = _dist(path[i], path[i + 1]);
      if (accumulated + segLen >= targetDist) {
        double ratio = (targetDist - accumulated) / segLen;
        double lat =
            path[i].latitude +
            (path[i + 1].latitude - path[i].latitude) * ratio;
        double lng =
            path[i].longitude +
            (path[i + 1].longitude - path[i].longitude) * ratio;
        return LatLng(lat, lng);
      }
      accumulated += segLen;
    }
    return path.last;
  }

  int? getGhostEta(
    String lineKey,
    LatLng stopLoc,
    Map<String, List<LatLng>> externalBusLines,
  ) {
    try {

      if (!allRouteData.containsKey(lineKey) &&
          externalBusLines.containsKey(lineKey)) {
        allRouteData[lineKey] = externalBusLines[lineKey]!;

        double totalLen = 0;
        final path = externalBusLines[lineKey]!;
        for (int i = 0; i < path.length - 1; i++) {
          totalLen += _dist(path[i], path[i + 1]);
        }
        _cachedRouteLengths[lineKey] = totalLen;
      }

      if (!allRouteData.containsKey(lineKey)) return null;

      final path = allRouteData[lineKey]!;
      final totalLength = _cachedRouteLengths[lineKey] ?? 0.1;

      Random random = Random(lineKey.hashCode);
      int durationMins = 75 + random.nextInt(31); 
      int durationMs = durationMins * 60 * 1000;

      double userDist = _getDistanceToPoint(path, stopLoc);
      int minEta = 9999;

      int nowMs = DateTime.now().millisecondsSinceEpoch;

      for (int i = 0; i < 3; i++) {
        int offsetMs = (durationMs ~/ 3) * i;
        int logicalTimeMs = nowMs + offsetMs;
        double progress = (logicalTimeMs % durationMs) / durationMs;

        double currentDist = progress * totalLength;

        double distRemaining;
        if (userDist >= currentDist) {
          distRemaining = userDist - currentDist; 
        } else {
          distRemaining =
              (totalLength - currentDist) + userDist; 
        }

        double speed = totalLength / durationMs;
        int etaMs = (distRemaining / speed).round();
        int etaMins = (etaMs / 1000 / 60).ceil();

        if (etaMins < minEta) {
          minEta = etaMins;
        }
      }
      return minEta;
    } catch (e) {
      return null;
    }
  }

  int? calculateEtaMinutes(String lineName, LatLng userStopLocation) {
    try {
      final buses = activeBuses.where((b) => b.lineName == lineName).toList();
      if (buses.isEmpty) return null;

      double userDist = _getDistanceToPoint(
        allRouteData[lineName]!,
        userStopLocation,
      );
      int minEta = 9999;

      for (var bus in buses) {
        int nowMs = DateTime.now().millisecondsSinceEpoch;
        int logicalTimeMs = nowMs + bus.timeOffsetMs;
        double progress = (logicalTimeMs % bus.durationMs) / bus.durationMs;
        double currentDist = progress * bus.cachedTotalLength;

        double distRemaining;
        if (userDist >= currentDist) {
          distRemaining = userDist - currentDist; 
        } else {
          distRemaining =
              (bus.cachedTotalLength - currentDist) +
              userDist; 
        }

        double speed = bus.cachedTotalLength / bus.durationMs; 
        int etaMs = (distRemaining / speed).round();
        int etaMins = (etaMs / 1000 / 60).ceil();

        if (etaMins < minEta) {
          minEta = etaMins;
        }
      }
      return minEta;
    } catch (e) {
      return null;
    }
  }

  double _getDistanceToPoint(List<LatLng> path, LatLng point) {
    int nearestIdx = 0;
    double minD = double.infinity;
    for (int i = 0; i < path.length; i++) {
      final d = _dist(point, path[i]);
      if (d < minD) {
        minD = d;
        nearestIdx = i;
      }
    }
    double dist = 0.0;
    for (int i = 0; i < nearestIdx; i++) {
      dist += _dist(path[i], path[i + 1]);
    }
    return dist;
  }

  void stop() {
    _timer?.cancel();
    activeBuses.clear();
  }
}
