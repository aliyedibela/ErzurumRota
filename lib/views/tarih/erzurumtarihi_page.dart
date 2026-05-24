import 'dart:ui';
import 'package:flutter/material.dart';

class ErzurumTarihiPage extends StatelessWidget {
  const ErzurumTarihiPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> tarihBolumleri = [
      {
        "baslik": "Antik Dönem: Karaz Kültürü",
        "metin":
            "Erzurum Ovası’nda yapılan kazılar, MÖ 4000’lere kadar uzanan yerleşim izlerini ortaya koymuştur. Karaz Kültürü olarak bilinen bu dönem, bölgenin ilk tarım ve ticaret topluluklarını oluşturmuştur.",
        "tarih": "~ M.Ö. 4000-1000",
        "gorsel": "assets/yerler/kale.jpg",
      },
      {
        "baslik": "Bizans Dönemi: Theodosiopolis",
        "metin":
            "Roma İmparatoru Theodosius döneminde şehrin temelleri atılmış ve Theodosiopolis adını almıştır. Kale inşa edilerek bölge önemli bir askeri ve ticaret merkezi haline gelmiştir.",
        "tarih": "~ M.S. 400-1071",
        "gorsel": "assets/yerler/bizans.jpg",
      },
      {
        "baslik": "Selçuklu Dönemi: Türklerin Gelişi",
        "metin":
            "Malazgirt Zaferi sonrasında Saltuk Bey tarafından fethedilen Erzurum, Anadolu’daki ilk Türk beyliği Saltukluların başkenti oldu. Yakutiye ve Çifte Minareli Medrese bu dönemde yapıldı.",
        "tarih": "~ 1071-1202",
        "gorsel": "assets/yerler/yakutiye.jpg",
      },
      {
        "baslik": "Osmanlı Dönemi: Stratejik Kale Şehri",
        "metin":
            "Erzurum, Osmanlı döneminde İran ve Rusya sınırındaki en önemli askeri merkezlerden biri haline geldi. Tabyalar inşa edilerek şehir tahkim edildi ve Tanzimat döneminde vilayet merkezi oldu.",
        "tarih": "~ 1518-1918",
        "gorsel": "assets/yerler/ulu_cami.jpg",
      },
      {
        "baslik": "Milli Mücadele: Cumhuriyet'in Temeli",
        "metin":
            "12 Mart 1918’de kurtarılan Erzurum, 23 Temmuz 1919’da toplanan Erzurum Kongresi ile Milli Mücadele’nin simgesi haline geldi. Burada alınan kararlar Cumhuriyet’in temelini oluşturdu.",
        "tarih": "~ 1918-1923",
        "gorsel": "assets/icons/erzbblogo.jpg",
      },
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "Tarihi Yolculuk",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
            shadows: [
              Shadow(
                offset: Offset(0, 1),
                blurRadius: 4,
                color: Colors.black45,
              ),
            ],
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: tarihBolumleri.length,
        itemBuilder: (context, index) {
          final item = tarihBolumleri[index];
          return Stack(
            fit: StackFit.expand,
            children: [
  
              Image.asset(
                item["gorsel"]!,
                fit: BoxFit.cover,
                errorBuilder: (c, o, s) =>
                    Container(color: Colors.grey.shade900), 
              ),
              BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 6,
                  sigmaY: 6,
                ), 
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 
                          0.3,
                        ), 
                        Colors.black.withValues(alpha: 
                          0.7,
                        ), 
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(), 
                      Text(
                        item["baslik"]!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 2),
                              blurRadius: 6,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: Text(
                          "📅 ${item["tarih"]}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
          const SizedBox(height: 16),

                      Flexible(
                        child: SingleChildScrollView(
                          child: Text(
                            item["metin"]!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              height: 1.5,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40), 
                    ],
                  ),
                ),
              ),
              if (index < tarihBolumleri.length - 1)
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      const Text(
                        "Kaydır",
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 32,
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
