import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/user_auth_service.dart';
import 'user_signup_screen.dart';
import 'user_forgot_password_screen.dart';

class UserLoginScreen extends StatefulWidget {
  /// Kayıt sonrası doğrulama tamamlandıysa email otomatik doldurulur
  final String? prefillEmail;
  const UserLoginScreen({super.key, this.prefillEmail});
  @override
  State<UserLoginScreen> createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends State<UserLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _svc = UserAuthService();
  bool _loading = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    if (widget.prefillEmail != null) {
      _emailCtrl.text = widget.prefillEmail!;
    }
  }

  Future<void> _login() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      _snack('Tüm alanları doldurun', Colors.red);
      return;
    }
    setState(() => _loading = true);
    final res = await _svc.login(
        email: _emailCtrl.text.trim(), password: _passCtrl.text.trim());
    setState(() => _loading = false);
    if (!mounted) return;
    if (res['success']) {
      Navigator.pop(context, res['user'] as AppUser);
    } else {
      _snack(res['error'], Colors.red);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded, size: 60, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text('Kullanıcı Girişi',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text('Erzurum Şehir Rehberi',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
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
                    child: Column(children: [
                      _field(_emailCtrl, 'Email', Icons.email_outlined, type: TextInputType.emailAddress),
                      const SizedBox(height: 14),
                      _field(_passCtrl, 'Şifre', Icons.lock_outline,
                          obscure: _obscure,
                          suffix: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white60),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          )),
                      const SizedBox(height: 24),
                      _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: _login,
                                icon: const Icon(Icons.login, color: Color(0xFF1A237E)),
                                label: const Text('Giriş Yap',
                                    style: TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const UserForgotPasswordScreen()),
                ),
                child: Center(
                  child: Text(
                    'Şifremi Unuttum?',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white54,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () async {
                  final user = await Navigator.push<AppUser>(
                    context,
                    MaterialPageRoute(builder: (_) => const UserSignupScreen()),
                  );
                  if (user != null && mounted) Navigator.pop(context, user);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('Hesabınız yok mu? ', style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
                    const Text('Kayıt Olun',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline, decorationColor: Colors.white)),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, IconData icon,
      {bool obscure = false, TextInputType? type, Widget? suffix}) {
    return TextField(
      controller: ctrl, obscureText: obscure, keyboardType: type,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        prefixIcon: Icon(icon, color: Colors.white60),
        suffixIcon: suffix,
        filled: true, fillColor: Colors.white.withValues(alpha: 0.08),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.25))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.25))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }
}