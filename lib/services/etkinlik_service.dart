import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:erzurum_rota/models/etkinlik.dart';

const _browserHeaders = {
  "User-Agent":
      "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36",
  "Accept":
      "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
  "Accept-Language": "tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7",
};

Future<List<Etkinlik>> _fetchBubilet() async {
  try {
    final url = Uri.parse("https://www.bubilet.com.tr/erzurum");
    final response = await http
        .get(url, headers: _browserHeaders)
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      debugPrint("Bubilet HTTP ${response.statusCode}");
      return [];
    }

    final document = parser.parse(response.body);

    // Birden fazla olası selector'ı dene
    var kartlar = document.querySelectorAll("a.group.block");
    if (kartlar.isEmpty) kartlar = document.querySelectorAll("a[href*='/etkinlik/']");
    if (kartlar.isEmpty) kartlar = document.querySelectorAll("article a");

    final List<Etkinlik> list = [];

    for (var k in kartlar) {
      final ad = (k.attributes["title"] ??
              k.querySelector("h2,h3,h4,.title,.name")?.text ??
              "İsimsiz Etkinlik")
          .trim();
      if (ad == "İsimsiz Etkinlik" || ad.isEmpty) continue;

      final href = k.attributes["href"] ?? "";
      final link = href.startsWith("http")
          ? href
          : "https://www.bubilet.com.tr$href";

      // Görsel: src veya data-src
      final imgEl = k.querySelector("img");
      final img = imgEl?.attributes["src"] ??
          imgEl?.attributes["data-src"] ??
          imgEl?.attributes["data-lazy-src"];

      // Mekan & Tarih
      final pTags = k.querySelectorAll("p");
      String mekan = pTags.isNotEmpty ? pTags[0].text.trim() : "Erzurum";
      String tarih = pTags.length > 1 ? pTags[1].text.trim() : "Tarih Yok";

      // Fiyat
      final fiyatEl = k.querySelector("span");
      String fiyat = fiyatEl?.text.trim() ?? "Bilinmiyor";

      list.add(Etkinlik(
        ad: ad,
        mekan: mekan.isEmpty ? "Erzurum" : mekan,
        tarih: tarih.isEmpty ? "Tarih Yok" : tarih,
        fiyat: fiyat,
        link: link,
        afisUrl: img,
        kaynak: "Bubilet",
      ));
    }
    debugPrint("Bubilet: ${list.length} etkinlik bulundu");
    return list;
  } catch (e) {
    debugPrint("Bubilet Hatası: $e");
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

    final response = await http
        .post(
          url,
          headers: {
            "Content-Type": "application/json",
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
            "Accept": "application/json",
            "Referer": "https://www.passo.com.tr/",
            "Origin": "https://www.passo.com.tr",
          },
          body: body,
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      debugPrint("Passo HTTP ${response.statusCode}");
      return [];
    }

    final decoded = jsonDecode(response.body);

    // Farklı response yapılarını destekle
    List? data;
    if (decoded is Map) {
      data = decoded['data'] as List? ??
          decoded['hits'] as List? ??
          decoded['results'] as List? ??
          decoded['items'] as List?;

      // Elasticsearch tarzı nested yapı: { hits: { hits: [...] } }
      if (data == null && decoded['hits'] is Map) {
        data = decoded['hits']['hits'] as List?;
      }
    }

    if (data == null || data.isEmpty) {
      debugPrint("Passo: data boş veya null");
      return [];
    }

    final List<Etkinlik> list = [];
    for (final item in data) {
      if (item is! Map) continue;
      // Elasticsearch _source wrapper
      final src = (item['_source'] as Map?) ?? item;
      String rawDate = src['date']?.toString() ?? src['startDate']?.toString() ?? "";
      String tarih = rawDate.length > 10
          ? "${rawDate.substring(0, 10)} / Saat: ${rawDate.substring(11, 16)}"
          : (rawDate.isEmpty ? "Tarih Yok" : rawDate);

      String seoUrl = src['seoUrl']?.toString() ?? src['slug']?.toString() ?? "";
      String id = src['id']?.toString() ?? src['_id']?.toString() ?? "";

      list.add(Etkinlik(
        ad: src['title']?.toString() ?? src['name']?.toString() ?? "Passo Etkinliği",
        mekan: src['venueName']?.toString() ?? src['venue']?.toString() ?? "Erzurum",
        tarih: tarih,
        fiyat: "Detayda",
        link: "https://www.passo.com.tr/tr/etkinlik/$seoUrl/$id",
        afisUrl: src['imageUrl']?.toString() ?? src['image']?.toString(),
        kaynak: "Passo",
      ));
    }
    debugPrint("Passo: ${list.length} etkinlik bulundu");
    return list;
  } catch (e) {
    debugPrint("Passo Hatası: $e");
    return [];
  }
}

Future<List<Etkinlik>> tumEtkinlikleriGetir() async {
  final results = await Future.wait([_fetchBubilet(), _fetchPasso()]);
  final all = [...results[0], ...results[1]];
  debugPrint("Toplam etkinlik: ${all.length}");
  return all;
}
