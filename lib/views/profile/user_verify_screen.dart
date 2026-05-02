import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/user_auth_service.dart';

class UserVerifyScreen extends StatefulWidget {
  final String userId;
  final String email;
  /// Backend'den dönen debug kodu — email gelmediğinde gösterilir
  final String? debugCode;
  const UserVerifyScreen({super.key, required this.userId, required this.email, this.debugCode});
  @override
  State<UserVerifyScreen> createState() => _UserVerifyScreenState();
}

class _UserVerifyScreenState extends State<UserVerifyScreen> {
  final _codeCtrl = TextEditingController();
  final _svc = UserAuthService();
  bool _loading = false;
  bool _showDebugCode = false;

  Future<void> _verify() async {
    if (_codeCtrl.text.length != 6) { _snack('6 haneli kodu girin', Colors.red); return; }
    setState(() => _loading = true);
    final res = await _svc.verify(userId: widget.userId, code: _codeCtrl.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);
    if (res['success']) {
      _snack('Hesap doğrulandı! Giriş ekranına yönlendiriliyorsunuz...', Colors.green);
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;
      // true döndür → signup screen giriş ekranına yönlendirir
      Navigator.pop(context, true);
    } else {
      _snack(res['error'] ?? 'Doğrulama başarısız', Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF1A237E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Row(children: [
                IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
              ]),
              const Spacer(),
              const Icon(Icons.mark_email_unread_outlined, size: 80, color: Colors.white70),
              const SizedBox(height: 20),
              const Text('Email Doğrulama', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(widget.email, style: const TextStyle(color: Colors.white60, fontSize: 14)),
              const SizedBox(height: 6),
              const Text('adresine gönderilen 6 haneli kodu girin.', style: TextStyle(color: Colors.white54, fontSize: 13), textAlign: TextAlign.center),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.mark_email_read_outlined, color: Colors.white54, size: 16),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Email gönderildi. Göremiyorsanız spam / önemsiz klasörünüzü kontrol edin.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Column(children: [
                      TextField(
                        controller: _codeCtrl, keyboardType: TextInputType.number,
                        maxLength: 6, textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 8),
                        decoration: InputDecoration(
                          hintText: '------',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 28, letterSpacing: 8),
                          counterText: '',
                          filled: true, fillColor: Colors.white.withOpacity(0.08),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white, width: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : SizedBox(
                              width: double.infinity, height: 52,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                onPressed: _verify,
                                child: const Text('Doğrula', style: TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ),
                    ]),
                  ),
                ),
              ),
              const Spacer(),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() { _codeCtrl.dispose(); super.dispose(); }
}
