import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// Önceki adımda oluşturduğumuz servis dosyasını import ediyoruz
import 'yaklasanetkinlikler.dart';

class YaklasanEtkinliklerPage extends StatefulWidget {
  const YaklasanEtkinliklerPage({super.key});

  @override
  State<YaklasanEtkinliklerPage> createState() =>
      _YaklasanEtkinliklerPageState();
}

class _YaklasanEtkinliklerPageState extends State<YaklasanEtkinliklerPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Servisimizden gelecek veriyi tutacak future
  late Future<List<Etkinlik>> futureEtkinlikler;

  @override
  void initState() {
    super.initState();
    // Aurora animasyonu için controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);

    // 🔥 BURASI DEĞİŞTİ: Artık yeni servisten tüm verileri çekiyoruz
    futureEtkinlikler = tumEtkinlikleriGetir();
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
          "Yaklaşan Etkinlikler 🎭",
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
                futureEtkinlikler = tumEtkinlikleriGetir();
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 🌈 Arka plan (Aurora efekti)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A237E), Color(0xFF64B5F6)],
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

          // 📋 Etkinlik listesi
          SafeArea(
            child: FutureBuilder<List<Etkinlik>>(
              future: futureEtkinlikler,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Hata: ${snapshot.error}",
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      "Hiç etkinlik bulunamadı",
                      style: TextStyle(color: Colors.white70),
                    ),
                  );
                }

                final etkinlikler = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: etkinlikler.length,
                  itemBuilder: (context, i) {
                    final e = etkinlikler[i];
                    return _buildEventCard(e);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 💎 Cam efektli ve görselli kart
  Widget _buildEventCard(Etkinlik e) {
    // Kaynağa göre renk belirle (Passo: Yeşil, Bubilet: Turuncu)
    final isPasso = e.kaynak == "Passo";
    final sourceColor = isPasso
        ? const Color.fromARGB(255, 255, 30, 0)
        : Colors.greenAccent.shade400;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                final uri = Uri.parse(e.link);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🖼️ Afiş Varsa Göster (Üst Kısım)
                  if (e.afisUrl != null)
                    SizedBox(
                      height: 150,
                      width: double.infinity,
                      child: Image.network(
                        e.afisUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (c, o, s) => Container(
                          color: Colors.black12,
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ),

                  // 📝 Bilgiler (Alt Kısım)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sol taraf (İkon veya Kaynak Badge)
                        Column(
                          children: [
                            const Icon(
                              Icons.event,
                              color: Colors.white,
                              size: 28,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: sourceColor.withOpacity(0.7),
                                ),
                                borderRadius: BorderRadius.circular(6),
                                color: sourceColor.withOpacity(0.1),
                              ),
                              child: Text(
                                e.kaynak.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: sourceColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),

                        // Orta kısım (Metinler)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.ad,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _buildInfoRow(
                                Icons.location_on_outlined,
                                e.mekan,
                              ),
                              const SizedBox(height: 4),
                              _buildInfoRow(Icons.access_time, e.tarih),
                              const SizedBox(height: 8),
                              Text(
                                "🎟 ${e.fiyat}",
                                style: TextStyle(
                                  color: Colors.yellowAccent.shade100,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Sağ Taraf (Link İkonu)
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white54,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.white70),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.1,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// 🌌 Aurora Painter (Senin orijinal efektin)
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
