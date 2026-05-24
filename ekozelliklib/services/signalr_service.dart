import 'package:signalr_core/signalr_core.dart';
import 'package:uuid/uuid.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:erzurum_rota/models/taxi_stand.dart';

typedef TaxiAcceptedCallback = void Function(String driverName, String plate);
typedef TaxiRejectedCallback = void Function();

class SignalRService {
  static const String _baseUrl =
      "https://taksiappbackendnet-production.up.railway.app";
  static const String _hubUrl = "$_baseUrl/taxiHub";

  HubConnection? _hubConnection;
  String? _waitingRequestId;

  HubConnection? get hubConnection => _hubConnection;
  String? get waitingRequestId => _waitingRequestId;
  set waitingRequestId(String? val) => _waitingRequestId = val;

  bool get isConnected => _hubConnection?.state == HubConnectionState.connected;

  /// Railway.app servisi uyku modundaysa uyandırmak için ping atar.
  Future<void> _pingBackend() async {
    try {
      await http
          .get(Uri.parse("$_baseUrl/health"))
          .timeout(const Duration(seconds: 8));
      print("✅ Backend ping başarılı");
    } catch (e) {
      print("⚠️ Backend ping timeout (uyku modunda olabilir): $e");
    }
  }

  Future<void> connect({
    required TaxiAcceptedCallback onAccepted,
    required TaxiRejectedCallback onRejected,
  }) async {
    try {
      // Railway.app backend'i uyandır
      await _pingBackend();

      _hubConnection = HubConnectionBuilder()
          .withUrl(
            _hubUrl,
            HttpConnectionOptions(
              transport: HttpTransportType.webSockets,
              skipNegotiation: true,
            ),
          )
          .withAutomaticReconnect([0, 2000, 5000, 10000])
          .build();

      _hubConnection!.off("TaxiAccepted");
      _hubConnection!.off("TaxiRejected");

      _hubConnection!.on("TaxiAccepted", (args) {
        final data = Map<String, dynamic>.from(args?[0] as Map);
        if (data['requestId'] == _waitingRequestId) {
          _waitingRequestId = null;
          onAccepted(
            data['driverName']?.toString() ?? '-',
            data['plate']?.toString() ?? '-',
          );
        }
      });

      _hubConnection!.on("TaxiRejected", (args) {
        final data = Map<String, dynamic>.from(args?[0] as Map);
        if (data['requestId'] == _waitingRequestId) {
          _waitingRequestId = null;
          onRejected();
        }
      });

      await _hubConnection!.start();
      print("✅ SignalR bağlandı");
    } catch (e) {
      print("❌ SignalR bağlantı hatası: $e — LongPolling ile deneniyor...");
      await _connectWithLongPolling(onAccepted: onAccepted, onRejected: onRejected);
    }
  }

  /// WebSocket başarısız olursa LongPolling ile dene.
  Future<void> _connectWithLongPolling({
    required TaxiAcceptedCallback onAccepted,
    required TaxiRejectedCallback onRejected,
  }) async {
    try {
      _hubConnection = HubConnectionBuilder()
          .withUrl(
            _hubUrl,
            HttpConnectionOptions(
              transport: HttpTransportType.longPolling,
            ),
          )
          .withAutomaticReconnect([0, 2000, 5000, 10000])
          .build();

      _hubConnection!.off("TaxiAccepted");
      _hubConnection!.off("TaxiRejected");

      _hubConnection!.on("TaxiAccepted", (args) {
        final data = Map<String, dynamic>.from(args?[0] as Map);
        if (data['requestId'] == _waitingRequestId) {
          _waitingRequestId = null;
          onAccepted(
            data['driverName']?.toString() ?? '-',
            data['plate']?.toString() ?? '-',
          );
        }
      });

      _hubConnection!.on("TaxiRejected", (args) {
        final data = Map<String, dynamic>.from(args?[0] as Map);
        if (data['requestId'] == _waitingRequestId) {
          _waitingRequestId = null;
          onRejected();
        }
      });

      await _hubConnection!.start();
      print("✅ SignalR LongPolling ile bağlandı");
    } catch (e) {
      print("❌ SignalR LongPolling de başarısız: $e");
    }
  }

  Future<void> requestTaxi({
    required TaxiStand stand,
    required LatLng startPoint,
    LatLng? endPoint,
    required double fare,
  }) async {
    if (_hubConnection == null || !isConnected) {
      throw Exception("SignalR bağlantısı yok. Önce connect() çağırın.");
    }

    final requestId = const Uuid().v4();
    _waitingRequestId = requestId;

    await _hubConnection!.invoke(
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

  Future<void> disconnect() async {
    await _hubConnection?.stop();
    _hubConnection = null;
    print("🔌 SignalR bağlantısı kesildi");
  }
}
