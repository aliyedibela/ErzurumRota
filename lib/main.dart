import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'route_page.dart';
import 'eczane_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; 
import 'onemliyerler_page.dart';
import 'erzurumtarihi_page.dart';
import 'baskanlar_page.dart';
import 'yaklasanetkinlikler_page.dart';
import 'havadurumu_page.dart';
import 'sondepremler_page.dart';
import 'profile_screen.dart';
import 'user_auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
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
  bool isRouteTab = false;
  int _currentTabIndex = 0;
  AppUser? _currentUser;
  final _userSvc = UserAuthService();

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
                color: _currentUser == null ? Colors.white.withOpacity(0.15) : null,
                border: Border.all(
                  color: Colors.white.withOpacity(_currentUser != null ? 0.8 : 0.3),
                  width: 2,
                ),
                boxShadow: _currentUser != null
                    ? [
                        BoxShadow(
                          color: const Color(0xFF42A5F5).withOpacity(0.4),
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
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16), 
            border: Border.all(color: Colors.white.withOpacity(0.25)),
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
            _LazyTab(index: 4, currentIndex: _currentTabIndex, child: const RoutePage()),
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
    padding: const EdgeInsets.fromLTRB(24, 185, 24, 40), 
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
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
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
            color: Colors.white.withOpacity(0.95),
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
            color: Colors.white.withOpacity(0.85),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 35),
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
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
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
                        color: gradient.colors.first.withOpacity(0.4),
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
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
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