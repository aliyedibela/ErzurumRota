import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'eczane.dart';
import 'route_page.dart';

class EczanePage extends StatefulWidget {
  const EczanePage({super.key});

  @override
  State<EczanePage> createState() => _EczanePageState();
}

class _EczanePageState extends State<EczanePage>
    with SingleTickerProviderStateMixin {
  late Future<List<Eczane>> futureEczaneler;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    futureEczaneler = fetchEczaneler();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<LatLng?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen konum servisini açın')),
        );
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Konum izni verilmedi')));
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (e) {
      return null;
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
 
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    final Uri launchUri = Uri(scheme: 'tel', path: cleanNumber);

    try {
      await launchUrl(launchUri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Arama başlatılamadı: $cleanNumber")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "Nöbetçi Eczaneler",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
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
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                futureEczaneler = fetchEczaneler();
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1A237E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) =>
                CustomPaint(painter: _AuroraPainter(_controller.value)),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(color: Colors.white.withOpacity(0.05)),
          ),

    
          SafeArea(
            child: FutureBuilder<List<Eczane>>(
              future: futureEczaneler,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 48,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Veri alınamadı. İnternetinizi kontrol edin.",
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      "Şu an nöbetçi eczane bulunamadı.",
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                final eczaneler = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                  itemCount: eczaneler.length,
                  itemBuilder: (context, i) {
                    return _buildEczaneCard(eczaneler[i]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEczaneCard(Eczane e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Image.asset(
                        "assets/icons/eczane.png",
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.local_pharmacy,
                              color: Colors.redAccent,
                              size: 30,
                            ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.ad,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              e.ilce.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onLongPress: () {
                  Clipboard.setData(ClipboardData(text: e.adres));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Adres kopyalandı")),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  color: Colors.black.withOpacity(0.1),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: Colors.white70,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.adres,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40, 
                        child: ElevatedButton.icon(
                          onPressed: () => _makePhoneCall(e.telefon),
                          icon: const Icon(Icons.phone, size: 18),
                          label: const Text(
                            "ARA",
                            style: TextStyle(fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.withOpacity(0.8),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 40, 
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final current = await _getCurrentLocation();
                            if (current != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RoutePage(
                                    startPoint: current,
                                    destination: LatLng(e.lat, e.lng),
                                    destinationName: e.ad,
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Konum alınamadı'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.directions, size: 18),
                          label: const Text(
                            "YOL TARİFİ",
                            style: TextStyle(fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.blue.shade900,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double t;
  _AuroraPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.cyanAccent.withOpacity(0.15),
          Colors.blueAccent.withOpacity(0.1),
          Colors.purpleAccent.withOpacity(0.12),
        ],
        begin: Alignment(-1 + t * 2, -1),
        end: Alignment(1 - t * 2, 1),
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) => true;
}
