import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../services/favorite_stop_service.dart';
import '../../core/utils/stop_utils.dart';
import '../rota/route_page.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final _favSvc = FavoriteStopService();
  List<Map<String, dynamic>> _favorites = [];
  List<Map<String, dynamic>> _searchResults = [];
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    StopUtils.loadAllStops();
  }

  Future<void> _loadFavorites() async {
    final favs = await _favSvc.getFavorites();
    setState(() => _favorites = favs);
  }

  void _searchStops(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    final results = StopUtils.allStops.where((stop) {
      final name = (stop['stopName'] ?? '').toString().toLowerCase();
      return name.contains(query.toLowerCase());
    }).take(20).toList();

    setState(() {
      _searchResults = results;
      _isSearching = true;
    });
  }

  void _showAddFavoriteDialog(Map<String, dynamic> stop) {
    final nameController = TextEditingController(text: stop['stopName']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A237E),
        title: const Text("Favoriye Ekle", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: "Durak Adı (Örn: Evim, İş)",
            labelStyle: TextStyle(color: Colors.white70),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              await _favSvc.toggleFavorite(stop, customName: nameController.text);
              Navigator.pop(ctx);
              _loadFavorites();
              setState(() {
                _searchController.clear();
                _isSearching = false;
              });
            },
            child: const Text("Ekle"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Favori Duraklarım", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1A237E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: kToolbarHeight + 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    color: Colors.white.withOpacity(0.1),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _searchStops,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "Durak Ara ve Ekle...",
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                        prefixIcon: const Icon(Icons.search, color: Colors.white70),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isSearching ? _buildSearchResults() : _buildFavoritesList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return const Center(child: Text("Durak bulunamadı", style: TextStyle(color: Colors.white70)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      itemBuilder: (ctx, index) {
        final stop = _searchResults[index];
        return Card(
          color: Colors.white.withOpacity(0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.bus_alert, color: Colors.lightBlueAccent),
            title: Text(stop['stopName'] ?? 'Durak', style: const TextStyle(color: Colors.white)),
            trailing: const Icon(Icons.add_circle_outline, color: Colors.white70),
            onTap: () => _showAddFavoriteDialog(stop),
          ),
        );
      },
    );
  }

  Widget _buildFavoritesList() {
    if (_favorites.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_border, color: Colors.white24, size: 64),
            SizedBox(height: 16),
            Text("Henüz favori durağınız yok", style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _favorites.length,
      itemBuilder: (ctx, index) {
        final stop = _favorites[index];
        return Card(
          color: Colors.white.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.favorite, color: Colors.redAccent),
            title: Text(stop['customName'] ?? stop['stopName'] ?? 'Durak', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: stop['customName'] != null ? Text(stop['stopName'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)) : null,
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white54),
              onPressed: () async {
                await _favSvc.toggleFavorite(stop);
                _loadFavorites();
              },
            ),
            onTap: () {
              final lat = double.tryParse(stop['lat'].toString()) ?? 0;
              final lng = double.tryParse(stop['lng'].toString()) ?? 0;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RoutePage(
                    destination: LatLng(lat, lng),
                    destinationName: stop['stopName'],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
