import '../models/notification_model.dart';

class NotificationService {
  static final List<AppNotification> _mockNotifications = [
    AppNotification(
      id: '1',
      title: 'Hoş Geldiniz!',
      body: 'Erzurum Şehir Rehberi uygulamasına hoş geldiniz. Şehri keşfetmeye başlayabilirsiniz.',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    AppNotification(
      id: '2',
      title: 'Yol Bakım Çalışması',
      body: 'Cumhuriyet Caddesi üzerindeki duraklarda bakım çalışması nedeniyle kısa süreli gecikmeler yaşanabilir.',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
    ),
    AppNotification(
      id: '3',
      title: 'Yeni Etkinlik!',
      body: 'Yakın zamanda düzenlenecek olan Kar Festivali etkinliklerini "Yaklaşan Etkinlikler" sayfasından takip edebilirsiniz.',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  Future<List<AppNotification>> getNotifications() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _mockNotifications;
  }

  Future<void> markAsRead(String id) async {
    final index = _mockNotifications.indexWhere((n) => n.id == id);
    if (index >= 0) {
      _mockNotifications[index].isRead = true;
    }
  }

  Future<int> getUnreadCount() async {
    return _mockNotifications.where((n) => !n.isRead).length;
  }
}