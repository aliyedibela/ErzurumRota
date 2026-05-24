import 'dart:ui';
import 'package:erzurum_rota/views/baskanlar/baskanlar_page.dart';
import 'package:erzurum_rota/views/deprem/sondepremler_page.dart';
import 'package:erzurum_rota/views/eczane/eczane_page.dart';
import 'package:erzurum_rota/views/etkinlikler/yaklasanetkinlikler_page.dart';
import 'package:erzurum_rota/views/hava/havadurumu_page.dart';
import 'package:erzurum_rota/views/profile/profile_screen.dart';
import 'package:erzurum_rota/views/rota/route_page.dart';
import 'package:erzurum_rota/views/tarih/erzurumtarihi_page.dart';
import 'package:erzurum_rota/views/yerler/onemliyerler_page.dart';
import 'package:erzurum_rota/views/favorites/favorites_page.dart';
import 'package:erzurum_rota/views/notifications/notifications_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'services/fcm_service.dart';
import 'services/user_auth_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Uygulamayı hemen başlat, Firebase arka planda yüklensin
  runApp(const MyApp());

  // Firebase arka planda başlat — UI'yi bloklamaz
  _initFirebaseInBackground();
}

void _initFirebaseInBackground() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FcmService().initialize();
    debugPrint('✅ Firebase başlatıldı');
  } catch (e) {
    debugPrint('⚠️ Firebase başlatılamadı: $e');
  }
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
  bool isRouteTab = false;
  int _currentTabIndex = 0;
  AppUser? _currentUser;
  final _userSvc = UserAuthService();
  final _routeLineNotifier = ValueNotifier<String?>(null);
  

 @override
void initState() {
  super.initState();
  _tabController = TabController(length: 9, vsync: this);

  _tabController.addListener(() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _currentTabIndex = _tabController.index;
        isRouteTab = _tabController.index == 4;
      });
    }
  });

  _loadSavedUser();
  
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _showAccessibilityOnboarding();
  });
}

Future<void> _showAccessibilityOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  final shown = prefs.getBool('accessibility_onboarding_shown') ?? false;
  if (shown) return;
  await prefs.setBool('accessibility_onboarding_shown', true);

  if (!mounted) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.lightBlueAccent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.accessibility_new_rounded,
                    color: Colors.lightBlueAccent,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Erişilebilirlik Modu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Bu uygulama görme engelli kullanıcılar için sesli yönlendirme özelliğine sahiptir.\n\n'
                    'Durağa yaklaştığınızda otobüs bilgisi sesli olarak iletilir.\n\n'
                    '♿ Sağ üstteki profil ikonuna girerek bu özelliği açıp kapatabilirsiniz.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Anladım',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
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


  Future<void> _loadSavedUser() async {
    final u = await _userSvc.getSavedUser();
    if (mounted) setState(() => _currentUser = u);
  }

  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          initialUser: _currentUser,
          onUserChanged: (user) => setState(() => _currentUser = user),
        ),
      ),
    );
    final saved = await _userSvc.getSavedUser();
    if (mounted) setState(() => _currentUser = saved);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

@override
Widget build(BuildContext context) {
  final size = MediaQuery.of(context).size;
  final Color mainTextColor = isRouteTab ? const Color(0xFF1A237E) : Colors.white;
  final Color unselectedColor = isRouteTab ? Colors.black45 : Colors.white60;
  final SystemUiOverlayStyle overlayStyle = isRouteTab ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light;

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
          color: mainTextColor,
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
      actions: [
        FutureBuilder<int>(
          future: NotificationService().getUnreadCount(),
          builder: (context, snapshot) {
            final count = snapshot.data ?? 0;
            return Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.notifications_none_rounded,
                    color: isRouteTab ? const Color(0xFF1A237E) : Colors.white70,
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationsPage()),
                    );
                    setState(() {});
                  },
                ),
                if (count > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: _openProfile,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _currentUser != null
                    ? const LinearGradient(
                        colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: _currentUser == null ? Colors.white.withValues(alpha: 0.15) : null,
                border: Border.all(
                  color: Colors.white.withValues(alpha: _currentUser != null ? 0.8 : 0.3),
                  width: 2,
                ),
                boxShadow: _currentUser != null
                    ? [
                        BoxShadow(
                          color: const Color(0xFF42A5F5).withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              child: _currentUser != null
                  ? Center(
                      child: Text(
                        _currentUser!.fullName.isNotEmpty
                            ? _currentUser!.fullName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.person_outline_rounded,
                      color: isRouteTab ? const Color(0xFF1A237E) : Colors.white70,
                      size: 20,
                    ),
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16), 
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16), 
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: mainTextColor,
                unselectedLabelColor: unselectedColor,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                indicatorSize: TabBarIndicatorSize.label,
                indicator: UnderlineTabIndicator(
                  borderSide: BorderSide(
                    color: isRouteTab ? const Color(0xFF1A237E) : Colors.white,
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
        AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: isRouteTab ? 0.0 : 1.0,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1A237E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        TabBarView(
          controller: _tabController,
          children: [
            _buildMainTab(size),
            _LazyTab(index: 1, currentIndex: _currentTabIndex, child: const EczanePage()),
            _LazyTab(index: 2, currentIndex: _currentTabIndex, child: const YaklasanEtkinliklerPage()),
            _LazyTab(index: 3, currentIndex: _currentTabIndex, child: const ErzurumTarihiPage()),
            _LazyTab(index: 4, currentIndex: _currentTabIndex, child: RoutePage(lineNotifier: _routeLineNotifier)),
            _LazyTab(index: 5, currentIndex: _currentTabIndex, child: const OnemliYerlerPage()),
            _LazyTab(index: 6, currentIndex: _currentTabIndex, child: const SonDepremlerPage()),
            _LazyTab(index: 7, currentIndex: _currentTabIndex, child: const HavaDurumuPage()),
            _LazyTab(index: 8, currentIndex: _currentTabIndex, child: const BaskanlarPage()),
          ],
        ),
      ],
    ),
  );
}

Widget _buildMainTab(Size size) {
  return SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 150, 24, 40), 
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: size.width * 0.42,
              height: size.width * 0.42,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Image.asset("assets/icons/erzbblogoformain.png", fit: BoxFit.contain),
            ),
          ),
        ),
        const SizedBox(height: 30),
        Text(
          "Şehrini Keşfet",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white.withValues(alpha: 0.95),
            letterSpacing: 0.5,
            shadows: const [
              Shadow(offset: Offset(0, 2), blurRadius: 8, color: Colors.black26)
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '"Senin Şehrin, Senin Rehberin."',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withValues(alpha: 0.85),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 35),
        _buildGlassMenuCard(
          icon: Icons.star_rounded,
          title: "Favori Duraklarım",
          subtitle: "Sık kullandığın duraklara hızlıca ulaş",
          gradient: const LinearGradient(
            colors: [Color(0xFFFF9800), Color(0xFFF57C00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => FavoritesPage(
                onLineSelected: (line) {
                  _routeLineNotifier.value = line;
                  _tabController.animateTo(4);
                },
              ))),
        ),
        const SizedBox(height: 14),
        _buildGlassMenuCard(
          icon: Icons.local_hospital_rounded,
          title: "Nöbetçi Eczaneler",
          subtitle: "Yakındaki açık eczaneleri gör",
          gradient: const LinearGradient(
            colors: [Color(0xFF00BCD4), Color(0xFF0097A7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          onTap: () => _tabController.animateTo(1),
        ),
        const SizedBox(height: 14),
        _buildGlassMenuCard(
          icon: Icons.event_rounded,
          title: "Yaklaşan Etkinlikler",
          subtitle: "Kültür & sanat takvimi",
          gradient: const LinearGradient(
            colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          onTap: () => _tabController.animateTo(2),
        ),
        const SizedBox(height: 14),
        _buildGlassMenuCard(
          icon: Icons.history_edu_rounded,
          title: "Erzurum Şehir Tarihi",
          subtitle: "Erzurum tarihinin aşamaları",
          gradient: const LinearGradient(
            colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          onTap: () => _tabController.animateTo(3),
        ),
        const SizedBox(height: 14),
        _buildGlassMenuCard(
          icon: Icons.directions_bus_rounded,
          title: "Rota Öneri Sistemi",
          subtitle: "Otobüs hatlarını keşfet",
          gradient: const LinearGradient(
            colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          onTap: () => _tabController.animateTo(4),
        ),
      ],
    ),
  );
}
  Widget _buildGlassMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: gradient.colors.first.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
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
                          fontSize: 16,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white70,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LazyTab extends StatefulWidget {
  final int index;
  final int currentIndex;
  final Widget child;

  const _LazyTab({
    required this.index,
    required this.currentIndex,
    required this.child,
  });

  @override
  State<_LazyTab> createState() => _LazyTabState();
}

class _LazyTabState extends State<_LazyTab> with AutomaticKeepAliveClientMixin {
  bool _hasBeenBuilt = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.currentIndex == widget.index || _hasBeenBuilt) {
      if (!_hasBeenBuilt) {
        _hasBeenBuilt = true;
      }
      return widget.child;
    }

    return const SizedBox.shrink();
  }
}