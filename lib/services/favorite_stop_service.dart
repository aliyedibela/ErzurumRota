import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FavoriteStopService {
  static const String _kFavoritesKey = 'favorite_stops';

  Future<List<Map<String, dynamic>>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final String? favoritesJson = prefs.getString(_kFavoritesKey);
    if (favoritesJson == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(favoritesJson);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      print('Error decoding favorites: $e');
      return [];
    }
  }

  Future<void> toggleFavorite(Map<String, dynamic> stop, {String? customName}) async {
    final favorites = await getFavorites();
    final stopId = stop['stopId']?.toString();

    if (stopId == null) return;

    final index = favorites.indexWhere((e) => e['stopId'].toString() == stopId);

    if (index >= 0) {
      favorites.removeAt(index);
    } else {
      favorites.add({
        'stopId': stopId,
        'stopName': stop['stopName'],
        'customName': customName,
        'lat': stop['lat'],
        'lng': stop['lng'],
        'routes': stop['routes'],
      });
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFavoritesKey, jsonEncode(favorites));
  }

  Future<bool> isFavorite(String stopId) async {
    final favorites = await getFavorites();
    return favorites.any((e) => e['stopId'].toString() == stopId);
  }
}