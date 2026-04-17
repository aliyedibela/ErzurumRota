import 'dart:async';
import 'dart:math';
import 'package:latlong2/latlong.dart';

// 1. SADELEŞTİRİLMİŞ VE GÜÇLENDİRİLMİŞ OTOBÜS SINIFI
class SimulatedBus {
  String id;
  String lineName;
  List<LatLng> routePath;
  double cachedTotalLength;
  int durationMs; // Bu otobüsün seferi kaç milisaniye sürüyor
  int timeOffsetMs; // Diğer otobüsle aralarındaki mesafe (Zaman farkı)
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
    // 1. Yeni gelen rotayı kaydet
    if (initialPath != null) {
      allRouteData[lineKey] = initialPath;
      double totalLen = 0;
      for (int i = 0; i < initialPath.length - 1; i++) {
        totalLen += _dist(initialPath[i], initialPath[i + 1]);
      }
      _cachedRouteLengths[lineKey] = totalLen;
    }

    // 2. Sadece ilgili yön için otobüs var mı kontrol et
    // Eğer bu spesifik yön (örn: K10_Donus) zaten varsa ekleme yapma
    if (activeBuses.any((b) => b.lineName == lineKey)) return;

    // 3. Sadece çağrılan yön için otobüs üret
    // Bu sayede Gidis yüklendiğinde gidiş, Donus yüklendiğinde dönüş otobüsleri oluşur.
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

    // Her yönün kendi "Random" seed'i olsun ki süreler gidiş-dönüşte farklı olsun
    Random random = Random(key.hashCode);
    int durationMins = 75 + random.nextInt(31); // 20-40 dk
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
    // Animasyon akıcı olsun diye saniyede 1 güncelliyoruz.
    // Artık TickMs hesaplamaya gerek yok, saat kaçsa ona göre çizilecek.
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (activeBuses.isEmpty) return;

      int nowMs = DateTime.now().millisecondsSinceEpoch;

      for (var bus in activeBuses) {
        _updateBusPosition(bus, nowMs);
      }

      onUpdate(activeBuses);
    });
  }

  // 🧠 MATEMATİK BÜYÜSÜ: Zamanı mesafeye çeviren fonksiyon
  void _updateBusPosition(SimulatedBus bus, int nowMs) {
    if (bus.routePath.isEmpty) return;

    // Şu anki zaman + Otobüsün başlangıç farkı
    int logicalTimeMs = nowMs + bus.timeOffsetMs;

    // Yüzdelik İlerleme (0.0 ile 1.0 arası). Modulo (%) sayesinde başa döner.
    double progress = (logicalTimeMs % bus.durationMs) / bus.durationMs;

    // Yüzdeyi metreye çevir
    double targetDist = progress * bus.cachedTotalLength;

    // Haritadaki tam GPS koordinatını bul
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

  // 👻 HAYALET ETA HESAPLAYICI (Sıfır RAM, Sadece Matematik)
  int? getGhostEta(
    String lineKey,
    LatLng stopLoc,
    Map<String, List<LatLng>> externalBusLines,
  ) {
    try {
      // 1. Rota verisi bizde yoksa external map'ten (RoutePage'den) al
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

      // Veri hala yoksa hesaplayamayız
      if (!allRouteData.containsKey(lineKey)) return null;

      final path = allRouteData[lineKey]!;
      final totalLength = _cachedRouteLengths[lineKey] ?? 0.1;

      // 2. Hattın süresini bul (Simülasyondaki aynı mantık)
      Random random = Random(lineKey.hashCode);
      int durationMins = 75 + random.nextInt(31); // 20-40 dk
      int durationMs = durationMins * 60 * 1000;

      // 3. Kullanıcının durağının başlangıca uzaklığı
      double userDist = _getDistanceToPoint(path, stopLoc);
      int minEta = 9999;

      int nowMs = DateTime.now().millisecondsSinceEpoch;

      // 4. 2 adet otobüs için matematiksel konumu bul
      for (int i = 0; i < 3; i++) {
        int offsetMs = (durationMs ~/ 3) * i;
        int logicalTimeMs = nowMs + offsetMs;
        double progress = (logicalTimeMs % durationMs) / durationMs;

        double currentDist = progress * totalLength;

        double distRemaining;
        if (userDist >= currentDist) {
          distRemaining = userDist - currentDist; // Otobüs henüz gelmedi
        } else {
          distRemaining =
              (totalLength - currentDist) + userDist; // Otobüs tur atıp gelecek
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

  // 🕒 YENİ ETA (TAHMİNİ VARIŞ) HESAPLAYICI (Sana en yakın otobüsü bulur)
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
          distRemaining = userDist - currentDist; // Otobüs henüz gelmedi
        } else {
          distRemaining =
              (bus.cachedTotalLength - currentDist) +
              userDist; // Otobüs geçti, turlayıp gelecek
        }

        double speed = bus.cachedTotalLength / bus.durationMs; // ms başına hız
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
