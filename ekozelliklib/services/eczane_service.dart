import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:erzurum_rota/models/eczane.dart';

Future<List<Eczane>> fetchEczaneler() async {
  final url = Uri.parse("https://www.erzurumeo.org.tr/nobetci-eczaneler/25");
  final response = await http.get(url);

  if (response.statusCode != 200) {
    throw Exception("Eczaneler alınamadı (status ${response.statusCode})");
  }

  final document = parser.parse(response.body);
  final eczaneCards = document.querySelectorAll("div.col-md-12.nobetci");
  final List<Eczane> list = [];

  for (var card in eczaneCards) {
    String ad = card.querySelector("strong")?.text.trim() ?? "";
    String ilceRaw = card.querySelector("h4")?.text.trim() ?? "";
    String ilce = ilceRaw.contains("-") ? ilceRaw.split("-").last.trim() : "";

    final adresNode = card.querySelector("p");
    String adres = "";
    if (adresNode != null) {
      adres = adresNode.text
          .replaceAll("Haritada görüntülemek için tıklayınız...", "")
          .replaceAll(RegExp(r"0\d{9,10}"), "")
          .replaceAll(RegExp(r"Adres:"), "")
          .replaceAll(RegExp(r"Tel:?"), "")
          .replaceAll('"', '')
          .replaceAll(RegExp(r"\s+"), " ")
          .trim();
    }

    String telefon =
        card.querySelector("a[href^='tel:']")?.text.trim() ?? "Bilinmiyor";

    double lat = 0.0;
    double lng = 0.0;
    final mapLink = card
        .querySelector("a[href^='https://maps.google.com/maps']")
        ?.attributes["href"];
    if (mapLink != null && mapLink.contains("q=")) {
      final coords = mapLink.split("q=").last.split(",");
      if (coords.length >= 2) {
        lat = double.tryParse(coords[0]) ?? 0.0;
        lng = double.tryParse(coords[1]) ?? 0.0;
      }
    }

    final exists = list.any((e) => e.ad == ad && e.telefon == telefon);
    if (!exists && ad.isNotEmpty) {
      list.add(Eczane(
        ad: ad,
        ilce: ilce,
        adres: adres,
        telefon: telefon,
        lat: lat,
        lng: lng,
      ));
    }
  }

  return list;
}