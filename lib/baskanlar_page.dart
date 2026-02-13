import 'dart:ui';
import 'package:flutter/material.dart';

class BaskanlarPage extends StatefulWidget {
  const BaskanlarPage({super.key});

  @override
  State<BaskanlarPage> createState() => _BaskanlarPageState();
}

class _BaskanlarPageState extends State<BaskanlarPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  final List<Map<String, String>> baskanlar = [
    {
      "ad": "Mehmet Sekmen",
      "yil": "2014 - Günümüz",
      "foto": "assets/icons/mehmetsekmen.jpg",
      "bio":
          "1958 Erzurum doğumlu. Kartal ve Samandıra belediye başkanlığı yaptı. 2014, 2019 ve 2024’te Erzurum Büyükşehir Belediye Başkanı seçildi. Türkiye’nin en başarılı büyükşehir başkanlarından biridir.",
    },
    {
      "ad": "Şerif Efendi",
      "yil": "1901 - 1906, 1908 (kısa dönem)",
      "foto": "assets/icons/serifefendi.jpg",
      "bio":
          "1840’larda Erzurum’da doğdu. Erzincankapı’daki konağı Rus işgalinde yandı. 1901-1906 ve 1908’de belediye başkanlığı yaptı. Şehir hapishanesini inşa ettirdi. Şerif Efendi Caddesi onun adını taşır.",
    },
    {
      "ad": "Nazif Bey",
      "yil": "1910’lar",
      "foto": "assets/icons/nazifbey.jpg",
      "bio":
          "Mehmet Nafiz Dumlu (1880-1961). Askerlik ve ziraatla uğraştı. Erzurum Belediye Reisliği, ardından uzun yıllar milletvekilliği yaptı.",
    },
    {
      "ad": "Zakir Bey",
      "yil": "1918 - 1921, 1927 - 1928",
      "foto": "assets/icons/zakirbey.jpg",
      "bio":
          "1887 doğumlu. Milli Mücadele döneminde Erzurum halkını örgütledi. İki kez belediye başkanlığı yaptı, hayırseverliğiyle tanındı.",
    },
    {
      "ad": "Seyfullah Bey",
      "yil": "1930 - 1932",
      "foto": "assets/icons/seyfullahbey.jpg",
      "bio":
          "1859 doğumlu. Şerif Efendi’nin oğludur. I. Dünya Savaşı’nda milis birliğiyle savaştı. Belediye Başkanlığı döneminde adaletli tutumuyla bilindi.",
    },
    {
      "ad": "Mustafa Durak Sakarya",
      "yil": "1933 - 1935",
      "foto": "assets/icons/duraksakarya.jpg",
      "bio":
          "1876 doğumlu. Türkiye’nin ilk polis okulu mezunlarındandır. Emniyet müdürlüğü ve milletvekilliği yaptı, 1933-35 arasında Erzurum Belediye Başkanıydı.",
    },
    {
      "ad": "Salim Altuğ",
      "yil": "1939’lar",
      "foto": "assets/icons/salimaltug.jpg",
      "bio":
          "1895 doğumlu. Harp Okulu mezunu, Romen Esirleri Heyeti Başkanlığı yaptı. Erzurum Belediye Başkanlığı ve milletvekilliği görevlerinde bulundu.",
    },
    {
      "ad": "Şevket Arı",
      "yil": "1940’lar",
      "foto": "assets/icons/sevketari.jpg",
      "bio": "",
    },
    {
      "ad": "Mehmet Mesut Çankaya",
      "yil": "1940’lar",
      "foto": "assets/icons/mesutcankaya.jpg",
      "bio":
          "1887 doğumlu. Erzurum Kongresi üyesi, avukat ve siyasetçidir. Belediye Reisliği ve milletvekilliği yaptı.",
    },
    {
      "ad": "Kazım Yurdalan",
      "yil": "1945 - 1950",
      "foto": "assets/icons/kazimyurdalan.jpg",
      "bio":
          "Belediyenin mali yapısını düzeltti, şehir imar planını başlattı. Elektrik, kanalizasyon ve yeşil alan düzenlemeleriyle Erzurum’a çağ atlattı.",
    },
    {
      "ad": "Lütfi Yalım",
      "yil": "1950’ler",
      "foto": "assets/icons/lutfuyalim.jpg",
      "bio": "",
    },
    {
      "ad": "Semih Korukcu",
      "yil": "1950’ler",
      "foto": "assets/icons/semihkorukcu.jpg",
      "bio": "",
    },
    {
      "ad": "Edip Somunoğlu",
      "yil": "1950’ler",
      "foto": "assets/icons/edipsomunoglu.jpg",
      "bio":
          "1904 doğumlu. Doktordur. Erzurum Belediye Başkanlığı, Cumhuriyet Senatosu üyeliği ve Sağlık Bakanlığı görevlerinde bulundu.",
    },
    {
      "ad": "Hilmi Nalbantoğlu",
      "yil": "1964 - 1968",
      "foto": "assets/icons/hilminalbantoglu.jpg",
      "bio":
          "1921 Oltu doğumlu, mühendis. 1964-68 arasında başkanlık yaptı. Erzurumspor’un kurucularındandır.",
    },
    {
      "ad": "Selahattin Ozan",
      "yil": "1970’ler",
      "foto": "assets/icons/selahattinozan.jpg",
      "bio": "",
    },
    {
      "ad": "Orhan Şerifsoy",
      "yil": "1973 - 1977",
      "foto": "assets/icons/orhanserifsoy.jpg",
      "bio":
          "1928 doğumlu, CHP’den seçilen Erzurum’un ilk sol partili belediye başkanıdır. Dönem sonunda İstanbul’a yerleşip avukatlığa devam etmiştir.",
    },
    {
      "ad": "Nihat Kitapçı",
      "yil": "1977 - 1980",
      "foto": "assets/icons/nihatkitapci.jpg",
      "bio":
          "1928 Erzurum doğumlu. Ziraat mühendisi. Belediye Başkanlığı ve Devlet Bakanlığı yaptı. 2014’te vefat etti.",
    },
    {
      "ad": "Necati Güllülü",
      "yil": "1984 - 1989",
      "foto": "assets/icons/necatigullulu.jpg",
      "bio":
          "1942 Pasinler doğumlu. 1984-1989 arasında belediye başkanlığı yaptı. MHP ve Anavatan Partilerinde görev aldı.",
    },
    {
      "ad": "Mehmet Ali Ünal",
      "yil": "1990’lar",
      "foto": "assets/icons/mehmetaliunal.jpg",
      "bio": "",
    },
    {
      "ad": "Ersan Gemalmaz",
      "yil": "1990’lar",
      "foto": "assets/icons/ersangemalmaz.jpg",
      "bio": "",
    },
    {
      "ad": "Mahmut Uykusuz",
      "yil": "1999 - 2004",
      "foto": "assets/icons/mahmutuykusuz.jpg",
      "bio": "",
    },
    {
      "ad": "Ahmet Küçükler",
      "yil": "2004 - 2014",
      "foto": "assets/icons/ahmetkucukler.jpg",
      "bio":
          "1970 Erzurum doğumlu. Hukuk ve ilahiyat mezunu. 2004 ve 2009 seçimlerinde %56.8 oyla iki dönem başkan seçildi. Şu anda Çevre ve Şehircilik Bakanlığı’nda görev yapmaktadır.",
    },
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
          "Erzurum Belediye Başkanları",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
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
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: baskanlar.length,
              itemBuilder: (context, i) => _buildBaskanCard(baskanlar[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBaskanCard(Map<String, String> b) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.35)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showBaskanDetay(b), 
              splashColor: Colors.white24,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                child: Row(
                  children: [
                    Hero(
                      tag: b["ad"]!,
                      child: CircleAvatar(
                        radius: 30,
                        backgroundImage: AssetImage(b["foto"]!),
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b["ad"]!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              b["yil"]!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.info_outline, color: Colors.white70),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showBaskanDetay(Map<String, String> b) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, 
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6, 
          minChildSize: 0.4,
          maxChildSize: 0.85,
          builder: (_, scrollController) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 25,
                  sigmaY: 25,
                ), 
                child: Container(
                  decoration: BoxDecoration(

                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(
                          0xFF1A237E,
                        ).withOpacity(0.5), 
                        const Color(
                          0xFF283593,
                        ).withOpacity(0.4),
                      ],
                    ),
 
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: ListView(
                    controller: scrollController,
                    children: [
                   
                      Center(
                        child: Container(
                          width: 50,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                
                      Center(
                        child: Hero(
                          tag: b["ad"]!,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 70,
                              backgroundImage: AssetImage(b["foto"]!),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                  
                      Text(
                        b["ad"]!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 2),
                              blurRadius: 4,
                              color: Colors.black45,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                   
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(
                            "Görev Yılı: ${b["yil"]}",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(
                            0.2,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          b["bio"]!.isNotEmpty
                              ? b["bio"]!
                              : "Bu başkan hakkında detaylı biyografi bulunmamaktadır.",
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors
                                .white, 
                            height: 1.6,
                          ),
                          textAlign: TextAlign.justify,
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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
