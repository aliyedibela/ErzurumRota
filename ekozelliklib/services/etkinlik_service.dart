import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:erzurum_rota/models/etkinlik.dart';

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
    final List<Etkinlik> list = [];

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
          fiyat += " ${tlSpan.text.trim()}";
        }
      }

      list.add(Etkinlik(
        ad: ad,
        mekan: mekan,
        tarih: tarih,
        fiyat: fiyat,
        link: link,
        afisUrl: img,
        kaynak: "Bubilet",
      ));
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

    final data = jsonDecode(response.body)['data'] as List?;
    if (data == null) return [];

    return data.map((item) {
      String rawDate = item['date'] ?? "";
      String tarih = rawDate.length > 10
          ? "${rawDate.substring(0, 10)} / Saat: ${rawDate.substring(11, 16)}"
          : rawDate;
      String seoUrl = item['seoUrl'] ?? "";
      String id = item['id'] ?? "";

      return Etkinlik(
        ad: item['title'] ?? "Passo Etkinliği",
        mekan: item['venueName'] ?? "Erzurum",
        tarih: tarih,
        fiyat: "Detayda",
        link: "https://www.passo.com.tr/tr/etkinlik/$seoUrl/$id",
        afisUrl: item['imageUrl'],
        kaynak: "Passo",
      );
    }).toList();
  } catch (e) {
    print("Passo Hatası: $e");
    return [];
  }
}

Future<List<Etkinlik>> tumEtkinlikleriGetir() async {
  final results = await Future.wait([_fetchBubilet(), _fetchPasso()]);
  return [...results[0], ...results[1]];
}