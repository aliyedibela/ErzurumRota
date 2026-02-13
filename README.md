# 🚌 Erzurum Şehir Rehberi — Rota Öneri Sistemi

<p align="center">
  <img src="assets/icons/erzbblogoformain.png" width="120" alt="Erzurum Büyükşehir Belediyesi Logo"/>
</p>

<p align="center">
  <b>Senin Şehrin, Senin Rehberin.</b><br/>
  Belediyemiz için hazırlanan Akıllı Şehir Temalı Bitirme Projesi.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter"/>
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart"/>
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green?style=for-the-badge"/>
  <img src="https://img.shields.io/badge/OSRM-Routing-orange?style=for-the-badge"/>
</p>

---

## 📱 Özellikler

### 🗺️ Rota Öneri Sistemi
- **Otobüs Hatları** — A1, B1-B3, G1-G14, K1-K11, M11 ve daha fazlası (60+ hat)
- **Direkt & Aktarmalı Rota** — En kısa yol algoritmasıyla otomatik hat önerisi
- **Yürüyüş Rotası** — 1 km altı mesafeler için yaya yönlendirme
- **Araç Rotası** — Kişisel araç için sürüş yönlendirme
- **Canlı Otobüs Takibi** — Gerçek zamanlı simülasyonla otobüs konumları
- **Tahmini Varış Süresi** — Durak bazlı ETA hesaplama

### 🚕 Taksi Sistemi
- Erzurum genelinde **taksi durağı haritası**
- **Anlık taksi çağırma** — SignalR ile gerçek zamanlı sürücü eşleşmesi
- Tahmini ücret hesaplama
- Sürücü onay/red bildirimi

### 🏙️ Şehir Rehberi
| Sekme | İçerik |
|-------|--------|
| 🏠 Ana Sayfa | Genel menü ve hızlı erişim |
| 💊 Nöbetçi Eczaneler | Güncel nöbetçi eczane listesi |
| 🎭 Yaklaşan Etkinlikler | Kültür & sanat takvimi |
| 📜 Erzurum Tarihçesi | Şehrin tarihi |
| 🗺️ Rota Öneri Sistemi | Ulaşım planlayıcı |
| 📍 Gezilecek Yerler | Önemli lokasyonlar |
| 🌍 Son Depremler | Güncel deprem verileri |
| 🌤️ Hava Durumu | Anlık hava bilgisi |
| 👔 Eski Başkanlar | Belediye başkanları tarihi |

---

## 🛠️ Teknik Altyapı

```
erzurum_rota/
├── lib/
│   ├── main.dart                  # Ana uygulama & TabBar
│   ├── route_page.dart            # Rota öneri motoru
│   ├── bus_simulator.dart         # Canlı otobüs simülasyonu
│   ├── stops_layer.dart           # Harita durak katmanı
│   ├── taxi_stands.dart           # Taksi durağı verileri
│   ├── generated_polylines.dart   # Hat koordinatları (60+ hat)
│   └── utils/
│       └── stop_utils.dart        # Durak ismi çözümleme
├── assets/
│   ├── data/
│   │   └── all_stops.json         # Tüm durak koordinatları
│   └── icons/
└── ...
```

### Kullanılan Teknolojiler

| Paket | Kullanım |
|-------|---------|
| `flutter_map` | OpenStreetMap harita entegrasyonu |
| `latlong2` | Koordinat hesaplama |
| `geolocator` | Kullanıcı konumu |
| `http` | REST API çağrıları |
| `signalr_core` | Gerçek zamanlı taksi iletişimi |
| `uuid` | Benzersiz istek ID üretimi |

### Backend Servisleri
- **OSRM (Yürüyüş)** — Yaya rota hesaplama
- **OSRM (Araç)** — Sürüş rota hesaplama
- **Google Places API** — Yer arama & otomatik tamamlama
- **SignalR Hub** — Taksi sürücü eşleşme servisi

---

## 🚀 Kurulum

### Gereksinimler
- Flutter 3.x
- Dart 3.x
- Android Studio / VS Code
- Android SDK veya Xcode (iOS için)

### Kurulum Adımları

```bash
# Repoyu klonla
git clone https://github.com/erzurum-bb/erzurum-rota.git
cd erzurum-rota

# Bağımlılıkları yükle
flutter pub get

# Uygulamayı çalıştır
flutter run
```

### API Anahtarları

`lib/route_page.dart` dosyasında aşağıdaki alanları doldurun:

```dart
const apiKey = "YOUR_GOOGLE_PLACES_API_KEY";
```

### OSRM Sunucu Yapılandırması

`lib/route_page.dart` içindeki URL'leri kendi OSRM sunucunuzla güncelleyin:

```dart
// Yaya rotası için
final baseUrl = "https://YOUR_OSRM_WALKING_SERVER";

// Araç rotası için  
final baseUrl = "https://YOUR_OSRM_DRIVING_SERVER";
```

---

## 🗺️ Rota Algoritması Nasıl Çalışır?

```
Kullanıcı A → B noktası seçer
         │
         ▼
  60+ hat taranır (400m yarıçap)
         │
         ├── Direkt hat bulundu? → En iyi segment seçilir
         │                         (Skor = yürüyüş mesafesi + otobüs mesafesi)
         │
         ├── Aktarma gerekiyor? → Kesişim noktası hesaplanır
         │                        (İki hat arasında 80m eşik)
         │
         ├── Mesafe < 1km? → Yürüyüş önerilir
         │
         └── Her durumda araç ve taksi seçeneği eklenir
```

---

## 📸 Ekran Görüntüleri

> Yakında eklenecek

---

## 🤝 Katkıda Bulunma

1. Fork'la
2. Feature branch oluştur (`git checkout -b feature/yeni-ozellik`)
3. Commit'le (`git commit -m 'feat: yeni özellik eklendi'`)
4. Push'la (`git push origin feature/yeni-ozellik`)
5. Pull Request aç

---
