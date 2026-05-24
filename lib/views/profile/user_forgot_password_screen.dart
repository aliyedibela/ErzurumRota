import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/user_auth_service.dart';

class UserForgotPasswordScreen extends StatefulWidget {
  const UserForgotPasswordScreen({super.key});

  @override
  State<UserForgotPasswordScreen> createState() => _UserForgotPasswordScreenState();
}

class _UserForgotPasswordScreenState extends State<UserForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _svc = UserAuthService();

  bool _loading = false;
  bool _codeSent = false;
  bool _obscure = true;

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _snack('Lütfen email adresinizi girin', Colors.red);
      return;
    }

    setState(() => _loading = true);
    final res = await _svc.forgotPassword(email: email);
    setState(() => _loading = false);

    if (res['success']) {
      _snack('Sıfırlama kodu email adresinize gönderildi', Colors.green);
      setState(() => _codeSent = true);
    } else {
      _snack(res['error'] ?? 'Hata oluştu', Colors.red);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    final newPass = _newPassCtrl.text.trim();

    if (code.isEmpty || newPass.isEmpty) {
      _snack('Lütfen tüm alanları doldurun', Colors.red);
      return;
    }

    setState(() => _loading = true);
    final res = await _svc.resetPassword(
      email: email,
      code: code,
      newPassword: newPass,
    );
    setState(() => _loading = false);

    if (res['success']) {
      _snack('Şifreniz başarıyla güncellendi. Giriş yapabilirsiniz.', Colors.green);
      Navigator.pop(context);
    } else {
      _snack(res['error'] ?? 'Hata oluştu', Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1A237E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_reset_rounded, size: 60, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'Şifre Sıfırlama',
                  style: TextStyle(
                      color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 36),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      children: [
                        _field(_emailCtrl, 'Email', Icons.email_outlined,
                            type: TextInputType.emailAddress, enabled: !_codeSent),
                        if (_codeSent) ...[
                          const SizedBox(height: 14),
                          _field(_codeCtrl, 'Doğrulama Kodu', Icons.vpn_key_outlined,
                              type: TextInputType.number),
                          const SizedBox(height: 14),
                          _field(_newPassCtrl, 'Yeni Şifre', Icons.lock_outline,
                              obscure: _obscure,
                              suffix: IconButton(
                                icon: Icon(
                                    _obscure ? Icons.visibility_off : Icons.visibility,
                                    color: Colors.white60),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              )),
                        ],
                        const SizedBox(height: 24),
                        _loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16)),
                                  ),
                                  onPressed: _codeSent ? _resetPassword : _sendCode,
                                  icon: Icon(
                                      _codeSent
                                          ? Icons.check_rounded
                                          : Icons.send_rounded,
                                      color: const Color(0xFF1A237E)),
                                  label: Text(
                                    _codeSent
                                        ? 'Şifreyi Güncelle'
                                        : 'Sıfırlama Kodu Gönder',
                                    style: const TextStyle(
                                        color: Color(0xFF1A237E),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool obscure = false,
    TextInputType? type,
    Widget? suffix,
    bool enabled = true,
  }) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: type,
      enabled: enabled,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        prefixIcon: Icon(icon, color: Colors.white60),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.25))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.25))),
        disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _newPassCtrl.dispose();
    super.dispose();
  }
}