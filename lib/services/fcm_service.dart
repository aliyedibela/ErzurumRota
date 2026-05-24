import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';
import 'notification_service.dart';

/// Arka planda gelen FCM mesajlarını işler — top-level fonksiyon olmalı
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Arka planda bildirim kaydını NotificationService üzerinden yapar
  final notifSvc = NotificationService();
  await notifSvc.addNotification(_remoteMessageToNotification(message));
}

AppNotification _remoteMessageToNotification(RemoteMessage message) {
  return AppNotification(
    id: message.messageId ??
        DateTime.now().millisecondsSinceEpoch.toString(),
    title: message.notification?.title ?? 'Bildirim',
    body: message.notification?.body ?? '',
    timestamp: message.sentTime ?? DateTime.now(),
  );
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final NotificationService _notifSvc = NotificationService();

  static const _channelId = 'erzurum_rota_high';
  static const _channelName = 'Erzurum Şehir Rehberi';
  static const _channelDesc = 'Önemli şehir bildirimler';

  Future<void> initialize() async {
    // İzin iste
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint(
        '🔔 FCM izin durumu: ${settings.authorizationStatus.name}');

    // Local notification kanalı oluştur (Android 8+)
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
      playSound: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Local notifications başlat
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _localNotifications.initialize(initSettings);

    // Arka plan mesaj handler'ı kaydet
    FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler);

    // Ön planda gelen mesajlar → local notification göster + kaydet
    FirebaseMessaging.onMessage.listen(_handleForeground);

    // Bildirime tıklanarak açılış (arka plan → ön plan)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // Uygulama kapalıyken bildirime tıklanarak açılış
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _handleTap(initial);

    // FCM token'ı kaydet
    final token = await _messaging.getToken();
    if (token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
      debugPrint('🔑 FCM Token: $token');
    }

    // Token yenilenince güncelle
    _messaging.onTokenRefresh.listen((newToken) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', newToken);
    });

    // Tüm kullanıcılara toplu bildirim için konuya abone ol
    await _messaging.subscribeToTopic('erzurum_rehber');
    debugPrint('✅ FCM "erzurum_rehber" konusuna abone olundu');
  }

  Future<void> _handleForeground(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // Ekranda local notification göster
    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );

    // SharedPreferences'a kaydet
    await _notifSvc.addNotification(_remoteMessageToNotification(message));
  }

  void _handleTap(RemoteMessage message) {
    // Bildirime tıklandığında yapılacak navigasyon buraya eklenir
    debugPrint('🔔 Bildirime tıklandı: ${message.notification?.title}');
  }

  /// Sunucuya göndermek için FCM token'ı döndürür
  Future<String?> getToken() => _messaging.getToken();
}
