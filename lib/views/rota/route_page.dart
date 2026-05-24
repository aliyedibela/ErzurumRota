import 'dart:async';
import 'dart:ui';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:erzurum_rota/models/route_option.dart';
import 'package:erzurum_rota/models/taxi_stand.dart';      
import 'package:erzurum_rota/viewmodels/route_viewmodel.dart';
import 'package:erzurum_rota/services/bus_simulator.dart';
import 'package:erzurum_rota/core/utils/stop_utils.dart';
import 'package:erzurum_rota/widgets/stops_layer.dart';
import 'package:erzurum_rota/data/taxi_stands.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:signalr_core/signalr_core.dart';

import '../../core/accessibility_prefs.dart';
import '../../services/accessibility_service.dart';
import '../../services/favorite_stop_service.dart';

class RoutePage extends StatefulWidget {
  final LatLng? startPoint;
  final LatLng? destination;
  final String? destinationName;
  final ValueNotifier<String?>? lineNotifier;

  const RoutePage({
    super.key,
    this.startPoint,
    this.destination,
    this.destinationName,
    this.lineNotifier,
  });

  @override
  State<RoutePage> createState() => _RoutePageState();
}

class _RoutePageState extends State<RoutePage> with WidgetsBindingObserver {


  late RouteViewModel _vm;
  List<LatLng>? bus1Segment;
  List<LatLng>? bus2Segment;
  TaxiStand? selectedTaxiStand;
  bool showTaxiStands = false;
  List<Marker> _taxiStandMarkers = [];
  bool isRouteMode = false;
  bool showBusStops = true;
  BusSimulationManager? _simulationManager;
  late AccessibilityService _accessibilityService;
  List<Marker> _busMarkers = [];
  BuildContext? _waitingDialogCtx;
  Set<String> _favoriteStopIds = {};

  List<Polyline> polylines = [];
  String? suggestedLine;
  String? transferLine;
  List<RouteOption> suggestedOptions = [];
  LatLng? startPoint;
  LatLng? endPoint;
  List<LatLng> routePoints = [];
  String? activeField;
  bool isLoading = false;
  double progress = 0.0;
  String randomTip = "";

  final mapController = MapController();
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  final List<String> loadingTips = [
    "Rotalarınızı analiz ediyoruz...",
    "En kısa yolu bulmak için hatları tarıyoruz...",
    "Biliyor muydunuz? Erzurum'daki en uzun hat G4'tür!",
    "Aktarma seçenekleri hesaplanıyor...",
    "Ortalama hesaplama süresi 10-15 saniye sürebilir.",
    "OSRM motoru rota geometrilerini çıkarıyor...",
  ];

  void _onLineNotified() {
    final line = widget.lineNotifier?.value;
    if (line != null && mounted) {
      _smartSelectLine(line);
      widget.lineNotifier!.value = null; // sıfırla
    }
  }

  @override
  void initState() {
    super.initState();
    widget.lineNotifier?.addListener(_onLineNotified);
WidgetsBinding.instance.addObserver(this);
    _simulationManager = BusSimulationManager(
      onUpdate: (buses) {
        if (!mounted) return;
        final visibleBuses = buses.where((b) {
          if (suggestedLine != null) {
            if (b.lineName == suggestedLine) return true;
            if (!suggestedLine!.contains("_") && b.lineName.startsWith(suggestedLine!)) return true;
          }
          if (transferLine != null) {
            if (b.lineName == transferLine) return true;
            if (!transferLine!.contains("_") && b.lineName.startsWith(transferLine!)) return true;
          }
          return false;
        }).toList();

        setState(() {
          _busMarkers = visibleBuses.map((b) => Marker(
            point: b.currentLocation,
            width: 45, height: 45,
            child: Stack(alignment: Alignment.center, children: [
              Container(
                width: 35, height: 35,
                decoration: BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(blurRadius: 5, color: Colors.black45)],
                ),
              ),
              const Icon(Icons.directions_bus_rounded, color: Colors.redAccent, size: 26),
            ]),
          )).toList();
        });
      },
    );

    _vm = RouteViewModel(simulationManager: _simulationManager);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      Future.microtask(() => StopUtils.loadAllStops());
      _loadFavoriteStopIds();
      await _vm.connectSignalR(
        onAccepted: (driverName, plate) {
          if (!mounted) return;
          if (_waitingDialogCtx != null) {
            Navigator.of(_waitingDialogCtx!).pop();
            _waitingDialogCtx = null;
          }
          _showResultDialog(accepted: true, driverName: driverName, plate: plate);
        },
        onRejected: () {
          if (!mounted) return;
          if (_waitingDialogCtx != null) {
            Navigator.of(_waitingDialogCtx!).pop();
            _waitingDialogCtx = null;
          }
          _showResultDialog(accepted: false);
        },
      );

      _accessibilityService = AccessibilityService(
        simulationManager: _simulationManager,
        busLines: _vm.busLines,
        onEnsureLineLoaded: _vm.ensureBusLineLoaded,
      );
      await _accessibilityService.init();
      final accessEnabled = await AccessibilityPrefs.isEnabled();
      if (accessEnabled) {
        await _accessibilityService.startLocationTracking();
        print('♿ Erişilebilirlik modu aktif');
      } else {
        print('♿ Erişilebilirlik modu kapalı');
      }

      if (widget.startPoint != null && widget.destination != null) {
        setState(() {
          startPoint = widget.startPoint!;
          endPoint = widget.destination!;
          _startController.text = "Konumunuz";
          _endController.text = widget.destinationName ?? "Seçilen Konum";
        });
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text("Rotaları hesaplamak için haritaya dokunun"),
            action: SnackBarAction(label: "Hesapla", onPressed: _calculateRoutes),
            duration: const Duration(seconds: 5),
          ));
        }
      }

      // İlk kez build edildiğinde lineNotifier değeri zaten set edilmiş olabilir
      final pendingLine = widget.lineNotifier?.value;
      if (pendingLine != null && mounted) {
        _smartSelectLine(pendingLine);
        widget.lineNotifier!.value = null;
      }
    });
  }

  @override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    _checkAccessibility();
  }
}

Future<void> _checkAccessibility() async {
  final enabled = await AccessibilityPrefs.isEnabled();
  if (enabled) {
    await _accessibilityService.startLocationTracking();
    print('♿ Erişilebilirlik modu aktif');
  } else {
    _accessibilityService.stopLocationTracking();
    print('♿ Erişilebilirlik modu kapalı');
  }
}

Future<void> _loadFavoriteStopIds() async {
  final favs = await FavoriteStopService().getFavorites();
  if (!mounted) return;
  setState(() {
    _favoriteStopIds = favs
        .map((f) => f['stopId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  });
}

  @override
  void dispose() {
    widget.lineNotifier?.removeListener(_onLineNotified);
    _accessibilityService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _vm.dispose();
    super.dispose();
  }

  Future<void> _calculateRoutes() async {
    FocusScope.of(context).unfocus();
    if (startPoint == null || endPoint == null) return;

    setState(() {
      polylines.clear();
      bus1Segment = null;
      bus2Segment = null;
      suggestedOptions.clear();
      isLoading = true;
      progress = 0.0;
      randomTip = (loadingTips..shuffle()).first;
    });

    final timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || !isLoading) { t.cancel(); return; }
      setState(() {
        progress = (progress + 0.067).clamp(0.0, 1.0);
        randomTip = (loadingTips..shuffle()).first;
      });
    });

    final options = await _vm.calculateRoutes(
      startPoint: startPoint!,
      endPoint: endPoint!,
      onProgress: (p) => setState(() => progress = (progress + p).clamp(0.0, 1.0)),
      maxSeconds: 15,
    );

    timer.cancel();
    setState(() {
      isLoading = false;
      suggestedOptions = options;
    });

    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Uygun rota bulunamadı.")),
      );
      return;
    }

    _showOptionsDialog(context, options);
  }

  void _resetRouteState() {
    setState(() {
      startPoint = null; endPoint = null;
      routePoints.clear(); polylines.clear();
      bus1Segment = null; bus2Segment = null;
      suggestedLine = null; transferLine = null;
      suggestedOptions.clear();
      isLoading = false; progress = 0.0;
      _startController.clear(); _endController.clear();
    });
    mapController.move(const LatLng(39.9042, 41.2670), 13);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Yeni rota için başlangıç ve varış noktalarını seçin.")),
    );
  }


  void _selectLineToView(String lineKey) {
    _vm.ensureBusLineLoaded(lineKey);
    if (!_vm.busLines.containsKey(lineKey)) return;
    final linePoints = _vm.busLines[lineKey]!;

    setState(() {
      suggestedLine = lineKey;
      showBusStops = true;
      polylines = [Polyline(points: linePoints, color: Colors.blueAccent, strokeWidth: 5)];
      bus1Segment = linePoints;
      bus2Segment = null;
    });

    _simulationManager?.setAllRoutes({lineKey: linePoints});
    _simulationManager?.startSimulation(lineKey);

    if (linePoints.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(linePoints);
      mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
    }
  }

  void _smartSelectLine(String baseLineName) {
    String targetLineKey = "${baseLineName}_Gidis";
    if (_simulationManager != null) {
      try {
        final activeBus = _simulationManager!.activeBuses.firstWhere(
          (b) => b.lineName.startsWith(baseLineName),
        );
        targetLineKey = activeBus.lineName;
      } catch (_) {}
    }
    _selectLineToView(targetLineKey);
  }

  void _toggleDirection() {
    if (suggestedLine == null) return;
    String newLineKey;
    if (suggestedLine!.endsWith("_Gidis")) {
      newLineKey = suggestedLine!.replaceAll("_Gidis", "_Donus");
    } else if (suggestedLine!.endsWith("_Donus")) {
      newLineKey = suggestedLine!.replaceAll("_Donus", "_Gidis");
    } else return;
    _selectLineToView(newLineKey);
  }

  void _clearSelectedLine() {
    setState(() {
      suggestedLine = null; polylines.clear();
      bus1Segment = null; bus2Segment = null;
      _busMarkers = []; isRouteMode = false;
    });
  }

  void _moveTo(LatLng point) => mapController.move(point, 15);

  String _formatDuration(double meters, {bool isBus = false}) {
    final speed = isBus ? 6.9 : 1.4;
    final minutes = (meters / speed / 60).round();
    return "$minutes dk";
  }

  void _renderTaxiRouteOnMap(RouteOption opt) {
    final lines = <Polyline>[];
    if (opt.walk1.isNotEmpty) lines.add(Polyline(points: opt.walk1, color: Colors.green, strokeWidth: 5));
    if (opt.bus1.isNotEmpty) lines.add(Polyline(points: opt.bus1, color: const Color(0xFFFF6F00), strokeWidth: 7));

    setState(() {
      polylines = lines; suggestedLine = null; transferLine = null; showBusStops = false;
      if (opt.taxiStand != null) { selectedTaxiStand = opt.taxiStand; showTaxiStands = true; }
    });

    final allPts = [...opt.walk1, ...opt.bus1];
    if (allPts.isNotEmpty) {
      mapController.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(allPts), padding: const EdgeInsets.all(50)));
    }
  }

  void _callTaxi(TaxiStand stand, {double? preCalculatedFare}) async {
    if (startPoint == null) {
      showDialog(
        context: context, barrierDismissible: false,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF1565C0)]),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Stack(alignment: Alignment.center, children: [
                    Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.1))),
                    const SizedBox(width: 60, height: 60, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 4)),
                    Container(width: 40, height: 40,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.15)),
                      child: const Icon(Icons.my_location, color: Colors.white, size: 24)),
                  ]),
                  const SizedBox(height: 20),
                  const Text('Konumunuz Alınıyor', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Lütfen bekleyin...', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
                ]),
              ),
            ),
          ),
        ),
      );

      try {
        final pos = await _vm.getCurrentLocation();
        if (!mounted) return;
        Navigator.pop(context);
        setState(() {
          startPoint = LatLng(pos.latitude, pos.longitude);
          _startController.text = "Mevcut Konumunuz";
        });
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Konum alınamadı.")));
        return;
      }
    }

    if (_vm.hubConnection?.state != HubConnectionState.connected) {
      await _vm.connectSignalR(
        onAccepted: (dN, p) { if (_waitingDialogCtx != null) { Navigator.of(_waitingDialogCtx!).pop(); _waitingDialogCtx = null; } _showResultDialog(accepted: true, driverName: dN, plate: p); },
        onRejected: () { if (_waitingDialogCtx != null) { Navigator.of(_waitingDialogCtx!).pop(); _waitingDialogCtx = null; } _showResultDialog(accepted: false); },
      );
    }

    final fare = preCalculatedFare ??
        (endPoint != null
            ? TaxiStandUtils.calculateEstimatedFare(const Distance()(startPoint!, endPoint!))
            : TaxiStandUtils.calculateEstimatedFare(const Distance()(startPoint!, stand.location) + 1000));

    try {
      await _vm.requestTaxi(stand: stand, startPoint: startPoint!, endPoint: endPoint, fare: fare);
      setState(() {
        selectedTaxiStand = stand; showTaxiStands = true;
        _taxiStandMarkers = [_buildSingleTaxiMarker(stand)];
      });
      mapController.move(stand.location, 16);
      _showWaitingDialog(stand);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("İstek gönderilemedi: $e")));
    }
  }

  void _updateTaxiStandMarkers() {
    if (!showTaxiStands) { setState(() => _taxiStandMarkers = []); return; }
    setState(() {
      _taxiStandMarkers = erzurumTaxiStands.map((stand) {
        final isSelected = selectedTaxiStand?.id == stand.id;
        return Marker(
          point: stand.location,
          width: isSelected ? 80 : 60, height: isSelected ? 80 : 60,
          child: GestureDetector(
            onTap: () {
              setState(() => selectedTaxiStand = stand);
              mapController.move(stand.location, 16);
              showDialog(
                context: context, barrierDismissible: true,
                builder: (dialogContext) => _buildTaxiStandDialog(dialogContext, stand),
              );
            },
            child: Stack(alignment: Alignment.center, children: [
              Container(width: isSelected ? 50 : 40, height: isSelected ? 50 : 40,
                decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.3), shape: BoxShape.circle)),
              Container(
                width: isSelected ? 45 : 35, height: isSelected ? 45 : 35,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFFFA726), Color(0xFFFF6F00)]),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.local_taxi, color: Colors.white, size: isSelected ? 26 : 20),
              ),
              if (isSelected) Positioned(top: 0, right: 0,
                child: Container(width: 18, height: 18,
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Colors.white, size: 12))),
            ]),
          ),
        );
      }).toList();
    });
  }

  void _showTaxiSelector() {
    final Distance dist = const Distance();
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) {
        LatLng userLocation = startPoint ?? const LatLng(39.9042, 41.2670);
        bool isLocating = false;

        return StatefulBuilder(builder: (ctx, setSheetState) {
          final sortedStands = erzurumTaxiStands
              .map((s) => {'stand': s, 'distance': dist(userLocation, s.location)})
              .toList()
            ..sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

          return DraggableScrollableSheet(
            initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.9,
            builder: (_, scrollController) => Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                border: Border.all(color: const Color(0xFFFF6F00).withValues(alpha: 0.3)),
              ),
              child: Column(children: [
                const SizedBox(height: 12),
                Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3))),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(children: [
                    const Icon(Icons.local_taxi, color: Color(0xFFFF6F00), size: 26),
                    const SizedBox(width: 10),
                    const Text("Taksi Durağı Seç", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    GestureDetector(
                      onTap: isLocating ? null : () async {
                        setSheetState(() => isLocating = true);
                        final pos = await _vm.getCurrentLocation();
                        setSheetState(() { userLocation = LatLng(pos.latitude, pos.longitude); isLocating = false; });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: const Color(0xFFFF6F00).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFFF6F00).withValues(alpha: 0.4))),
                        child: isLocating
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFFFF6F00), strokeWidth: 2))
                          : const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.my_location, color: Color(0xFFFF6F00), size: 18),
                              SizedBox(width: 6),
                              Text("Konumumu Al", style: TextStyle(color: Color(0xFFFF6F00), fontSize: 13, fontWeight: FontWeight.bold)),
                            ]),
                      ),
                    ),
                  ]),
                ),
                Expanded(child: ListView.builder(
                  controller: scrollController, itemCount: sortedStands.length,
                  itemBuilder: (ctx, index) {
                    final stand = sortedStands[index]['stand'] as TaxiStand;
                    final distance = sortedStands[index]['distance'] as double;
                    final distanceText = distance < 1000 ? '${distance.toStringAsFixed(0)} m' : '${(distance / 1000).toStringAsFixed(1)} km';
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: const Color(0xFF2C2C2E), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFFF6F00).withValues(alpha: 0.25))),
                      child: ListTile(
                        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFFF6F00).withValues(alpha: 0.15), shape: BoxShape.circle), child: const Icon(Icons.local_taxi, color: Color(0xFFFF6F00), size: 24)),
                        title: Row(children: [
                          Expanded(child: Text(stand.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFFF6F00).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFF6F00).withValues(alpha: 0.5))),
                            child: Text(distanceText, style: const TextStyle(color: Color(0xFFFF6F00), fontSize: 11, fontWeight: FontWeight.bold))),
                        ]),
                        subtitle: Text(stand.address, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6F00), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), elevation: 0),
                          onPressed: () { Navigator.pop(context); _callTaxi(stand); },
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.phone, size: 15, color: Colors.white), SizedBox(width: 4), Text("Çağır", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]),
                        ),
                      ),
                    );
                  },
                )),
              ]),
            ),
          );
        });
      },
    );
  }

  void _showWaitingDialog(TaxiStand stand) {
    int remainingSeconds = 60;
    Timer? countdownTimer;

    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) {
        _waitingDialogCtx = ctx;
        return StatefulBuilder(builder: (context, setDialogState) {
          countdownTimer?.cancel();
          countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (remainingSeconds > 0) {
              setDialogState(() => remainingSeconds--);
            } else {
              timer.cancel();
              if (_waitingDialogCtx != null) { Navigator.of(_waitingDialogCtx!).pop(); _waitingDialogCtx = null; }
              _vm.waitingRequestId = null;
              _showResultDialog(accepted: false);
            }
          });

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(colors: [Color(0xFFFF8F00), Color(0xFFE65100)]),
                boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.15), shape: BoxShape.circle), child: const Icon(Icons.local_taxi, color: Colors.white, size: 28)),
                  const SizedBox(width: 12),
                  const Expanded(child: Text("Taksi Aranıyor", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
                ]),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(stand.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Row(children: [const Icon(Icons.location_on, color: Colors.white70, size: 16), const SizedBox(width: 6), Expanded(child: Text(stand.address, style: const TextStyle(color: Colors.white70, fontSize: 13)))]),
                    const SizedBox(height: 4),
                    Row(children: [const Icon(Icons.phone, color: Colors.white70, size: 16), const SizedBox(width: 6), Text(stand.phone, style: const TextStyle(color: Colors.white70, fontSize: 13))]),
                  ]),
                ),
                const SizedBox(height: 24),
                const SizedBox(width: 48, height: 48, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 4)),
                const SizedBox(height: 12),
                const Text("Sürücü onayı bekleniyor...", style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.timer_outlined, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text("$remainingSeconds sn", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  ]),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
                    onPressed: () { countdownTimer?.cancel(); _vm.waitingRequestId = null; _waitingDialogCtx = null; Navigator.pop(ctx); },
                    child: const Text("İptal Et", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ),
          );
        });
      },
    ).then((_) => countdownTimer?.cancel());
  }

  void _showResultDialog({required bool accepted, String? driverName, String? plate}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: accepted ? [const Color(0xFF2E7D32), const Color(0xFF1B5E20)] : [const Color(0xFFC62828), const Color(0xFF7F0000)]),
            boxShadow: [BoxShadow(color: (accepted ? Colors.green : Colors.red).withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 72, height: 72,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(accepted ? Icons.check_rounded : Icons.close_rounded, color: Colors.white, size: 40)),
            const SizedBox(height: 16),
            Text(accepted ? "Taksi Yolda!" : "İstek Reddedildi", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (accepted) ...[
              Container(
                width: double.infinity, padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  _infoRow(Icons.person, "Sürücü", driverName ?? '-'),
                  const SizedBox(height: 8),
                  _infoRow(Icons.directions_car, "Plaka", plate ?? '-'),
                ]),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: Colors.white70, size: 18), SizedBox(width: 8),
                  Expanded(child: Text("Sürücünüz yola çıktı. Konumunuzda bekleyin.", style: TextStyle(color: Colors.white70, fontSize: 13))),
                ]),
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
                child: const Text("Bu duraktaki sürücüler şu an müsait değil.\nBaşka bir durak deneyebilirsiniz.", style: TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
              ),
            const SizedBox(height: 20),
            Row(children: [
              if (!accepted) ...[
                Expanded(child: OutlinedButton(
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () { Navigator.pop(ctx); _showTaxiSelector(); },
                  child: const Text("Başka Durak", style: TextStyle(color: Colors.white70)),
                )),
                const SizedBox(width: 12),
              ],
              Expanded(child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () => Navigator.pop(ctx),
                child: Text("Tamam", style: TextStyle(color: accepted ? const Color(0xFF2E7D32) : const Color(0xFFC62828), fontWeight: FontWeight.bold, fontSize: 16)),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  void _showOptionsDialog(BuildContext context, List<RouteOption> options) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(12),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 50, height: 5, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10))),
                const Text("Alternatif Rota Önerileri", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white, shadows: [Shadow(offset: Offset(0, 1), blurRadius: 4, color: Colors.black38)])),
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
                        icon = Icons.local_taxi; gradient = [const Color(0xFFFFA726), const Color(0xFFFF6F00)];
                        subtitle = opt.estimatedFare != null ? "Tahmini ücret: ${opt.estimatedFare!.toStringAsFixed(0)} TL • ${opt.totalDistance.toStringAsFixed(0)} m" : "Taksi ile ulaşım";
                      } else if (opt.lineName.contains("Yürüyüş")) {
                        icon = Icons.directions_walk; gradient = [Colors.greenAccent, Colors.green.shade700];
                        subtitle = "Kısa mesafe yürüyüş (${opt.totalDistance.toStringAsFixed(0)} m)";
                      } else if (opt.lineName.contains("Araç")) {
                        icon = Icons.directions_car; gradient = [Colors.redAccent, Colors.deepOrange];
                        subtitle = "Araçla tahmini: ${opt.totalDistance.toStringAsFixed(0)} m";
                      } else if (opt.isTransfer) {
                        icon = Icons.swap_horiz; gradient = [Colors.orangeAccent, Colors.deepOrange];
                        subtitle = "Aktarmalı rota (${opt.totalDistance.toStringAsFixed(0)} m)";
                      } else {
                        icon = Icons.directions_bus; gradient = [Colors.lightBlueAccent, Colors.blueAccent];
                        subtitle = "Direkt hat (${opt.totalDistance.toStringAsFixed(0)} m)";
                      }

                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(milliseconds: 400 + index * 80),
                        builder: (context, value, child) => Transform.scale(
                          scale: value,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [BoxShadow(color: gradient.last.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                            ),
                            child: ListTile(
                              leading: Icon(icon, color: Colors.white, size: 30),
                              title: Text(
                                opt.isTransfer ? "${opt.lineName.split('_')[0]} → ${opt.transferLine?.split('_')[0]}" : opt.lineName.split('_')[0],
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70)),
                              onTap: () {
                                Navigator.pop(context);
                                FocusScope.of(context).unfocus();

                                if (opt.isTaxi) { _renderTaxiRouteOnMap(opt); _showSelectedRouteSummary(opt); return; }

                                final fullLine1 = _vm.busLines[opt.lineName] ?? <LatLng>[];
                                final fullLine2 = opt.transferLine != null ? (_vm.busLines[opt.transferLine] ?? <LatLng>[]) : <LatLng>[];

                                _simulationManager?.startSimulation(opt.lineName);

                                 setState(() {
                                   suggestedLine = opt.lineName; transferLine = opt.transferLine;
                                   polylines = [
                                     // Tüm hat güzergahları — ince, soluk gri (gidilmeyen kısımlar belli olsun)
                                     if (fullLine1.isNotEmpty) Polyline(points: fullLine1, color: Colors.blueGrey.withValues(alpha: 0.28), strokeWidth: 3),
                                     if (fullLine2.isNotEmpty) Polyline(points: fullLine2, color: Colors.deepPurple.withValues(alpha: 0.22), strokeWidth: 3),
                                     // Yürüyüş segmentleri
                                     if (opt.walk1.isNotEmpty) Polyline(points: opt.walk1, color: Colors.green.shade600, strokeWidth: 4, pattern: StrokePattern.dashed(segments: [12, 6])),
                                     // Gidilen otobüs segmentleri — kalın, canlı renk
                                     if (opt.bus1.isNotEmpty) Polyline(points: opt.bus1, color: opt.lineName.contains("Araç") ? Colors.redAccent : const Color(0xFF1565C0), strokeWidth: 7),
                                     if (opt.walkTransfer.isNotEmpty) Polyline(points: opt.walkTransfer, color: Colors.orange.shade700, strokeWidth: 4, pattern: StrokePattern.dashed(segments: [12, 6])),
                                     if (opt.bus2.isNotEmpty) Polyline(points: opt.bus2, color: const Color(0xFF6A1B9A), strokeWidth: 7),
                                     if (opt.walk2.isNotEmpty) Polyline(points: opt.walk2, color: Colors.green.shade600, strokeWidth: 4, pattern: StrokePattern.dashed(segments: [12, 6])),
                                   ];
                                  bus1Segment = fullLine1.isNotEmpty ? fullLine1 : opt.bus1;
                                  bus2Segment = fullLine2.isNotEmpty ? fullLine2 : opt.bus2;
                                  showBusStops = !opt.lineName.contains("Araç");
                                });

                                if (fullLine1.isNotEmpty) {
                                  mapController.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(fullLine1), padding: const EdgeInsets.all(50)));
                                }
                                _showSelectedRouteSummary(opt);
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ])),
            ),
          ),
        ),
      ),
    );
  }

  void _showSelectedRouteSummary(RouteOption opt) {
    String displayName = opt.lineName.split('_')[0];
    if (opt.isTransfer && opt.transferLine != null) displayName += " → ${opt.transferLine!.split('_')[0]}";

    final totalWalk1 = _vm.polylineLength(opt.walk1);
    final totalBus1 = _vm.polylineLength(opt.bus1);
    final totalWalkTransfer = _vm.polylineLength(opt.walkTransfer);
    final totalBus2 = _vm.polylineLength(opt.bus2);
    final totalWalk2 = _vm.polylineLength(opt.walk2);

    String? liveBusMsg;
    if (!opt.isTaxi && _simulationManager != null && opt.bus1.isNotEmpty) {
      final stopLoc = opt.bus1.first;
      final baseLine = opt.lineName.split('_')[0];
      final etaGidis = _simulationManager!.calculateEtaMinutes("${baseLine}_Gidis", stopLoc);
      final etaDonus = _simulationManager!.calculateEtaMinutes("${baseLine}_Donus", stopLoc);
      if (etaGidis != null) liveBusMsg = "Canlı Takip: Otobüsünüz tahminen $etaGidis dk sonra durakta.";
      else if (etaDonus != null) liveBusMsg = "Canlı Takip: Otobüsünüz tahminen $etaDonus dk sonra durakta.";
    }

    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: false,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(10),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
              ),
              child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 50, height: 5, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)))),
                Text(opt.isTaxi ? "🚕 $displayName" : "🚌 $displayName", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo)),
                const SizedBox(height: 10),
                if (opt.isTaxi && opt.estimatedFare != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange)),
                    child: Row(children: [const Icon(Icons.account_balance_wallet, color: Colors.orange), const SizedBox(width: 8), Expanded(child: Text("Tahmini Tutar: ${opt.estimatedFare!.toStringAsFixed(0)} TL", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))]),
                  ),
                if (liveBusMsg != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green)),
                    child: Row(children: [const Icon(Icons.sensors, color: Colors.green), const SizedBox(width: 8), Expanded(child: Text(liveBusMsg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))]),
                  ),
                if (opt.isTaxi) ...[
                  _buildStep("${_formatDuration(totalWalk1)} yürü (${opt.startStopName ?? 'taksi durağına'})"),
                  _buildStep("${_formatDuration(totalBus1, isBus: true)} taksi ile git"),
                ] else if (opt.isTransfer) ...[
                  _buildStep("${_formatDuration(totalWalk1)} yürü (${opt.startStopName ?? 'durağa'})"),
                  _buildStep("${_formatDuration(totalBus1, isBus: true)} otobüsle git (${displayName.split(' → ')[0]})"),
                  _buildStep("🔁 ${_formatDuration(totalWalkTransfer)} aktarma (${opt.transferStopName ?? 'aktarma durağı'})"),
                  _buildStep("${_formatDuration(totalBus2, isBus: true)} otobüsle git (${opt.transferLine?.split('_')[0] ?? '2. hat'})"),
                  _buildStep("${_formatDuration(totalWalk2)} yürü (${opt.endStopName ?? 'varışa'})"),
                ] else ...[
                  _buildStep("${_formatDuration(totalWalk1)} yürü (${opt.startStopName ?? 'durağa'})"),
                  _buildStep("${_formatDuration(totalBus1, isBus: true)} otobüsle git"),
                  _buildStep("${_formatDuration(totalWalk2)} yürü (${opt.endStopName ?? 'varışa'})"),
                ],
                const SizedBox(height: 12),
                Divider(color: Colors.blueAccent.withValues(alpha: 0.3)),
                Text("Toplam mesafe: ${opt.totalDistance.toStringAsFixed(0)} m", style: TextStyle(color: Colors.indigo.shade700, fontSize: 14)),
                const SizedBox(height: 4),
                Text("Tahmini toplam süre: ${_formatDuration(opt.totalDistance, isBus: true)} - ${_formatDuration(opt.totalDistance)} arası", style: TextStyle(color: Colors.indigo.shade400, fontSize: 13)),
                if (opt.isTaxi && opt.taxiStand != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity, height: 55,
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFFA726), Color(0xFFFF6F00)]), borderRadius: BorderRadius.circular(15)),
                    child: ElevatedButton.icon(
                      onPressed: () { Navigator.pop(context); _callTaxi(opt.taxiStand!, preCalculatedFare: opt.estimatedFare); },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      icon: const Icon(Icons.phone_forwarded, color: Colors.white, size: 26),
                      label: const Text("BU TAKSİYİ ÇAĞIR", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ])),
            ),
          ),
        ),
      ),
    );
  }

  void _showLineSelector() {
    final allLines = ["A1","B1","B2","B2A","B3","G1","G2","G3","G4","G4A","G4B","G5","G6","G7","G7A","G8","G9","G10","G11","G14","K1","K1A","K2","K3","K4","K5","K6","K7","K7A","K10","K11","M11"];
    allLines.sort();

    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5, minChildSize: 0.4, maxChildSize: 0.9,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(color: const Color(0xFF1A237E).withValues(alpha: 0.95), borderRadius: const BorderRadius.vertical(top: Radius.circular(25))),
          child: Column(children: [
            const SizedBox(height: 15),
            Container(width: 50, height: 5, color: Colors.white30),
            const Padding(padding: EdgeInsets.all(16.0), child: Text("Hat Seçiniz", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
            Expanded(child: ListView.builder(
              controller: scrollController, itemCount: allLines.length,
              itemBuilder: (ctx, index) => ListTile(
                leading: const Icon(Icons.directions_bus, color: Colors.lightBlueAccent),
                title: Text(allLines[index], style: const TextStyle(color: Colors.white, fontSize: 18)),
                trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                onTap: () { Navigator.pop(context); _smartSelectLine(allLines[index]); },
              ),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _buildStep(String text) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
        boxShadow: [BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Text(text, style: const TextStyle(color: Colors.indigo, fontSize: 15, fontWeight: FontWeight.w500)),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, color: Colors.white70, size: 18), const SizedBox(width: 8),
      Text("$label: ", style: const TextStyle(color: Colors.white70, fontSize: 14)),
      Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
    ]);
  }

  Marker _buildSingleTaxiMarker(TaxiStand stand) {
    return Marker(
      point: stand.location, width: 70, height: 70,
      child: Column(children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFFA726), Color(0xFFFF6F00)]),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.5), blurRadius: 12, spreadRadius: 2)],
          ),
          child: const Icon(Icons.local_taxi, color: Colors.white, size: 28),
        ),
        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFF6F00), shape: BoxShape.circle)),
      ]),
    );
  }

  Widget _buildTaxiStandDialog(BuildContext dialogContext, TaxiStand stand) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFFA726), Color(0xFFFF6F00)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Row(children: [Icon(Icons.local_taxi, color: Colors.white, size: 32), SizedBox(width: 12), Expanded(child: Text("Taksi Durağı", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)))]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(stand.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [const Icon(Icons.location_on, color: Colors.white70, size: 18), const SizedBox(width: 6), Expanded(child: Text(stand.address, style: const TextStyle(color: Colors.white70, fontSize: 14)))]),
              const SizedBox(height: 6),
              Row(children: [const Icon(Icons.phone, color: Colors.white70, size: 18), const SizedBox(width: 6), Text(stand.phone, style: const TextStyle(color: Colors.white70, fontSize: 14))]),
            ]),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: TextButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text("Kapat", style: TextStyle(color: Colors.white)),
            )),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: ElevatedButton.icon(
              onPressed: () { Navigator.pop(dialogContext); _callTaxi(stand); },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFFFF6F00), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              icon: const Icon(Icons.phone_forwarded, size: 20),
              label: const Text("Taksi Çağır", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            )),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    if (args != null && endPoint == null) {
      endPoint = LatLng(args["lat"], args["lng"]);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                boxShadow: [BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: AppBar(
                backgroundColor: Colors.transparent,
                centerTitle: true, titleSpacing: 0,
                title: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: widget.destinationName != null
                      ? Text(widget.destinationName!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20))
                      : const _BillboardTitle(),
                ),
                leading: Navigator.canPop(context)
                    ? IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87), onPressed: () => Navigator.of(context).pop())
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Expanded(child: SearchLocationField(
                    controller: _startController, hintText: "Nereden", showCurrentLocationOption: true,
                    onSelected: (lat, lng) { setState(() => startPoint = LatLng(lat, lng)); _moveTo(startPoint!); },
                    onFocus: () => setState(() => activeField = "start"),
                  )),
                  const SizedBox(width: 6),
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.lightBlueAccent]), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: IconButton(
                      icon: const Icon(Icons.swap_vert_rounded, color: Colors.white, size: 28),
                      onPressed: () async {
                        if (startPoint != null && endPoint != null) {
                          final oldStart = _startController.text;
                          final oldEnd = _endController.text;
                          setState(() {
                            final temp = startPoint; startPoint = endPoint; endPoint = temp;
                            _startController.text = oldEnd; _endController.text = oldStart;
                          });
                          await _calculateRoutes();
                        }
                      },
                    ),
                  ),
                ]),
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
                  color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: SingleChildScrollView(child: SearchLocationField(
                  controller: _endController, hintText: "Nereye", showCurrentLocationOption: false,
                  onSelected: (lat, lng) async {
                    setState(() => endPoint = LatLng(lat, lng));
                    if (startPoint != null && endPoint != null) await _calculateRoutes();
                    _moveTo(endPoint!);
                  },
                  onFocus: () => setState(() => activeField = "end"),
                )),
              ),
            ),
          ),
        ),
        Expanded(child: Stack(children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: const LatLng(39.9042, 41.2670), initialZoom: 13,
              onTap: (tapPosition, point) async {
                if (isLoading) return;
                setState(() { if (activeField == "start") startPoint = point; else if (activeField == "end") endPoint = point; });
                if (startPoint != null && endPoint != null) await _calculateRoutes();
              },
            ),
            children: [
              TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png", userAgentPackageName: 'com.example.erzurum_rota'),
              if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
              if (bus1Segment != null) StopsLayer(
                routePoints: bus1Segment!, currentRouteName: suggestedLine, showBusStops: showBusStops,
                simulationManager: _simulationManager, busLines: _vm.busLines, onEnsureLineLoaded: _vm.ensureBusLineLoaded,
                favoriteStopIds: _favoriteStopIds,
              ),
              if (bus2Segment != null && transferLine != null) StopsLayer(
                routePoints: bus2Segment!, currentRouteName: transferLine, showBusStops: showBusStops,
                simulationManager: _simulationManager, busLines: _vm.busLines, onEnsureLineLoaded: _vm.ensureBusLineLoaded,
                favoriteStopIds: _favoriteStopIds,
              ),
              if (_taxiStandMarkers.isNotEmpty) MarkerLayer(markers: _taxiStandMarkers),
              MarkerLayer(markers: _busMarkers),
              if (startPoint != null) MarkerLayer(markers: [Marker(point: startPoint!, width: 40, height: 40, child: const Icon(Icons.location_on, color: Colors.green, size: 40))]),
              if (endPoint != null) MarkerLayer(markers: [Marker(point: endPoint!, width: 40, height: 40, child: const Icon(Icons.flag, color: Colors.red, size: 40))]),
            ],
          ),
          if (isLoading) Positioned.fill(child: AbsorbPointer(
            absorbing: true,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.blueAccent.withValues(alpha: 0.15), Colors.indigo.withValues(alpha: 0.25), Colors.black.withValues(alpha: 0.45)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                child: Center(child: Container(
                  padding: const EdgeInsets.all(24), margin: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: 0.25)), boxShadow: [BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.2), blurRadius: 25, spreadRadius: 5)]),
                  child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Stack(alignment: Alignment.center, children: [
                      SizedBox(height: 80, width: 80, child: CircularProgressIndicator(strokeWidth: 6, value: progress, backgroundColor: Colors.white24, color: Colors.lightBlueAccent)),
                      Text("${(progress * 100).clamp(0, 100).toInt()}%", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 24),
                    const Text("🚌 En iyi rotalar hazırlanıyor...", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    Text(randomTip, style: const TextStyle(color: Colors.white70, fontSize: 15, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: Colors.white10, color: Colors.lightBlueAccent)),
                  ])),
                )),
              ),
            ),
          )),
          if (suggestedOptions.isNotEmpty) ...[
            Positioned(top: 15, right: 15, child: _buildGlassButton(icon: Icons.list_alt_rounded, text: "Önerilere Geri Dön", color: const Color(0xFF2239BB), onTap: () => _showOptionsDialog(context, suggestedOptions))),
            Positioned(top: 80, right: 15, child: _buildGlassButton(icon: Icons.refresh_rounded, text: "Yeni Rota Önerisi", color: const Color(0xFFFF3232), onTap: _resetRouteState)),
          ],
        ])),
      ]),
      floatingActionButton: isRouteMode ? null : Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (suggestedLine == null && !showTaxiStands)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: FloatingActionButton.extended(
              heroTag: "btn_taxi",
              onPressed: () { setState(() => showTaxiStands = true); _updateTaxiStandMarkers(); _showTaxiSelector(); },
              backgroundColor: const Color(0xFFFF6F00),
              icon: const Icon(Icons.local_taxi, color: Colors.white),
              label: const Text("Taksi Bul", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )),
          if (showTaxiStands && suggestedLine == null)
            Padding(padding: const EdgeInsets.only(bottom: 12), child: FloatingActionButton(
              heroTag: "btn_close_taxi",
              onPressed: () => setState(() { showTaxiStands = false; selectedTaxiStand = null; _taxiStandMarkers = []; }),
              backgroundColor: Colors.red,
              child: const Icon(Icons.close, color: Colors.white),
            )),
          if (suggestedLine != null) ...[
            Padding(padding: const EdgeInsets.only(bottom: 12), child: FloatingActionButton(
              heroTag: "btn_swap", onPressed: _toggleDirection, backgroundColor: Colors.orangeAccent,
              child: const Icon(Icons.swap_vert_rounded, color: Colors.white, size: 28),
            )),
            FloatingActionButton(heroTag: "btn_close", onPressed: _clearSelectedLine, backgroundColor: Colors.red, child: const Icon(Icons.close, color: Colors.white, size: 28)),
          ] else if (!showTaxiStands)
            FloatingActionButton.extended(
              heroTag: "btn_select", onPressed: _showLineSelector, backgroundColor: Colors.blueAccent,
              icon: const Icon(Icons.directions_bus, color: Colors.white),
              label: const Text("Hat Seç", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}


Widget _buildGlassButton({required IconData icon, required String text, required Color color, required VoidCallback onTap}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(25),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.50), borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 5))],
        ),
        child: InkWell(
          onTap: onTap, borderRadius: BorderRadius.circular(25), splashColor: Colors.white24,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8),
              Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5, shadows: [Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black26)])),
            ]),
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

  const SearchLocationField({super.key, required this.hintText, required this.onSelected, required this.onFocus, this.showCurrentLocationOption = false, this.controller});

  @override
  State<SearchLocationField> createState() => _SearchLocationFieldState();
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
        if (widget.showCurrentLocationOption) _results.add({"display": "Konumunuz", "lat": null, "lon": null, "isCurrentLocation": true});
      });
      return;
    }
    setState(() => _loading = true);

    final apiKey = dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      debugPrint("❌ GOOGLE_PLACES_API_KEY .env dosyasında bulunamadı!");
      setState(() => _loading = false);
      return;
    }

    try {
      final url = Uri.parse("https://places.googleapis.com/v1/places:searchText");
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "X-Goog-Api-Key": apiKey,
          "X-Goog-FieldMask": "places.displayName,places.location,places.formattedAddress",
        },
        body: json.encode({
          "textQuery": query,
          "languageCode": "tr",
          "locationBias": {
            "circle": {
              "center": {"latitude": 39.9042, "longitude": 41.2670},
              "radius": 50000.0,
            }
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final places = data["places"] as List? ?? [];
        setState(() {
          _results = places.map((e) => {
            "display": e["displayName"]?["text"] ?? e["formattedAddress"] ?? "Bilinmeyen",
            "lat": e["location"]["latitude"],
            "lon": e["location"]["longitude"],
          }).toList();
        });
      } else {
        debugPrint("❌ Places API hatası: ${response.statusCode} - ${response.body}");
        setState(() => _results = []);
      }
    } catch (e) {
      debugPrint("❌ Arama hatası: $e");
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextField(
          controller: _localController,
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: Icon(Icons.search, color: Colors.grey.shade500, size: 22),
            hintStyle: TextStyle(color: Colors.grey.shade900, fontWeight: FontWeight.w400),
            border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
            filled: true, fillColor: Colors.white.withValues(alpha: 0.15),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onChanged: _searchPlaces,
          onTap: () { widget.onFocus(); _searchPlaces(""); },
          onSubmitted: (value) async {
            if (value.isEmpty) return;
            await _searchPlaces(value);
            if (_results.isNotEmpty && _results.first["isCurrentLocation"] != true) {
              final item = _results.first;
              widget.onSelected(item["lat"], item["lon"]);
            _localController.text = item["display"];
              setState(() => _results.clear());
            }
          },
        ),
      ),
      if (_loading) const LinearProgressIndicator(),
      if (_results.isNotEmpty) ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final item = _results[index];
              if (item["isCurrentLocation"] == true) {
                return ListTile(
                  leading: const Icon(Icons.my_location, color: Colors.blue),
                  title: Text(item["display"]),
                  onTap: () async {
                    LocationPermission perm = await Geolocator.checkPermission();
                    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
                    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
                    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                    widget.onSelected(pos.latitude, pos.longitude);
                    _localController.text = "Mevcut konumunuz";
                    setState(() => _results.clear());
                  },
                );
              }
              return ListTile(
                title: Text(item["display"], maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () async {
                  double lat = item["lat"], lon = item["lon"];
                  try {
                    final snapUrl = Uri.parse("https://router.project-osrm.org/nearest/v1/foot/$lon,$lat");
                    final snapResponse = await http.get(snapUrl);
                    if (snapResponse.statusCode == 200) {
                      final data = jsonDecode(snapResponse.body);
                      if (data["waypoints"] != null && data["waypoints"].isNotEmpty) {
                        final snapped = data["waypoints"][0]["location"];
                        lon = snapped[0]; lat = snapped[1];
                      }
                    }
                  } catch (_) {}
                  widget.onSelected(lat, lon);
                  _localController.text = item["display"];
                  setState(() => _results.clear());
                },
              );
            },
          ),
        ),
      ),
    ]);
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
  final List<String> _messages = ["Rota Öneri Sistemi", "Senin Şehrin, Senin Rehberin.", "Erzurum Büyükşehir Belediyesi"];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 3500), (timer) { if (mounted) setState(() => _index = (_index + 1) % _messages.length); });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44, width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Image.asset("assets/icons/erzbblogoformain.png", height: 28, fit: BoxFit.contain),
        const SizedBox(width: 12),
        Expanded(child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          transitionBuilder: (child, animation) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.0, 1.0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Text(_messages[_index], key: ValueKey(_messages[_index]), textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'ProductSans', color: Color(0xFF1A237E), fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.4),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        )),
      ]),
    );
  }
}