import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

const Duration _kShortTimeout = Duration(seconds: 30);
const Duration _kPaymentTimeout = Duration(seconds: 20);

class AppUser {
  final String id;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final bool isVerified;
  final List<UserCard> cards;

  AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    this.isVerified = false,
    this.cards = const [],
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] ?? '',
        email: j['email'] ?? '',
        fullName: j['fullName'] ?? '',
        phoneNumber: j['phoneNumber'],
        isVerified: j['isVerified'] ?? false,
        cards: (j['cards'] as List? ?? [])
            .map((c) => UserCard.fromJson(c))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'isVerified': isVerified,
        'cards': cards.map((c) => c.toJson()).toList(),
      };
}

class UserCard {
  final String id;
  final String userId;
  final String cardCode;
  final String cardNickname;
  final double balance;
  final DateTime addedAt;
  final DateTime lastUsedAt;

  UserCard({
    required this.id,
    required this.userId,
    required this.cardCode,
    required this.cardNickname,
    required this.balance,
    required this.addedAt,
    required this.lastUsedAt,
  });

  factory UserCard.fromJson(Map<String, dynamic> j) {
    return UserCard(
      id: j['id'] ?? '',
      userId: j['userId'] ?? '',
      cardCode: j['cardCode'] ?? '',
      cardNickname: j['cardNickname'] ?? 'Kartım',
      balance: (j['balance'] as num?)?.toDouble() ?? 0.0,
      addedAt: j['addedAt'] != null
          ? DateTime.tryParse(j['addedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastUsedAt: j['lastUsedAt'] != null
          ? DateTime.tryParse(j['lastUsedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'cardCode': cardCode,
        'cardNickname': cardNickname,
        'balance': balance,
        'addedAt': addedAt.toIso8601String(),
        'lastUsedAt': lastUsedAt.toIso8601String(),
      };
}

class UserAuthService {

  static final String _base = "${dotenv.env['API_BASE_URL']}/api/user";
  static final String _cardBase = "${dotenv.env['API_BASE_URL']}/api/card";
  static final String _paymentBase = "${dotenv.env['API_BASE_URL']}/api/payment";
  static final String _apiBase = dotenv.env['API_BASE_URL'] ?? '';

  /// Railway.app backend'i uyandırır (uyku modundan çıkarır).
  Future<void> _pingBackend() async {
    try {
      await http
          .get(Uri.parse("$_apiBase/health"))
          .timeout(const Duration(seconds: 8));
      print("✅ Backend ping başarılı");
    } catch (_) {
      print("⚠️ Backend ping timeout (uyku modunda olabilir)");
    }
  }

  Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
  }) async {
    await _pingBackend(); // Railway cold start önlemi
    try {
      final res = await http.post(
        Uri.parse("$_base/signup"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'fullName': fullName,
          'phoneNumber': phoneNumber,
        }),
      ).timeout(_kShortTimeout);
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        return {
          'success': true,
          'userId': data['userId'],
          'debugCode': data['debugCode']
        };
      }
      return {'success': false, 'error': data['error'] ?? 'Kayıt başarısız'};
    } catch (e) {
      return {'success': false, 'error': 'Sunucuya ulaşılamadı. Lütfen tekrar deneyin.'};
    }
  }

  Future<Map<String, dynamic>> resendCode({required String userId}) async {
    try {
      final res = await http.post(
        Uri.parse("$_base/resend-code"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId}),
      ).timeout(_kShortTimeout);
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) return {'success': true};
      return {'success': false, 'error': data['error'] ?? 'Kod gönderilemedi'};
    } catch (e) {
      return {'success': false, 'error': 'Sunucuya ulaşılamadı. Lütfen tekrar deneyin.'};
    }
  }

  Future<Map<String, dynamic>> verify({
    required String userId,
    required String code,
  }) async {
    try {
      final res = await http.post(
        Uri.parse("$_base/verify"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId, 'code': code}),
      ).timeout(_kShortTimeout);
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) return {'success': true};
      return {'success': false, 'error': data['error'] ?? 'Doğrulama başarısız'};
    } catch (e) {
      return {'success': false, 'error': 'Sunucuya ulaşılamadı. Lütfen tekrar deneyin.'};
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await http.post(
        Uri.parse("$_base/login"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(_kShortTimeout);
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        final user = AppUser.fromJson(data);
        await _saveUser(user, data['token']);
        return {'success': true, 'user': user};
      }
      return {'success': false, 'error': data['error'] ?? 'Giriş başarısız'};
    } catch (e) {
      return {'success': false, 'error': 'Sunucuya ulaşılamadı. Lütfen tekrar deneyin.'};
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_data');
    await prefs.remove('user_token');
  }

  Future<Map<String, dynamic>> forgotPassword({required String email}) async {
    try {
      final res = await http.post(
        Uri.parse("$_base/forgot-password"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(_kShortTimeout);
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) return {'success': true, 'debugCode': data['debugCode']};
      return {'success': false, 'error': data['error'] ?? 'İşlem başarısız'};
    } catch (e) {
      return {'success': false, 'error': 'Sunucuya ulaşılamadı'};
    }
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      final res = await http.post(
        Uri.parse("$_base/reset-password"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'code': code,
          'newPassword': newPassword,
        }),
      ).timeout(_kShortTimeout);
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) return {'success': true};
      return {'success': false, 'error': data['error'] ?? 'Şifre güncellenemedi'};
    } catch (e) {
      return {'success': false, 'error': 'Sunucuya ulaşılamadı'};
    }
  }

  Future<Map<String, dynamic>> addCard({
    required String userId,
    required String cardCode,
    String? cardNickname,
  }) async {
    try {
      final res = await http.post(
        Uri.parse("$_cardBase/add"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'cardCode': cardCode,
          'cardNickname': cardNickname ?? 'Kartım',
        }),
      ).timeout(_kShortTimeout);
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        return {'success': true, 'card': UserCard.fromJson(data['card'])};
      }
      return {'success': false, 'error': data['error'] ?? 'Kart eklenemedi'};
    } catch (e) {
      return {'success': false, 'error': 'Sunucuya ulaşılamadı. Lütfen tekrar deneyin.'};
    }
  }

  Future<Map<String, dynamic>> deleteCard({
    required String cardId,
    required String userId,
  }) async {
    try {
      final res = await http.delete(
        Uri.parse("$_cardBase/$cardId?userId=$userId"),
      ).timeout(_kShortTimeout);
      if (res.statusCode == 200) return {'success': true};
      final data = jsonDecode(res.body);
      return {'success': false, 'error': data['error'] ?? 'Kart silinemedi'};
    } catch (e) {
      return {'success': false, 'error': 'Sunucuya ulaşılamadı. Lütfen tekrar deneyin.'};
    }
  }

  Future<List<dynamic>> getCardHistory(String cardCode) async {
    try {
      final res = await http
          .get(Uri.parse("$_paymentBase/history/$cardCode"))
          .timeout(_kShortTimeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['transactions'] as List? ?? [];
      }
    } catch (e) {
      print('Geçmiş hatası: $e');
    }
    return [];
  }

  Future<bool> topUpBalance(String cardCode, double amount) async {
    try {
      final res = await http.post(
        Uri.parse("$_paymentBase/topup"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'cardCode': cardCode, 'amount': amount}),
      ).timeout(_kShortTimeout);
      return res.statusCode == 200;
    } catch (e) {
      print('Bakiye yükleme hatası: $e');
      return false;
    }
  }

  Future<AppUser?> refreshProfile(String userId) async {
    try {
      final res = await http
          .get(Uri.parse("$_base/$userId"))
          .timeout(_kShortTimeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return AppUser.fromJson(data);
      }
    } catch (e) {
      print('Profil yenileme hatası: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> processIyzicoPaymentWithCard({
    required String cardCode,
    required double amount,
    required String userEmail,
    required String userName,
    required String cardNumber,
    required String cardHolder,
    required String expMonth,
    required String expYear,
    required String cvv,
  }) async {
    try {
      print('🔵 Iyzico ödeme başlatılıyor: $amount TL');

      // Railway.app backend'i uyandır (uyku modunda ise)
      await _pingBackend();

      final response = await http.post(
        Uri.parse('$_paymentBase/iyzico'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'cardCode': cardCode,
          'amount': amount,
          'userEmail': userEmail,
          'userName': userName,
          'cardDetails': {
            'cardNumber': cardNumber,
            'cardHolder': cardHolder,
            'expMonth': expMonth,
            'expYear': expYear,
            'cvv': cvv,
          }
        }),
      ).timeout(_kPaymentTimeout);

      print('🔵 Backend yanıt kodu: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('✅ Ödeme başarılı! PaymentId: ${data['paymentId']}');
          return {
            'success': true,
            'paymentId': data['paymentId'],
            'amount': data['amount'],
            'oldBalance': data['oldBalance'],
            'newBalance': data['newBalance'],
          };
        } else {
          final errorMsg = data['error'] ?? 'Ödeme başarısız';
          print('❌ Ödeme başarısız: $errorMsg');
          return {'success': false, 'error': errorMsg};
        }
      } else {
        Map<String, dynamic> data = {};
        try { data = jsonDecode(response.body); } catch (_) {}
        final errorMsg = data['error'] ?? 'Sunucu hatası (${response.statusCode})';
        print('❌ HTTP Error: $errorMsg');
        return {'success': false, 'error': errorMsg};
      }
    } on http.ClientException catch (e) {
      print('❌ Ağ hatası: $e');
      return {'success': false, 'error': 'İnternet bağlantısı kesildi. Lütfen tekrar deneyin.'};
    } catch (e) {
      print('❌ Ödeme hatası: $e');
      // Timeout kontrolü
      if (e.toString().contains('TimeoutException')) {
        return {'success': false, 'error': 'Sunucu yanıt vermedi. Lütfen birkaç saniye bekleyip tekrar deneyin.'};
      }
      return {'success': false, 'error': 'Beklenmeyen hata. Lütfen tekrar deneyin.'};
    }
  }


  Future<void> _saveUser(AppUser user, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(user.toJson()));
    await prefs.setString('user_token', token);
  }


  Future<void> saveUser(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(user.toJson()));
  }


  Future<AppUser?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user_data');
    if (raw == null) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw));
    } catch (e) {
      print('User parse hatası: $e');
      return null;
    }
  }

  Future<String?> getSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_token');
  }
}