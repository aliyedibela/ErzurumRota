import 'package:signalr_core/signalr_core.dart';
import 'package:uuid/uuid.dart';
import 'package:latlong2/latlong.dart';
import 'package:erzurum_rota/models/taxi_stand.dart';

typedef TaxiAcceptedCallback = void Function(String driverName, String plate);
typedef TaxiRejectedCallback = void Function();

class SignalRService {
  static const String _hubUrl =
      "https://jannette-acrogynous-allene.ngrok-free.dev/taxiHub";

  HubConnection? _hubConnection;
  String? _waitingRequestId;

  HubConnection? get hubConnection => _hubConnection;
  String? get waitingRequestId => _waitingRequestId;
  set waitingRequestId(String? val) => _waitingRequestId = val;

  bool get isConnected => _hubConnection?.state == HubConnectionState.connected;

  Future<void> connect({
    required TaxiAcceptedCallback onAccepted,
    required TaxiRejectedCallback onRejected,
  }) async {
    try {
      _hubConnection = HubConnectionBuilder()
          .withUrl(_hubUrl)
          .withAutomaticReconnect()
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
      print("❌ SignalR bağlantı hatası: $e");
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
