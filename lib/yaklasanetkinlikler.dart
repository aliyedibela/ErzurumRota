import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

class Etkinlik {
  final String ad;
  final String mekan;
  final String tarih;
  final String fiyat;
  final String link;
  final String? afisUrl;
  final String kaynak; 

  Etkinlik({
    required this.ad,
    required this.mekan,
    required this.tarih,
    required this.fiyat,
    required this.link,
    this.afisUrl,
    required this.kaynak,
  });
}

Future<List<Etkinlik>> _fetchBubilet() async {
  try {
    final url = Uri.parse("https://www.bubilet.com.tr/erzurum");
    final response = await http.get(
      url,
      headers: {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"},
    );

    if (response.statusCode != 200) return [];

    final document = parser.parse(response.body);
    final kartlar = document.querySelectorAll("a.group.block");

    List<Etkinlik> list = [];

    for (var k in kartlar) {
      final ad = k.attributes["title"]?.trim() ?? "İsimsiz Etkinlik";
      final href = k.attributes["href"] ?? "";
      final link = "https://www.bubilet.com.tr$href";
      final img = k.querySelector("img")?.attributes["src"];

      final pTags = k.querySelectorAll("div.px-1.pt-2 p");
      String mekan = pTags.isNotEmpty ? pTags[0].text.trim() : "Erzurum";
      String tarih = pTags.length > 1 ? pTags[1].text.trim() : "Tarih Yok";
      final fiyatSpan = k.querySelector("div.mt-1 span.text-left");
      final tlSpan = k.querySelector("div.mt-1 span.ml-0\\.5");
      String fiyat = "Bilinmiyor";

      if (fiyatSpan != null) {
        fiyat = fiyatSpan.text.trim();
        if (tlSpan != null && !fiyat.contains("₺")) {
          fiyat += " " + tlSpan.text.trim();
        }
      }

      list.add(
        Etkinlik(
          ad: ad,
          mekan: mekan,
          tarih: tarih,
          fiyat: fiyat,
          link: link,
          afisUrl: img,
          kaynak: "Bubilet",
        ),
      );
    }
    return list;
  } catch (e) {
    print("Bubilet Hatası: $e");
    return [];
  }
}

Future<List<Etkinlik>> _fetchPasso() async {
  try {
    final url = Uri.parse("https://www.passo.com.tr/api/utils/search-v2");
    final body = jsonEncode({
      "query": "erzurum", 
      "size": 20, 
      "from": 0,
      "sort": "date", 
    });

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "User-Agent": "Mozilla/5.0",
      },
      body: body,
    );

    if (response.statusCode != 200) return [];

    final jsonResponse = jsonDecode(response.body);
    final data = jsonResponse['data'] as List?;

    if (data == null) return [];

    List<Etkinlik> list = [];

    for (var item in data) {
      String title = item['title'] ?? "Passo Etkinliği";
      String venue = item['venueName'] ?? "Erzurum";
      String rawDate = item['date'] ?? "";
      String tarih = rawDate.length > 10
          ? "${rawDate.substring(0, 10)} / Saat: ${rawDate.substring(11, 16)}"
          : rawDate;

      String seoUrl = item['seoUrl'] ?? "";
      String id = item['id'] ?? "";
      String link = "https://www.passo.com.tr/tr/etkinlik/$seoUrl/$id";
      String? image = item['imageUrl'];

      list.add(
        Etkinlik(
          ad: title,
          mekan: venue,
          tarih: tarih,
          fiyat: "Detayda", 
          link: link,
          afisUrl: image,
          kaynak: "Passo",
        ),
      );
    }
    return list;
  } catch (e) {
    print("Passo Hatası: $e");
    return [];
  }
}

Future<List<Etkinlik>> tumEtkinlikleriGetir() async {

  final results = await Future.wait([_fetchBubilet(), _fetchPasso()]);

  List<Etkinlik> tumListe = [];
  tumListe.addAll(results[0]); 
  tumListe.addAll(results[1]); 


  return tumListe;
}
