import 'dart:async';
import 'dart:math';
import 'package:erzurum_rota/core/utils/stop_utils.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:erzurum_rota/services/bus_simulator.dart';


class AccessibilityService {
  final FlutterTts _tts = FlutterTts();
  final BusSimulationManager? simulationManager;
  final Map<String, List<LatLng>> busLines;
  final void Function(String lineKey)? onEnsureLineLoaded;

  static const _channel = MethodChannel('com.erzurum/stt');

  List<String> favoriteLines = [];
  String? _watchingLine;
  String? get watchingLine => _watchingLine;
  Timer? _etaWatchTimer;
  StreamSubscription<Position>? _locationSub;
  bool _isAnnouncing = false;
  int _listenRetryCount = 0;
  String? _lastAnnouncedStop;

  AccessibilityService({
    this.simulationManager,
    this.busLines = const {},
    this.onEnsureLineLoaded,
  });

  Future<void> init() async {
    await _tts.setLanguage('tr-TR');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    _tts.setCompletionHandler(() {});
    print('✅ AccessibilityService başlatıldı.');
  }

  Future<void> startLocationTracking() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        print('❌ Konum izni reddedildi');
        return;
      }
    }

    print('🗺️ GPS takibi başladı');

    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position pos) {
      _checkNearbyStops(LatLng(pos.latitude, pos.longitude));
    });
  }

  void _checkNearbyStops(LatLng userLoc) {
    if (_isAnnouncing) return;
    if (StopUtils.allStops.isEmpty) return;

    for (var stop in StopUtils.allStops) {
      final lat = double.tryParse(stop['lat'].toString()) ?? 0;
      final lng = double.tryParse(stop['lng'].toString()) ?? 0;
      if (lat == 0 && lng == 0) continue;

      final stopLoc = LatLng(lat, lng);
      final dist = _distanceMeters(userLoc, stopLoc);

      if (dist <= 30) {
        final stopName = stop['stopName'] ??
            stop['display'] ??
            stop['ad'] ??
            stop['name'] ??
            'Durak';

        if (_lastAnnouncedStop == stopName) continue;

        print('📍 Durağa yaklaşıldı: $stopName (${dist.toInt()}m)');
        _lastAnnouncedStop = stopName;

        String linesStr = '';
        if (stop.containsKey('lines')) linesStr = stop['lines'].toString();
        else if (stop.containsKey('hatlar')) linesStr = stop['hatlar'].toString();
        else if (stop.containsKey('routes')) linesStr = stop['routes'].toString();
        else if (stop.containsKey('Lines')) linesStr = stop['Lines'].toString();

        linesStr = linesStr.replaceAll('[', '').replaceAll(']', '');
        final lines = linesStr.split(',').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

        if (lines.isNotEmpty) {
          onApproachStop(
            stopName: stopName,
            stopLoc: stopLoc,
            lines: lines,
          );
        }
        break;
      }
    }

    if (_lastAnnouncedStop != null) {
      bool stillNear = StopUtils.allStops.any((stop) {
        final lat = double.tryParse(stop['lat'].toString()) ?? 0;
        final lng = double.tryParse(stop['lng'].toString()) ?? 0;
        final name = stop['stopName'] ?? stop['display'] ?? stop['ad'] ?? stop['name'] ?? '';
        return name == _lastAnnouncedStop &&
            _distanceMeters(userLoc, LatLng(lat, lng)) <= 80;
      });

      if (!stillNear) {
        print('🚶 Duraktan uzaklaşıldı, sıfırlanıyor');
        _lastAnnouncedStop = null;
      }
    }
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLon = (b.longitude - a.longitude) * pi / 180;
    final x = sin(dLat / 2) * sin(dLat / 2) +
        cos(a.latitude * pi / 180) *
            cos(b.latitude * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return R * 2 * atan2(sqrt(x), sqrt(1 - x));
  }

  void stopLocationTracking() {
    _locationSub?.cancel();
    _locationSub = null;
    _lastAnnouncedStop = null;
    print('🛑 GPS takibi durduruldu');
  }

  Future<void> onApproachStop({
    required String stopName,
    required LatLng stopLoc,
    required List<String> lines,
  }) async {
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 200));
    HapticFeedback.heavyImpact();

    final favInStop = favoriteLines
        .where((f) => lines.any((l) =>
            l.trim().replaceAll('/', '').replaceAll('-', '') == f))
        .toList();

    if (favInStop.isNotEmpty) {
      final line = favInStop.first;
      final eta = _getEta(line, stopLoc);
      if (eta != null) {
        await _speak('$stopName durağındasınız. Favori hattınız $line, $eta dakika sonra geliyor.');
        _startWatching(line, stopLoc, eta);
      } else {
        await _speak('$stopName durağındasınız. Favori hattınız $line için veri bulunamadı.');
      }
    } else {
      await _announceAllLines(stopName, stopLoc, lines);
    }
  }

  Future<void> _announceAllLines(
    String stopName,
    LatLng stopLoc,
    List<String> lines,
  ) async {
    if (_isAnnouncing) return;
    _isAnnouncing = true;

    final etaList = <Map<String, dynamic>>[];

    for (var line in lines) {
      final clean = line.trim().replaceAll('/', '').replaceAll('-', '');
      onEnsureLineLoaded?.call('${clean}_Gidis');
      onEnsureLineLoaded?.call('${clean}_Donus');
      final eta = _getEta(clean, stopLoc);
      if (eta != null) etaList.add({'line': clean, 'eta': eta});
    }

    etaList.sort((a, b) => (a['eta'] as int).compareTo(b['eta'] as int));

    if (etaList.isEmpty) {
      await _speak('$stopName durağındasınız. Yakın otobüs bulunamadı.');
      _isAnnouncing = false;
      return;
    }

    final best = etaList.first;
    final msg = StringBuffer();
    msg.write('$stopName durağındasınız. ');
    msg.write('En yakın otobüs ${best['line']}, ${best['eta']} dakika sonra geliyor. ');

    if (etaList.length > 1) {
      msg.write('Diğer hatlar: ');
      for (var i = 1; i < etaList.length && i < 4; i++) {
        msg.write('${etaList[i]['line']}, ${etaList[i]['eta']} dakika. ');
      }
    }

    msg.write('Takip etmek için hat adını söyleyin.');
    await _speak(msg.toString());

    _listenRetryCount = 0;
    await _listenForLineChoice(stopLoc, etaList);
    _isAnnouncing = false;
  }

  Future<void> _listenForLineChoice(
    LatLng stopLoc,
    List<Map<String, dynamic>> etaList,
  ) async {
    if (_listenRetryCount >= 2) {
      _listenRetryCount = 0;
      final best = etaList.first;
      await _speak('${best['line']} otomatik seçildi. ${best['eta']} dakika sonra geliyor.');
      _startWatching(best['line'], stopLoc, best['eta']);
      return;
    }

    try {
      await _speak('Dinliyorum.');
      final String? spoken = await _channel.invokeMethod<String>('startListening');

      if (spoken == null || spoken.trim().isEmpty) {
        _listenRetryCount++;
        await _speak('Anlamadım, tekrar söyleyin.');
        await _listenForLineChoice(stopLoc, etaList);
        return;
      }

      _listenRetryCount = 0;
      print('🎤 Duyulan: $spoken');
      final spokenUpper = spoken.toUpperCase().trim();

      final matched = etaList.firstWhere(
        (e) => spokenUpper.contains(e['line'].toString().toUpperCase()),
        orElse: () => <String, dynamic>{},
      );

      if (matched.isNotEmpty) {
        final line = matched['line'] as String;
        final eta = matched['eta'] as int;
        await _speak('$line seçildi. $eta dakika sonra geliyor. Haber vereceğim.');
        _startWatching(line, stopLoc, eta);
      } else {
        _listenRetryCount++;
        await _speak('Anlamadım. B1, B3 gibi hat adını söyleyin.');
        await _listenForLineChoice(stopLoc, etaList);
      }
    } catch (e) {
      print('❌ STT hatası: $e');
      _listenRetryCount = 0;
      final best = etaList.first;
      await _speak('Ses tanıma çalışmadı. ${best['line']} seçildi.');
      _startWatching(best['line'], stopLoc, best['eta']);
    }
  }

  void _startWatching(String line, LatLng stopLoc, int initialEta) {
    _watchingLine = line;
    _etaWatchTimer?.cancel();
    int lastEta = initialEta;

    _etaWatchTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final eta = _getEta(line, stopLoc);
      if (eta == null) return;
      print('⏱ $line ETA: $eta dk');

      if (eta <= 2 && lastEta > 2) {
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 200));
        HapticFeedback.heavyImpact();
        await _speak('$line otobüsü 2 dakika sonra geliyor! Hazır olun.');
      }

      if (eta <= 1 && lastEta > 1) {
        for (int i = 0; i < 3; i++) {
          HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 150));
        }
        await _speak('$line otobüsü 1 dakika sonra geliyor!');
      }

      if (eta == 0) {
        for (int i = 0; i < 5; i++) {
          HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 150));
        }
        await _speak('$line otobüsü şu an durağa ulaştı! Binin.');
        _etaWatchTimer?.cancel();
        _watchingLine = null;
      }

      lastEta = eta;
    });
  }

  int? _getEta(String cleanLine, LatLng stopLoc) {
    final etaGidis =
        simulationManager?.calculateEtaMinutes('${cleanLine}_Gidis', stopLoc) ??
        simulationManager?.getGhostEta('${cleanLine}_Gidis', stopLoc, busLines);
    final etaDonus =
        simulationManager?.calculateEtaMinutes('${cleanLine}_Donus', stopLoc) ??
        simulationManager?.getGhostEta('${cleanLine}_Donus', stopLoc, busLines);

    if (etaGidis != null && etaDonus != null) {
      return etaGidis < etaDonus ? etaGidis : etaDonus;
    }
    return etaGidis ?? etaDonus;
  }

  Future<void> _speak(String text) async {
    print('🔊 TTS: $text');
    final completer = Completer<void>();
    await _tts.stop();
    await Future.delayed(const Duration(milliseconds: 300));
    _tts.setCompletionHandler(() {
      if (!completer.isCompleted) completer.complete();
    });
    _tts.setCancelHandler(() {
      if (!completer.isCompleted) completer.complete();
    });
    await _tts.speak(text);
    await completer.future.timeout(const Duration(seconds: 30), onTimeout: () {});
    await Future.delayed(const Duration(milliseconds: 300));
  }

  void toggleFavorite(String line) {
    if (favoriteLines.contains(line)) {
      favoriteLines.remove(line);
    } else {
      favoriteLines.add(line);
    }
  }

  void stopWatching() {
    _etaWatchTimer?.cancel();
    _watchingLine = null;
    _tts.stop();
  }

  void dispose() {
    stopLocationTracking();
    _etaWatchTimer?.cancel();
    _tts.stop();
  }
}