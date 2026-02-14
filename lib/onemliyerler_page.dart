import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'route_page.dart';

class OnemliYer {
  final String ad;
  final String aciklama;
  final String foto;
  final double lat;
  final double lng;

  OnemliYer({
    required this.ad,
    required this.aciklama,
    required this.foto,
    required this.lat,
    required this.lng,
  });
}

class OnemliYerlerPage extends StatefulWidget {
  const OnemliYerlerPage({super.key});

  @override
  State<OnemliYerlerPage> createState() => _OnemliYerlerPageState();
}

class _OnemliYerlerPageState extends State<OnemliYerlerPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Future<LatLng?> _getCurrentLocation() async {
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
    );
    return LatLng(pos.latitude, pos.longitude);
  }

  final List<OnemliYer> yerler = [
    OnemliYer(
      ad: "Çifte Minareli Medrese",
      aciklama:
          "Erzurum’un sembolü. Selçuklu mimarisinin en görkemli eserlerinden biri olan bu medrese, 13. yüzyıldan kalma muhteşem bir tarihi yapıdır.",
      foto: "assets/yerler/cifte_minareli.jpg",
      lat: 39.906648,
      lng: 41.276155,
    ),
    OnemliYer(
      ad: "Yakutiye Medresesi",
      aciklama:
          "Erzurum’un merkezinde yer alan bu taş işçiliğiyle ünlü medrese, 1310 yılında yapılmıştır. Şehrin tarihini ve kültürünü yansıtır.",
      foto: "assets/yerler/yakutiye.jpg",
      lat: 39.906123,
      lng: 41.271948,
    ),
    OnemliYer(
      ad: "Ulu Cami",
      aciklama:
          "Selçuklu döneminden kalan Ulu Cami, 1179’da inşa edilmiştir. Şehrin kalbinde yer alır ve tarih kokar.",
      foto: "assets/yerler/ulu_cami.jpg",
      lat: 39.905412,
      lng: 41.272183,
    ),
    OnemliYer(
      ad: "Aziziye Tabyaları",
      aciklama:
          "Nene Hatun’un kahramanlık destanına sahne olmuş, 93 Harbi’nden bu yana tarihe tanıklık eden tabyalar.",
      foto: "assets/yerler/aziziye_tabyalari.jpg",
      lat: 39.958128,
      lng: 41.229534,
    ),
    OnemliYer(
      ad: "Üç Kümbetler",
      aciklama:
          "Selçuklu döneminden kalma üç anıtsal türbe. Tarih ve maneviyatın birleştiği nokta.",
      foto: "assets/yerler/uc_kumbetler.jpg",
      lat: 39.907975,
      lng: 41.278034,
    ),
    OnemliYer(
      ad: "Abdurrahman Gazi Türbesi",
      aciklama:
          "Maneviyatı yüksek, huzur dolu bir ziyaret noktasıdır. Şehit Abdurrahman Gazi’nin türbesi burada yer alır.",
      foto: "assets/yerler/abdurrahman_gazi.jpg",
      lat: 39.875884,
      lng: 41.317994,
    ),
    OnemliYer(
      ad: "Lala Mustafa Paşa Camii",
      aciklama:
          "Osmanlı döneminin zarif taş işçiliğini taşıyan bu cami, Lala Mustafa Paşa tarafından yaptırılmıştır.",
      foto: "assets/yerler/lala_mustafa.jpg",
      lat: 39.905821,
      lng: 41.271562,
    ),
    OnemliYer(
      ad: "Paşa Bey Konağı",
      aciklama:
          "Erzurum’un geleneksel mimarisini yaşatan, ahşap süslemeli tarihi konak. Kültürel mirasın en güzel örneklerinden biri.",
      foto: "assets/yerler/pasabay_konagi.jpg",
      lat: 39.905650,
      lng: 41.268150,
    ),
  ];

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "Önemli Yerler",
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
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: yerler.length,
              itemBuilder: (context, i) {
                final y = yerler[i];
                return _buildPlaceCard(context, y);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceCard(BuildContext context, OnemliYer y) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: Image.asset(
                  y.foto,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      y.ad,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      y.aciklama,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final current = await _getCurrentLocation();
                          if (current != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RoutePage(
                                  startPoint: current,
                                  destination: LatLng(y.lat, y.lng),
                                  destinationName: y.ad,
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Konum alınamadı')),
                            );
                          }
                        },
                        icon: const Icon(Icons.route, color: Colors.white),
                        label: const Text(
                          "Nasıl Giderim?",
                          style: TextStyle(color: Colors.white),
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
