import 'package:latlong2/latlong.dart';

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