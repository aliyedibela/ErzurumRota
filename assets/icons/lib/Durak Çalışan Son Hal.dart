import 'dart:async';
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
import 'main.dart';
import 'dart:io';
import 'stops_layer.dart';
import 'utils/stop_utils.dart';

void main() {
  runApp(const MyApp());
  HttpOverrides.global = MyHttpOverrides(); // 🔥 eklendi
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Erzurum Rota',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const RoutePage(),
    );
  }
}

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
  // === TÜM HATLAR ===
  List<LatLng>? bus1Segment;
  List<LatLng>? bus2Segment;
  bool showBusStops = true;
  List<dynamic>? _cachedStops;
  final Distance _dist = const Distance();

  double progress = 0.0; // 🔹 Yükleme yüzdesi (0.0 - 1.0 arası)

  String getExactStopName(LatLng point) {
    // _cachedStops verisine erişimimiz olmalı.
    if (_cachedStops == null || _cachedStops!.isEmpty) {
      return StopUtils.stopNameFromLatLng(point);
    }

    final Distance distance = const Distance();

    // 10 metre hassasiyetle, tam o noktadaki durağın adını bul
    for (var stop in _cachedStops!) {
      // stop yapına göre lat/lon/display key'lerini kontrol et
      double lat = double.tryParse(stop['lat'].toString()) ?? 0;
      double lng = double.tryParse(stop['lon'].toString()) ?? 0;

      // Eğer nokta 10 metreden yakınsa, kesin o duraktır.
      if (distance(point, LatLng(lat, lng)) < 15) {
        return stop['display'];
      }
    }

    // Bulamazsa eskiye dön
    return StopUtils.stopNameFromLatLng(point);
  }

  SegmentResult? findBestSegment(
    LatLng userStart,
    LatLng userEnd,
    List<LatLng> linePoints,
    String lineName,
  ) {
    final Distance distance = const Distance();
    // 🔍 YARIÇAP ARTIRILDI: Durak uzakta kalsa bile yakalasın (2km)
    const double searchRadius = 2000;

    final List<int> startCandidates = [];
    final List<int> endCandidates = [];

    // 1. Adayları Topla
    for (int i = 0; i < linePoints.length; i++) {
      if (distance(userStart, linePoints[i]) < searchRadius)
        startCandidates.add(i);
      if (distance(userEnd, linePoints[i]) < searchRadius) endCandidates.add(i);
    }

    if (startCandidates.isEmpty || endCandidates.isEmpty) return null;

    SegmentResult? bestResult;
    double minTotalScore = double.infinity;

    // 2. Kombinasyonları Tara
    for (final sIdx in startCandidates) {
      for (final eIdx in endCandidates) {
        // 🛑 KURAL: Biniş indexi, İniş indexinden büyükse bu rota GEÇERSİZDİR.
        // Bu satır 46. durak (Index 68) -> Varış (Index 25) rotasını İMKANSIZ kılar.
        if (sIdx >= eIdx) continue;

        // Skorlama: Yürüme mesafesi + Otobüs yolculuğu (kısa yolculuk tercihi)
        final walk1 = distance(userStart, linePoints[sIdx]);
        final walk2 = distance(userEnd, linePoints[eIdx]);

        // Otobüsün gittiği mesafe de skora eklensin ki en mantıklı ikili seçilsin
        // (Index farkı * 10 metre gibi basit bir maliyet)
        final busScore = (eIdx - sIdx) * 10.0;

        final totalScore = walk1 + walk2 + busScore;

        if (totalScore < minTotalScore) {
          minTotalScore = totalScore;

          // KONSOLA BAK: Burası çalışıyorsa 46'yı seçmesi matematiksel olarak imkansız
          print(
            "🎯 $lineName Aday: Index $sIdx -> Index $eIdx (Skor: ${totalScore.toInt()})",
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

  void _resetRouteState() {
    setState(() {
      // tüm state temizlenir
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

      // controller’lar da boşaltılır
      _startController.clear();
      _endController.clear();
    });

    // Haritayı tekrar merkeze getir
    mapController.move(LatLng(39.9042, 41.2670), 13);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Yeni rota için başlangıç ve varış noktalarını seçin."),
      ),
    );
  }

  String _formatDuration(double meters, {bool isBus = false}) {
    final speed = isBus ? 6.9 : 1.4; // m/s
    final seconds = meters / speed;
    final minutes = (seconds / 60).round();
    return "$minutes dk";
  }

  void _showSelectedRouteSummary(RouteOption opt) {
    const double walkingSpeed = 1.4;
    const double busSpeed = 6.9;

    final totalWalk1 = _polylineLength(opt.walk1);
    final totalBus1 = _polylineLength(opt.bus1);
    final totalWalkTransfer = _polylineLength(opt.walkTransfer);
    final totalBus2 = _polylineLength(opt.bus2);
    final totalWalk2 = _polylineLength(opt.walk2);

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
                  // 🔹 Cam efekti beyaz-mavi ton
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
                      opt.isTransfer
                          ? "🚌 ${opt.lineName} → ${opt.transferLine}"
                          : "🚌 ${opt.lineName}",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo, // 💙 başlık rengi
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Adımlar — her biri kutucukla
                    if (opt.isTransfer) ...[
                      _buildStep(
                        "${_formatDuration(totalWalk1)} yürü (${opt.startStopName ?? opt.lineName} durağına)",
                      ),
                      _buildStep(
                        "${_formatDuration(totalBus1, isBus: true)} otobüsle git (${opt.startStopName ?? 'Başlangıç durağı'} → ${opt.transferStopName ?? 'Aktarma durağı'})",
                      ),
                      _buildStep(
                        "🔁 ${_formatDuration(totalWalkTransfer)} aktarma (${opt.transferStopName ?? 'aktarma durağı'})",
                      ),
                      _buildStep(
                        "${_formatDuration(totalBus2, isBus: true)} otobüsle git (${opt.transferLine})",
                      ),

                      _buildStep(
                        "${_formatDuration(totalWalk2)} yürü (${opt.endStopName ?? 'varış durağı'})",
                      ),
                    ] else ...[
                      _buildStep(
                        "${_formatDuration(totalWalk1)} yürü (${opt.startStopName ?? opt.lineName} durağına)",
                      ),
                      _buildStep(
                        "${_formatDuration(totalBus1, isBus: true)} otobüsle git (${opt.startStopName ?? opt.lineName} → ${opt.endStopName ?? 'varış durağı'})",
                      ),
                      _buildStep(
                        "${_formatDuration(totalWalk2)} yürü (${opt.endStopName ?? 'varış durağı'})",
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
                  ],
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

  // çizim
  List<Polyline> polylines = [];

  // seçili hat adları (durak markerları için)
  String? suggestedLine;
  String? transferLine;

  // seçenek listesi (diyalog için)
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
      // 🔥 yön tersse, ters çevirip doğru akışı al
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

          // 🔥 yön farkı büyükse (örneğin >90°) ters yön — at
          if (diff > 90) continue;

          final score = d + diff * 0.5; // yön uyumu + yakınlık

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

    // Kullanıcının hareket yönü
    final userDir = _bearing(current, target);

    for (int i = 0; i < polyline.length - 2; i++) {
      final stop = polyline[i];
      final next = polyline[i + 1];
      final next2 = polyline[i + 2];

      final d = distance(current, stop);

      // bu segmentin yönü
      final dir1 = _bearing(stop, next);
      final dir2 = _bearing(next, next2);
      final avgDir = (dir1 + dir2) / 2; // yumuşatılmış yön
      final diff = _angleDiff(userDir, avgDir);

      // 🔹 yön farkı cezası
      final directionPenalty = diff > 100 ? 9999 : diff;

      // 🔹 ileriye mi geriye mi gidiyoruz kontrolü
      final proj = distance(target, next);
      final sameFlow = proj < distance(target, stop);

      // ters akıştaki segmentlere ekstra ceza
      final flowPenalty = sameFlow ? 0 : 300;

      // nihai skor
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

  @override
  void initState() {
    super.initState();
    if (widget.startPoint != null && widget.destination != null) {
      startPoint = widget.startPoint!;
      endPoint = widget.destination!;
      Future.delayed(const Duration(milliseconds: 500), () {
        _calculateRoutesAndShowDialog();
      });
    }
    StopUtils.loadAllStops();
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
                      "🚏 Alternatif Rota Önerileri",
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

                          // 🎨 Rota türüne göre stil
                          IconData icon;
                          List<Color> gradient;
                          String subtitle;

                          if (opt.lineName.contains("Yürüyüş")) {
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
                            gradient = [Colors.orangeAccent, Colors.deepOrange];
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
                                          ? "${opt.lineName} → ${opt.transferLine}"
                                          : opt.lineName,
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

                                      // 🗺️ Rota çizimi
                                      setState(() {
                                        suggestedLine = opt.lineName;
                                        transferLine = opt.transferLine;
                                        polylines = [
                                          Polyline(
                                            points: opt.walk1,
                                            color: Colors.green,
                                            strokeWidth: 3,
                                          ),
                                          Polyline(
                                            points: opt.bus1,
                                            color: opt.lineName.contains("Araç")
                                                ? Colors.redAccent
                                                : Colors.blue,
                                            strokeWidth: 4,
                                          ),
                                          if (opt.walkTransfer != null)
                                            Polyline(
                                              points: opt.walkTransfer!,
                                              color: Colors.orange,
                                              strokeWidth: 3,
                                            ),
                                          if (opt.bus2 != null)
                                            Polyline(
                                              points: opt.bus2!,
                                              color: Colors.purple,
                                              strokeWidth: 4,
                                            ),
                                          Polyline(
                                            points: opt.walk2,
                                            color: Colors.green,
                                            strokeWidth: 3,
                                          ),
                                          Polyline(
                                            points: opt.bus1,
                                            color: Colors.blue,
                                            strokeWidth: 5,
                                            strokeCap: StrokeCap.round,
                                            strokeJoin: StrokeJoin.round,
                                          ),
                                        ];
                                        bus1Segment = opt.bus1;
                                        bus2Segment = opt.bus2;
                                      });

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
        );
      },
    );
  }

  List<LatLng> walkingToStop = [];
  List<LatLng> busRoute = [];
  List<LatLng> walkingToDestination = [];

  // === HATLAR ===
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

    print("🌍 OSRM çağrısı ($mode): $url");

    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5)); // ⏳ timeout güvenliği

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List coords = data["routes"][0]["geometry"]["coordinates"];
        print("📦 OSRM route ($mode) geldi: ${coords.length} nokta");
        return coords.map((c) => LatLng(c[1], c[0])).toList();
      } else {
        print("⚠️ Rota alınamadı ($mode): ${response.statusCode}");
        return []; // ❗️ Artık crash yok
      }
    } catch (e) {
      print("❌ Rota isteği başarısız ($mode): $e");
      return []; // ❗️ Her durumda boş döner, app çökmez
    }
  }

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Servis açık mı?
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return _fallbackErzurum();
    }

    // İzinler
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
      );

      // Eğer hala 0.0,0.0 dönerse Erzurum fallback
      if (pos.latitude == 0.0 && pos.longitude == 0.0) {
        return _fallbackErzurum();
      }

      return pos;
    } catch (e) {
      return _fallbackErzurum();
    }
  }

  // Erzurum fallback
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
    List<LatLng>? bus1Segment, // sadece bindiği–indiği arası
    List<LatLng>? bus2Segment, // ikinci hattın bindiği–indiği arası

    String? currentRouteName, //
  }) {
    final markers = <Marker>[];

    if (currentRouteName != null &&
        (currentRouteName.contains("Araç") ||
            currentRouteName.contains("Yürüyüş"))) {
      return markers;
    }

    // 🔵 1. hattın SADECE bindiği–indiği arası durakları
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

    // 🟣 2. hattın SADECE bindiği–indiği arası durakları (mor tonlu)
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
      // === B SERİSİ (Zaten Yapılmış Olanlar) ===
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

      // === G SERİSİ (Yeni Eklenenler) ===
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

      // === K SERİSİ ===
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

      // K2 zaten yapılmıştı
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

      // === M SERİSİ ===
      case "M11_Gidis":
        busLines["M11_Gidis"] = M11_Gidis;
        break;
      case "M11_Donus":
        busLines["M11_Donus"] = M11_Donus;
        break;
      // === A SERİSİ ===
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
        // 🔹 İlk segmentin ilk noktası hariç diğerlerini ekle (çift tekrar olmasın)
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
    const int MAX_SECONDS = 15; // ⏱ süremiz 15 saniye
    const int MAX_DIRECT = 2; // 🚍 maksimum 2 direkt
    const int MAX_TRANSFER = 4; // 🔁 maksimum 4 aktarma

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
          ); // ✅ artık global değişken
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
      // === A SERİSİ ===
      "A1_Gidis", "A1_Donus",

      // === B SERİSİ ===
      "B1_Gidis", "B1_Donus",
      "B2_Gidis", "B2_Donus",
      "B2A_Gidis", "B2A_Donus",
      "B3_Gidis", "B3_Donus",

      // === G SERİSİ ===
      "G1_Gidis", "G1_Donus",
      "G2_Gidis",
      "G2_Donus", // Snippet'ta yoktu ama switch-case'de vardı, ekledim
      "G3_Gidis", "G3_Donus",
      "G4_Gidis", "G4_Donus",
      "G4A_Gidis", "G4A_Donus", // Switch-case ile uyumlu olsun
      "G4B_Gidis", "G4B_Donus", // Switch-case ile uyumlu olsun
      "G5_Gidis", "G5_Donus",
      "G6_Gidis", "G6_Donus",
      "G7_Gidis", "G7_Donus",
      "G7A_Gidis", "G7A_Donus",
      "G8_Gidis", "G8_Donus",
      "G9_Gidis", "G9_Donus",
      "G10_Gidis", "G10_Donus",
      "G11_Gidis", "G11_Donus", // Switch-case ile uyumlu olsun
      "G14_Gidis", "G14_Donus", // Switch-case ile uyumlu olsun
      // === K SERİSİ ===
      "K1_Gidis", "K1_Donus",
      "K1A_Gidis", "K1A_Donus", // Switch-case ile uyumlu olsun
      "K2_Gidis", "K2_Donus",
      "K3_Gidis", "K3_Donus",
      "K4_Gidis", "K4_Donus",
      "K5_Gidis", "K5_Donus",
      "K6_Gidis", "K6_Donus",
      "K7_Gidis", "K7_Donus",
      "K7A_Gidis", "K7A_Donus",
      "K10_Gidis", "K10_Donus",
      "K11_Gidis", "K11_Donus",
      // === M SERİSİ ===
      "M11_Gidis", "M11_Donus",
    ];

    for (final name in allLineNames) {
      ensureBusLineLoaded(name);
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
          startStopName: "Binilecek Durak", // buraya durak adını koy
          endStopName: "İnilecek Durak",
        ),
      );

      // ✅ direkt yürüyüş rotası bulunduysa hemen göster
      setState(() {
        isLoading = false;
        suggestedOptions = options;
      });
      _showOptionsDialog(context, options);
      print(
        "🚶‍♂️ Kısa mesafe yürüyüş rotası önerildi (${total.toStringAsFixed(0)} m)",
      );
    }

    // 🚍 1️⃣ DİREKT seçenekler (max 2)
    // 🚍 1️⃣ DİREKT seçenekler
    // 🚍 1️⃣ DİREKT seçenekler
    final directCandidates = startNearby
        .intersection(endNearby)
        .take(MAX_DIRECT);

    for (final name in directCandidates) {
      if (stopwatch.elapsed.inSeconds > MAX_SECONDS) break;

      final line = busLines[name]!;

      // 🔥 YENİ FONKSİYON ÇAĞRISI
      final bestSegment = findBestSegment(startPoint!, endPoint!, line, name);

      if (bestSegment == null) {
        print("⚠️ $name için uygun yönlü rota bulunamadı.");
        continue;
      }

      final ns = bestSegment.startPoint;
      final ne = bestSegment.endPoint;
      final bus1 = bestSegment.segment;

      // 🔥 YENİ İSİM BULUCU (46-72 karışıklığını çözer)
      final nsName = getExactStopName(ns);
      final neName = getExactStopName(ne);

      print("✅ SEÇİLEN ROTA ($name): $nsName -> $neName");

      final results = await Future.wait([
        _getRoute(startPoint!, ns, mode: "walking"),
        _getRoute(ne, endPoint!, mode: "walking"),
      ]).timeout(const Duration(seconds: 5), onTimeout: () => [[], []]);

      final walk1 = results[0];
      final walk2 = results[1];

      // Hesaplamada bus1 uzunluğunu kullanıyoruz
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
          lineName: displayName,
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

          // 🧹 2. Hattın (Transfer Hattı) İsmini Temizle
          // Aktarma yapılan hat da bölünmüş bir hat olabilir.
          String displayEName = eName;
          if (eName.contains("_")) {
            displayEName = eName.split("_")[0];
          }
          options.add(
            RouteOption(
              lineName: displaySName,
              transferLine: displayEName,
              walk1: walks[0],
              bus1: bus1,
              walkTransfer: walks[1],
              bus2: bus2,
              walk2: walks[2],
              totalDistance: total,
              isTransfer: true,
              startStopName: nsName, // ✅ eklendi
              transferStopName: "$nt1Name ↔ $nt2Name", // ✅ eklendi
              endStopName: neName, // ✅ eklendi
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

    // ⏱ 15 saniye dolmadan hiçbir şey bulamadıysa mesaj burada gelsin
    if (options.isEmpty && stopwatch.elapsed.inSeconds >= MAX_SECONDS) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("15 saniye içinde uygun rota bulunamadı."),
        ),
      );
      return;
    }

    // 🚗 Araç (car.lua) rotasını da her durumda öner
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

    options.sort((a, b) => a.totalDistance.compareTo(b.totalDistance));
    final limited = options.take(MAX_DIRECT + MAX_TRANSFER).toList();

    setState(() {
      isLoading = false;
      suggestedOptions = limited;
    });

    _showOptionsDialog(context, limited);

    print(
      "✅ ${options.length} rota bulundu (${stopwatch.elapsed.inSeconds}s sürdü)",
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

    // state
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

    // haritayı kadrajla
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
    // 📌 Navigator.pushNamed ile gelen parametreleri al
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    if (args != null && endPoint == null) {
      endPoint = LatLng(args["lat"], args["lng"]);
      widget.destinationName;
    }

    return Scaffold(
      backgroundColor: const Color(
        0xFFF4F6FA,
      ), // 🔹 Hafif gri-mavi alt ton (cam efekti belirgin olur)
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
                elevation: 0,
                centerTitle: true,
                title: Text(
                  widget.destinationName ?? "Rota Öneri Sistemi",
                  style: TextStyle(
                    fontFamily: 'Product Sans',
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                    letterSpacing: 0.3,
                    color: Colors.black.withOpacity(0.85),
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.black87,
                  ),
                  onPressed: () {
                    // ✅ Artık sekme mantığında çalıştığı için HomePage'e dön
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const HomePage()),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),

      body: Column(
        children: [
          // 🔹 Başlangıç input
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

          // Harita
          Expanded(
            child: Stack(
              children: [
                // === 1️⃣ Harita ===
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

                      // 🔥 elle tıklamayla başlangıç ve bitiş seçilince aynı hesaplama çalışsın
                      if (startPoint != null && endPoint != null) {
                        await _calculateRoutesAndShowDialog();
                      }
                    },
                  ),

                  // === ÇİZİM KATMANLARI ===
                  children: [
                    TileLayer(
                      urlTemplate:
                          "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                    ),
                    if (polylines.isNotEmpty)
                      PolylineLayer(polylines: polylines),

                    if (bus1Segment != null || bus2Segment != null)
                      StopsLayer(
                        routePoints: polylines.expand((p) => p.points).toList(),
                        currentRouteName: suggestedLine,
                        showBusStops: !suggestedLine!.contains("Araç"),
                      ),

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
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // 🔵 % ilerlemeli progress çemberi
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      SizedBox(
                                        height: 80,
                                        width: 80,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 6,
                                          value: progress, // 💡 % ilerleme
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
                                  // 🌈 İlerleme çubuğu (yatay)
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

                // === 3️⃣ Yeni Rota Önerisi Butonu ===
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

// 🔎 Adres arama widgeti
class SearchLocationField extends StatefulWidget {
  final String hintText;
  final VoidCallback onFocus;
  final void Function(double lat, double lng) onSelected;
  final bool showCurrentLocationOption;
  final TextEditingController? controller; // ✅ Bunu ekle!

  const SearchLocationField({
    super.key,
    required this.hintText,
    required this.onSelected,
    required this.onFocus,
    this.showCurrentLocationOption = false,
    this.controller, // default kapalı
  });

  @override
  State<SearchLocationField> createState() => _SearchLocationFieldState();
}

class RouteOption {
  final String lineName; // 1. hat (zorunlu)
  final String? transferLine; // 2. hat (opsiyonel: aktarma varsa)
  final List<LatLng> walk1; // start -> 1.hat biniş
  final List<LatLng> bus1; // 1.hat otobüs segmenti
  final List<LatLng>
  walkTransfer; // 1.hat iniş -> 2.hat biniş (aktarma yürüyüşü)
  final List<LatLng> bus2; // 2.hat otobüs segmenti
  final List<LatLng> walk2; // son iniş -> varış yürüyüş
  final double totalDistance; // toplam (yürüme+otobüs)
  final bool isTransfer; // aktarmalı mı?
  final String? startStopName; // 🆕 ekle
  final String? endStopName; // 🆕 ekle
  final String? transferStopName;

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
  });
}

class _SearchLocationFieldState extends State<SearchLocationField> {
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  Future<void> _searchPlaces(String query) async {
    // 🔥 Eğer kullanıcı kutuya tıkladı ama arama yapmadıysa:
    if (query.isEmpty) {
      setState(() {
        _results = [];

        // 🔥 sadece showCurrentLocationOption = true ise göster
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
        "AIzaSyA1vYAY0R_KTU8cqcyAECyj44dbvtHTEFA"; // Google API key'in
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

  // bu fonksiyonla LatLng’ten durak adı alıyoruz
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller ?? TextEditingController();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: controller, // 👈 burası önemli!
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
                  InputBorder.none, // 🔥 varsayılan çizgi tamamen kaldırıldı
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: true,
              fillColor: Colors.white.withOpacity(
                0.15,
              ), // 🔥 container ile aynı ton
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
              ); // 👈 kutuya tıklanınca “Konumunuzu kullan” gelsin
            },
            onSubmitted: (value) async {
              if (value.isEmpty) return;

              // Google API ile arama yap
              final encodedQuery = Uri.encodeComponent(value);
              const apiKey =
                  "AIzaSyA1vYAY0R_KTU8cqcyAECyj44dbvtHTEFA"; // kendi API key'in
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
                  controller.text = data["results"][0]["name"];
                  setState(() => _results.clear());

                  // 🔥 Elle yazıp Enter’a basınca da rota hesaplama çalışsın
                  if (widget.hintText.contains("Nereye")) {
                    Future.delayed(const Duration(milliseconds: 300), () async {
                      // ignore: use_build_context_synchronously
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
              ), // 🔥 Mat değil, yarı saydam beyaz
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.transparent,
              ), // 🔥 kenar çizgisi yok
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06), // hafif yumuşak gölge
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.blue.withOpacity(
                    0.03,
                  ), // çok hafif mavi yansıma
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

                // 🔥 Eğer bu "Konumunuzu kullan" seçeneği ise:
                if (item["isCurrentLocation"] == true) {
                  return ListTile(
                    leading: const Icon(Icons.my_location, color: Colors.blue),
                    title: Text(item["display"]),
                    onTap: () async {
                      final pos = await Geolocator.getCurrentPosition(
                        desiredAccuracy: LocationAccuracy.high,
                      );
                      widget.onSelected(pos.latitude, pos.longitude);
                      controller.text = "Mevcut konumunuz";
                      setState(() => _results.clear());
                    },
                  );
                }

                // 🔎 Normal arama sonucu
                return ListTile(
                  title: Text(
                    item["display"],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () async {
                    double lat = item["lat"];
                    double lon = item["lon"];

                    // 🔹 OSRM nearest (walking graph üzerinde en yakın nokta)
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
                    controller.text = item["display"];
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
