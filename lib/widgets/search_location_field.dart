import 'dart:convert';
import 'package:flutter/material.dart';
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
  static const String _googleApiKey = ""; // API key buraya
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

    try {
      final url = Uri.parse(
        "https://maps.googleapis.com/maps/api/place/textsearch/json"
        "?query=${Uri.encodeComponent(query)}&key=$_googleApiKey",
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data["status"] == "OK") {
          setState(() {
            _results = (data["results"] as List)
                .map((e) => {
                      "display": e["name"],
                      "lat": e["geometry"]["location"]["lat"],
                      "lon": e["geometry"]["location"]["lng"],
                    })
                .toList();
          });
        } else {
          setState(() => _results = []);
        }
      }
    } catch (e) {
      print("❌ Arama hatası: $e");
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
              fillColor: Colors.white.withOpacity(0.15),
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
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final item = _results[index];

                if (item["isCurrentLocation"] == true) {
                  return ListTile(
                    leading:
                        const Icon(Icons.my_location, color: Colors.blue),
                    title: Text(item["display"]),
                    onTap: () async {
                      LocationPermission perm =
                          await Geolocator.checkPermission();
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
      ],
    );
  }
}