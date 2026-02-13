import 'dart:async';
import 'package:latlong2/latlong.dart';

class SimulatedBus {
  String lineName;
  List<LatLng> routePath;
  double cachedTotalLength; 

  int currentSegmentIndex;
  double distanceTraveledInSegment;
  LatLng currentLocation;
  bool isWaiting;
  int waitTicksLeft;

  SimulatedBus({
    required this.lineName,
    required this.routePath,
    required this.cachedTotalLength, 
    this.currentSegmentIndex = 0,
    this.distanceTraveledInSegment = 0.0,
    this.isWaiting = false,
    this.waitTicksLeft = 0,
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

  static const int targetDurationMinutes = 30;
  static const int stopWaitSeconds = 15;

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

  void startSimulation(String startLineKey, [List<LatLng>? initialPath]) {
    if (!allRouteData.containsKey(startLineKey) && initialPath != null) {
      allRouteData[startLineKey] = initialPath;
      double totalLen = 0;
      for (int i = 0; i < initialPath.length - 1; i++) {
        totalLen += _dist(initialPath[i], initialPath[i + 1]);
      }
      _cachedRouteLengths[startLineKey] = totalLen;
    }
    if (!allRouteData.containsKey(startLineKey)) return;

    if (activeBuses.any((b) => b.lineName == startLineKey)) return;

    final path = allRouteData[startLineKey]!;
    final cachedLength = _cachedRouteLengths[startLineKey] ?? 0;
    
    final bus = SimulatedBus(
      lineName: startLineKey,
      routePath: path,
      cachedTotalLength: cachedLength,
    );
    activeBuses.add(bus);

    if (_timer == null || !_timer!.isActive) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    const int tickMs = 300;

    _timer = Timer.periodic(const Duration(milliseconds: tickMs), (timer) {
      if (activeBuses.isEmpty) return;

      for (var bus in activeBuses) {
        if (bus.isWaiting) {
          bus.waitTicksLeft--;
          if (bus.waitTicksLeft <= 0) {
            bus.isWaiting = false;
          }
          continue;
        }

        double speedMps = bus.cachedTotalLength / (targetDurationMinutes * 60);
        double stepDist = speedMps * (tickMs / 1000.0);

        _moveSingleBus(bus, stepDist, tickMs);
      }

      onUpdate(activeBuses);
    });
  }

  void _moveSingleBus(SimulatedBus bus, double stepDistance, int tickMs) {
    if (bus.routePath.isEmpty) return;

    LatLng startNode = bus.routePath[bus.currentSegmentIndex];
    LatLng endNode = bus.routePath[bus.currentSegmentIndex + 1];
    double segmentLength = _dist(startNode, endNode);

    if (segmentLength == 0) segmentLength = 0.001;

    bus.distanceTraveledInSegment += stepDistance;

    while (bus.distanceTraveledInSegment >= segmentLength) {
      bus.isWaiting = true;
      bus.waitTicksLeft = (stopWaitSeconds * 1000) ~/ tickMs;
      bus.distanceTraveledInSegment = 0;
      bus.currentLocation = endNode;

      bus.currentSegmentIndex++;

      if (bus.currentSegmentIndex >= bus.routePath.length - 1) {
        _switchDirection(bus);
        bus.isWaiting = false;
        return;
      }

      return;
    }

    double ratio = bus.distanceTraveledInSegment / segmentLength;
    double newLat =
        startNode.latitude + (endNode.latitude - startNode.latitude) * ratio;
    double newLng =
        startNode.longitude + (endNode.longitude - startNode.longitude) * ratio;
    bus.currentLocation = LatLng(newLat, newLng);
  }

  void _switchDirection(SimulatedBus bus) {
    String current = bus.lineName;
    String nextLineKey = "";

    if (current.endsWith("_Gidis")) {
      nextLineKey = current.replaceAll("_Gidis", "_Donus");
    } else if (current.endsWith("_Donus")) {
      nextLineKey = current.replaceAll("_Donus", "_Gidis");
    }

    if (nextLineKey.isNotEmpty && allRouteData.containsKey(nextLineKey)) {
      bus.lineName = nextLineKey;
      bus.routePath = allRouteData[nextLineKey]!;
      bus.cachedTotalLength = _cachedRouteLengths[nextLineKey] ?? 0; 
      bus.currentSegmentIndex = 0;
      bus.distanceTraveledInSegment = 0;
    } else {
      bus.currentSegmentIndex = 0;
      bus.distanceTraveledInSegment = 0;
    }
  }

  int? calculateEtaMinutes(String lineName, LatLng userStopLocation) {
    try {
      final bus = activeBuses.firstWhere((b) => b.lineName == lineName);
      int stopIndex = _findNearestIndex(bus.routePath, userStopLocation);
      if (bus.currentSegmentIndex >= stopIndex) return null;
      
      LatLng nextStop = bus.routePath[bus.currentSegmentIndex + 1];
      double distToNext = _dist(bus.currentLocation, nextStop);
      double segmentsDist = 0;
      for (int i = bus.currentSegmentIndex + 1; i < stopIndex; i++) {
        segmentsDist += _dist(bus.routePath[i], bus.routePath[i + 1]);
      }

      double speed = bus.cachedTotalLength / (targetDurationMinutes * 60);
      double seconds = (distToNext + segmentsDist) / speed;
      return (seconds / 60).ceil();
    } catch (e) {
      return null;
    }
  }

  int _findNearestIndex(List<LatLng> path, LatLng point) {
    int bestIdx = 0;
    double minD = double.infinity;
    for (int i = 0; i < path.length; i++) {
      final dist = _dist(point, path[i]);
      if (dist < minD) {
        minD = dist;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  void stop() {
    _timer?.cancel();
    activeBuses.clear();
  }
}