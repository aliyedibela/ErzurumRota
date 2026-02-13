import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Sayfa importları
import 'route_page.dart';
import 'eczane_page.dart';
import 'onemliyerler_page.dart';
import 'erzurumtarihi_page.dart';
import 'baskanlar_page.dart';
import 'yaklasanetkinlikler_page.dart';
import 'havadurumu_page.dart';
import 'sondepremler_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Erzurum Şehir Rehberi',
      theme: ThemeData(fontFamily: 'Roboto', useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late TabController _tabController;

  // Rota sayfasında mıyız kontrolü (Sadece yazı rengi için)
  bool isRouteTab = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 9, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          // Rota sekmesi (Index 4) ise true
          isRouteTab = _tabController.index == 4;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // 🔥 Yazı Renkleri (Rota sayfasında koyu, diğerlerinde beyaz)
    final Color mainTextColor = isRouteTab
        ? const Color(0xFF1A237E)
        : Colors.white;
    final Color unselectedColor = isRouteTab ? Colors.black45 : Colors.white60;
    final SystemUiOverlayStyle overlayStyle = isRouteTab
        ? SystemUiOverlayStyle.dark
        : SystemUiOverlayStyle.light;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: overlayStyle,
        title: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: mainTextColor, // Yazı rengi dinamik
            shadows: [
              Shadow(
                offset: const Offset(0, 1),
                blurRadius: isRouteTab ? 0 : 4,
                color: isRouteTab ? Colors.transparent : Colors.black45,
              ),
            ],
          ),
          child: const Text("Erzurum Şehir Rehberi"),
        ),

        // 🔹 TabBar Alanı (Orjinal Cam Efekti - Koyulaştırma Yok)
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            height: 50,
            decoration: BoxDecoration(
              // Rengi sabit tutuyoruz (Hafif beyaz cam), koyulaştırmıyoruz
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,

                  // Yazı renkleri dinamik (Rota'da lacivert, diğerlerinde beyaz)
                  labelColor: mainTextColor,
                  unselectedLabelColor: unselectedColor,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),

                  // İşaretçi (Indicator)
                  indicatorSize: TabBarIndicatorSize.label,
                  indicator: UnderlineTabIndicator(
                    borderSide: BorderSide(
                      color: isRouteTab
                          ? const Color(0xFF1A237E)
                          : Colors.white,
                      width: 3,
                    ),
                    insets: const EdgeInsets.only(bottom: 8),
                  ),

                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: "Ana Sayfa"),
                    Tab(text: "Nöbetçi Eczaneler"),
                    Tab(text: "Yaklaşan Etkinlikler"),
                    Tab(text: "Erzurum Tarihçesi"),
                    Tab(text: "Rota Öneri Sistemi"),
                    Tab(text: "Gezilecek Yerler"),
                    Tab(text: "Son Depremler"),
                    Tab(text: "Hava Durumu"),
                    Tab(text: "Eski Başkanlar"),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // 1. Katman: Gradient Arka Plan
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isRouteTab ? 0.0 : 1.0, // Rota'da arka planı gizle
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF1A237E), // Koyu Lacivert
                    Color(0xFF3949AB),
                    Color(0xFF64B5F6), // Açık Mavi
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),

          // 2. Katman: Hafif Desen
          Container(color: Colors.white.withOpacity(0.02)),

          // 3. Katman: Sayfa İçerikleri
          TabBarView(
            controller: _tabController,
            // Kaydırma özelliği açık (physics satırı yok)
            children: [
              _buildMainTab(size),
              const EczanePage(),
              const YaklasanEtkinliklerPage(),
              const ErzurumTarihiPage(),
              const RoutePage(),
              const OnemliYerlerPage(),
              const SonDepremlerPage(),
              const HavaDurumuPage(),
              const BaskanlarPage(),
            ],
          ),
        ],
      ),
    );
  }

  // 🏠 ANA SAYFA TASARIMI (1x4 LİSTE DÜZENİNE GERİ DÖNDÜK)
  Widget _buildMainTab(Size size) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 155, left: 25, right: 25, bottom: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo
          GlassCard(
            height: size.width * 0.42,
            width: size.width * 0.42,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Image.asset(
                "assets/icons/erzbblogoformain.png",
                fit: BoxFit.contain,
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Başlık
          Text(
            "Şehrini Keşfet",
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.95),
              shadows: const [
                Shadow(
                  offset: Offset(0, 1),
                  blurRadius: 4,
                  color: Colors.black26,
                ),
              ],
            ),
          ),

          const SizedBox(height: 4), // Başlık ile alt yazı arasına hafif boşluk
          Text(
            '"Senin Şehrin, Senin Rehberin."', // 👈 DIŞARISI TEK TIRNAK, İÇERİSİ ÇİFT TIRNAK
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 35),

          // 📋 DİKEY MENÜ LİSTESİ (1x4)
          GlassMenuCard(
            icon: Icons.local_hospital_rounded,
            title: "Nöbetçi Eczaneler",
            subtitle: "Yakındaki açık eczaneleri gör",
            color: Colors.tealAccent,
            onTap: () => _tabController.animateTo(1),
          ),
          const SizedBox(height: 15),

          GlassMenuCard(
            icon: Icons.event_rounded,
            title: "Yaklaşan Etkinlikler",
            subtitle: "Kültür & sanat takvimi",
            color: Colors.deepPurpleAccent,
            onTap: () => _tabController.animateTo(2),
          ),
          const SizedBox(height: 15),

          GlassMenuCard(
            icon: Icons.history_edu_rounded,
            title: "Erzurum Şehir Tarihi",
            subtitle: "Erzurum tarihinin aşamaları",
            color: Colors.blueAccent,
            onTap: () => _tabController.animateTo(3),
          ),
          const SizedBox(height: 15),

          GlassMenuCard(
            icon: Icons.directions_bus_rounded,
            title: "Rota Öneri Sistemi",
            subtitle: "Otobüs hatlarını keşfet",
            color: Colors.lightBlueAccent,
            onTap: () => _tabController.animateTo(4),
          ),
        ],
      ),
    );
  }
}

// 🌫️ CAM KART
class GlassCard extends StatelessWidget {
  final double? width;
  final double? height;
  final Widget child;

  const GlassCard({super.key, this.width, this.height, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        color: Colors.white.withOpacity(0.2),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: child,
        ),
      ),
    );
  }
}

// 💡 MENÜ KARTI
class GlassMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const GlassMenuCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.2),
                border: Border.all(color: color.withOpacity(0.5), width: 1.5),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white70,
              size: 26,
            ),
          ],
        ),
      ),
    );
  }
}
