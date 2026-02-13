import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SonDepremlerPage extends StatefulWidget {
  const SonDepremlerPage({super.key});

  @override
  State<SonDepremlerPage> createState() => _SonDepremlerPageState();
}

class _SonDepremlerPageState extends State<SonDepremlerPage>
    with SingleTickerProviderStateMixin {
  bool loading = true;
  List<dynamic> quakes = [];
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    fetchQuakes();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
  }

  Future<void> fetchQuakes() async {
    try {
      final uri = Uri.parse(
        "https://api.orhanaydogdu.com.tr/deprem/afad/live?limit=50",
      );
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          quakes = data["result"]
              .where(
                (q) =>
                    q["title"] != null &&
                    q["title"].toString().toUpperCase().contains("ERZURUM"),
              )
              .toList();
          loading = false;
        });
      } else {
        throw Exception("Sunucu hatası: ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("AFAD verisi alınamadı: $e");
      setState(() => loading = false);
    }
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
          "Erzurum'daki Son Depremler",
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
          SafeArea(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : quakes.isEmpty
                ? const Center(
                    child: Text(
                      "Son 50 deprem arasında Erzurum bulunamadı.",
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: quakes.length,
                    itemBuilder: (context, i) {
                      final q = quakes[i];
                      return _buildQuakeCard(q);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuakeCard(dynamic q) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.25),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "📍 ${q["title"] ?? "Bilinmiyor"}",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "📅 ${q["date"] ?? ""}",
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            "💥 Büyüklük: ${q["mag"]}  •  Derinlik: ${q["depth"]} km",
            style: const TextStyle(color: Colors.orangeAccent, fontSize: 14),
          ),
        ],
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
