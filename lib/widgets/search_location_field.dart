import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';


class SearchLocationField extends StatefulWidget {
  final String hintText;
  final VoidCallback onFocus;
  final void Function(double lat, double lng) onSelected;
  final bool showCurrentLocationOption;
  final TextEditingController? controller;

  const SearchLocationField({
    super.key,
    required this.hintText,
    required this.onSelected,
    required this.onFocus,
    this.showCurrentLocationOption = false,
    this.controller,
  });

  @override
  State<SearchLocationField> createState() => _SearchLocationFieldState();
}

class _SearchLocationFieldState extends State<SearchLocationField> {
  static String get _googleApiKey => dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '';
  static const String _osrmBase = "https://router.project-osrm.org";

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

    // API key kontrolü
    final apiKey = _googleApiKey;
    if (apiKey.isEmpty) {
      debugPrint("❌ GOOGLE_PLACES_API_KEY .env dosyasından okunamadı!");
      setState(() => _loading = false);
      return;
    }

    try {
      // Yeni Places API (v1) — Text Search
      final url = Uri.parse("https://places.googleapis.com/v1/places:searchText");
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "X-Goog-Api-Key": apiKey,
          "X-Goog-FieldMask":
              "places.displayName,places.location,places.formattedAddress",
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
          _results = places
              .map((e) => {
                    "display": e["displayName"]?["text"] ??
                        e["formattedAddress"] ??
                        "Bilinmeyen",
                    "lat": e["location"]["latitude"],
                    "lon": e["location"]["longitude"],
                  })
              .toList();
        });
      } else {
        debugPrint("❌ Places API hatası: ${response.statusCode}");
        debugPrint("❌ Yanıt: ${response.body}");
        setState(() => _results = []);
      }
    } catch (e) {
      debugPrint("❌ Arama hatası: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<(double lat, double lon)> _snapToRoad(
      double lat, double lon) async {
    try {
      final snapUrl = Uri.parse(
          "$_osrmBase/nearest/v1/walking/$lon,$lat");
      final snapResponse = await http.get(snapUrl);

      if (snapResponse.statusCode == 200) {
        final data = jsonDecode(snapResponse.body);
        if (data["waypoints"] != null && data["waypoints"].isNotEmpty) {
          final snapped = data["waypoints"][0]["location"];
          return (snapped[1] as double, snapped[0] as double);
        }
      }
    } catch (_) {}
    return (lat, lon);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _localController,
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixIcon:
                  Icon(Icons.search, color: Colors.grey.shade500, size: 22),
              hintStyle: TextStyle(
                color: Colors.grey.shade900,
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.15),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onChanged: _searchPlaces,
            onTap: () {
              widget.onFocus();
              _searchPlaces("");
            },
            onSubmitted: (value) async {
              if (value.isEmpty) return;
              await _searchPlaces(value);
              if (_results.isNotEmpty && _results.first["isCurrentLocation"] != true) {
                final item = _results.first;
                final (lat, lon) =
                    await _snapToRoad(item["lat"], item["lon"]);
                widget.onSelected(lat, lon);
                _localController.text = item["display"];
                setState(() => _results.clear());
              }
            },
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_results.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ],
              ),
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
                        if (perm == LocationPermission.denied) {
                          perm = await Geolocator.requestPermission();
                        }
                        if (perm == LocationPermission.denied ||
                            perm == LocationPermission.deniedForever) return;

                        final pos = await Geolocator.getCurrentPosition(
                            desiredAccuracy: LocationAccuracy.high);
                        widget.onSelected(pos.latitude, pos.longitude);
                        _localController.text = "Mevcut konumunuz";
                        setState(() => _results.clear());
                      },
                    );
                  }

                  return ListTile(
                    title: Text(item["display"],
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () async {
                      final (lat, lon) =
                          await _snapToRoad(item["lat"], item["lon"]);
                      widget.onSelected(lat, lon);
                      _localController.text = item["display"];
                      setState(() => _results.clear());
                    },
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
