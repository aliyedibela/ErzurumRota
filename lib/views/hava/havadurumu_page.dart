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
  String? errorMsg;
  late AnimationController _controller;

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
    setState(() {
      loading = true;
      errorMsg = null;
    });
    try {
      // Open-Meteo: tamamen ücretsiz, API key gerektirmez
      final uri = Uri.parse(
        "https://api.open-meteo.com/v1/forecast"
        "?latitude=39.9055&longitude=41.2658"
        "&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code,apparent_temperature"
        "&timezone=Europe%2FIstanbul",
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));

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
      setState(() {
        loading = false;
        errorMsg = "Hava durumu alınamadı. İnternet bağlantınızı kontrol edin.";
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getWeatherDescription(int code) {
    if (code == 0) return "Açık Hava";
    if (code == 1) return "Az Bulutlu";
    if (code == 2) return "Parçalı Bulutlu";
    if (code == 3) return "Bulutlu";
    if (code <= 48) return "Sisli";
    if (code <= 55) return "Çiseleyen Yağmur";
    if (code <= 57) return "Dondurucu Çiseleyen";
    if (code <= 65) return "Yağmurlu";
    if (code <= 67) return "Dondurucu Yağmur";
    if (code <= 75) return "Karlı";
    if (code == 77) return "Kar Taneleri";
    if (code <= 82) return "Sağanak Yağışlı";
    if (code <= 86) return "Karlı Sağanak";
    if (code <= 99) return "Gök Gürültülü Fırtına";
    return "Bilinmiyor";
  }

  String _getWeatherEmoji(int code) {
    if (code == 0) return "☀️";
    if (code <= 2) return "⛅";
    if (code == 3) return "☁️";
    if (code <= 48) return "🌫️";
    if (code <= 67) return "🌧️";
    if (code <= 77) return "❄️";
    if (code <= 82) return "🌦️";
    if (code <= 86) return "🌨️";
    if (code <= 99) return "⛈️";
    return "🌍";
  }

  Map<String, dynamic> _getThemeForWeather() {
    if (weather == null) {
      return {
        "colors": [const Color(0xFF1A237E), const Color(0xFF64B5F6)],
      };
    }

    final code = (weather!["current"]["weather_code"] as num).toInt();

    if (code == 0 || code <= 2) {
      return {
        "colors": [const Color(0xFF4A90E2), const Color(0xFF81D4FA)],
      };
    } else if (code == 3 || code <= 48) {
      return {
        "colors": [const Color(0xFF546E7A), const Color(0xFF90A4AE)],
      };
    } else if (code <= 67) {
      return {
        "colors": [const Color(0xFF1565C0), const Color(0xFF4FC3F7)],
      };
    } else if (code <= 86) {
      return {
        "colors": [const Color(0xFF90CAF9), const Color(0xFFE3F2FD)],
      };
    } else {
      return {
        "colors": [const Color(0xFF37474F), const Color(0xFF607D8B)],
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
            child: Container(color: Colors.white.withValues(alpha: 0.05)),
          ),

          SafeArea(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : errorMsg != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off, color: Colors.white70, size: 54),
                        const SizedBox(height: 12),
                        Text(
                          errorMsg!,
                          style: const TextStyle(color: Colors.white70, fontSize: 15),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: fetchWeather,
                          icon: const Icon(Icons.refresh),
                          label: const Text("Tekrar Dene"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white24,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                : _buildWeatherCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherCard() {
    final current = weather!["current"];
    final code = (current["weather_code"] as num).toInt();
    final emoji = _getWeatherEmoji(code);
    final desc = _getWeatherDescription(code);
    final temp = current["temperature_2m"];
    final feelsLike = current["apparent_temperature"];
    final humidity = current["relative_humidity_2m"];
    final wind = current["wind_speed_10m"];

    return SingleChildScrollView(
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "📍 Erzurum, Türkiye",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              Text(emoji, style: const TextStyle(fontSize: 72)),
              const SizedBox(height: 12),
              Text(
                "$temp°C",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: const TextStyle(color: Colors.white70, fontSize: 18),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _infoRow("💧", "Nem", "$humidity%"),
                    const SizedBox(height: 8),
                    _infoRow("💨", "Rüzgar", "$wind km/s"),
                    const SizedBox(height: 8),
                    _infoRow("🌡️", "Hissedilen", "$feelsLike°C"),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: fetchWeather,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.refresh, color: Colors.white38, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      "Yenile",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
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

  Widget _infoRow(String emoji, String label, String value) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 14)),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
          Colors.cyanAccent.withValues(alpha: 0.15),
          Colors.blueAccent.withValues(alpha: 0.1),
          Colors.purpleAccent.withValues(alpha: 0.12),
        ],
        begin: Alignment(-1 + t * 2, -1),
        end: Alignment(1 - t * 2, 1),
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) => true;
}
