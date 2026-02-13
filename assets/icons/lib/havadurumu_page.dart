import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class HavaDurumuPage extends StatefulWidget {
  const HavaDurumuPage({super.key});

  @override
  State<HavaDurumuPage> createState() => _HavaDurumuPageState();
}

class _HavaDurumuPageState extends State<HavaDurumuPage>
    with SingleTickerProviderStateMixin {
  bool loading = true;
  Map<String, dynamic>? weather;
  late AnimationController _controller;

  // 🌤️ kendi API anahtarını yaz
  final String apiKey =
      "fd5b98a82e5b40dd889205029252910"; // <--- burayı değiştir
  final String city = "Erzurum";

  @override
  void initState() {
    super.initState();
    fetchWeather();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
  }

  Future<void> fetchWeather() async {
    try {
      final uri = Uri.parse(
        "http://api.weatherapi.com/v1/current.json?key=$apiKey&q=$city&lang=tr",
      );
      final res = await http.get(uri);

      if (res.statusCode == 200) {
        setState(() {
          weather = jsonDecode(res.body);
          loading = false;
        });
      } else {
        throw Exception("Sunucu hatası: ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("Hava durumu alınamadı: $e");
      setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ☁️ Hava durumuna göre renk ve emoji seç
  Map<String, dynamic> _getThemeForWeather() {
    if (weather == null) {
      return {
        "colors": [const Color(0xFF1A237E), const Color(0xFF64B5F6)],
        "emoji": "🌍",
      };
    }

    final current = weather!["current"];
    final condition = current["condition"]["text"].toString().toLowerCase();
    final isDay = current["is_day"] == 1;

    if (condition.contains("kar")) {
      return {
        "colors": [const Color(0xFF90CAF9), const Color(0xFFE3F2FD)],
        "emoji": "❄️",
      };
    } else if (condition.contains("bulut")) {
      return {
        "colors": [const Color(0xFF546E7A), const Color(0xFF90A4AE)],
        "emoji": "☁️",
      };
    } else if (condition.contains("yağmur") || condition.contains("sağanak")) {
      return {
        "colors": [const Color(0xFF1565C0), const Color(0xFF4FC3F7)],
        "emoji": "🌧️",
      };
    } else if (!isDay) {
      return {
        "colors": [const Color(0xFF0D47A1), const Color(0xFF311B92)],
        "emoji": "🌙",
      };
    } else {
      return {
        "colors": [const Color(0xFF4A90E2), const Color(0xFF81D4FA)],
        "emoji": "☀️",
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _getThemeForWeather();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "Erzurum Hava Durumu",
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
          // 🌈 Aurora arka plan (temaya göre renk)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: List<Color>.from(theme["colors"]),
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
                : weather == null
                ? const Center(
                    child: Text(
                      "Veri alınamadı",
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : _buildWeatherCard(theme["emoji"]),
          ),
        ],
      ),
    );
  }

  // 💎 Cam efektli hava kartı
  Widget _buildWeatherCard(String emoji) {
    final current = weather!["current"];
    final location = weather!["location"];
    final condition = current["condition"];

    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "📍 ${location["name"]}, ${location["country"]}",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            Text(emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 6),
            Image.network("https:${condition["icon"]}", width: 80, height: 80),
            const SizedBox(height: 8),
            Text(
              "${current["temp_c"]}°C",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              condition["text"],
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 12),
            Text(
              "💧 Nem: ${current["humidity"]}%\n💨 Rüzgar: ${current["wind_kph"]} km/s\n🌡️ Hissedilen: ${current["feelslike_c"]}°C",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

// 🌌 Aurora Painter (hareketli ışık dalgası)
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
