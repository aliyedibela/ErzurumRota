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