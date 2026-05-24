import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';

class NotificationService {
  static const String _key = 'app_notifications';

  // Varsayılan bildirimler — ilk açılışta yüklenir
  static final List<AppNotification> _defaults = [
    AppNotification(
      id: 'welcome',
      title: 'Hoş Geldiniz!',
      body: 'Erzurum Şehir Rehberi uygulamasına hoş geldiniz. Şehri keşfetmeye başlayabilirsiniz.',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    AppNotification(
      id: 'road_work',
      title: 'Yol Bakım Çalışması',
      body: 'Cumhuriyet Caddesi üzerindeki duraklarda bakım çalışması nedeniyle kısa süreli gecikmeler yaşanabilir.',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
    ),
    AppNotification(
      id: 'festival',
      title: 'Yeni Etkinlik!',
      body: 'Yakın zamanda düzenlenecek olan Kar Festivali etkinliklerini "Yaklaşan Etkinlikler" sayfasından takip edebilirsiniz.',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  Future<List<AppNotification>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key);

    if (raw == null || raw.isEmpty) {
      // İlk açılış → varsayılanları kaydet ve döndür
      await _saveAll(_defaults);
      return List.from(_defaults);
    }

    return raw
        .map((e) => AppNotification.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  Future<void> markAsRead(String id) async {
    final notifications = await getNotifications();
    final idx = notifications.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      notifications[idx].isRead = true;
      await _saveAll(notifications);
    }
  }

  Future<int> getUnreadCount() async {
    final notifications = await getNotifications();
    return notifications.where((n) => !n.isRead).length;
  }

  /// FCM'den gelen bildirimi başa ekler
  Future<void> addNotification(AppNotification notification) async {
    final notifications = await getNotifications();
    // Aynı id varsa ekleme
    if (notifications.any((n) => n.id == notification.id)) return;
    notifications.insert(0, notification);
    // Maksimum 50 bildirim tut
    if (notifications.length > 50) notifications.removeLast();
    await _saveAll(notifications);
  }

  Future<void> deleteNotification(String id) async {
    final notifications = await getNotifications();
    notifications.removeWhere((n) => n.id == id);
    await _saveAll(notifications);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<void> _saveAll(List<AppNotification> notifications) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      notifications.map((n) => jsonEncode(n.toJson())).toList(),
    );
  }
}
