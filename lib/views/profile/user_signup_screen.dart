import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/user_auth_service.dart';
import 'user_verify_screen.dart';
import 'user_login_screen.dart';

class UserSignupScreen extends StatefulWidget {
  const UserSignupScreen({super.key});
  @override
  State<UserSignupScreen> createState() => _UserSignupScreenState();
}

class _UserSignupScreenState extends State<UserSignupScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _svc = UserAuthService();
  bool _loading = false;
  bool _obscure = true;
  String _countryCode = '+90';
  String _countryFlag = '🇹🇷';

  static const List<Map<String, String>> _countries = [
    {'flag': '🇹🇷', 'name': 'Türkiye', 'code': '+90'},
    {'flag': '🇩🇪', 'name': 'Almanya', 'code': '+49'},
    {'flag': '🇬🇧', 'name': 'İngiltere', 'code': '+44'},
    {'flag': '🇺🇸', 'name': 'ABD', 'code': '+1'},
    {'flag': '🇫🇷', 'name': 'Fransa', 'code': '+33'},
    {'flag': '🇳🇱', 'name': 'Hollanda', 'code': '+31'},
    {'flag': '🇧🇪', 'name': 'Belçika', 'code': '+32'},
    {'flag': '🇦🇹', 'name': 'Avusturya', 'code': '+43'},
    {'flag': '🇨🇭', 'name': 'İsviçre', 'code': '+41'},
    {'flag': '🇸🇪', 'name': 'İsveç', 'code': '+46'},
    {'flag': '🇳🇴', 'name': 'Norveç', 'code': '+47'},
    {'flag': '🇩🇰', 'name': 'Danimarka', 'code': '+45'},
    {'flag': '🇦🇿', 'name': 'Azerbaycan', 'code': '+994'},
    {'flag': '🇰🇿', 'name': 'Kazakistan', 'code': '+7'},
    {'flag': '🇸🇦', 'name': 'Suudi Arabistan', 'code': '+966'},
    {'flag': '🇦🇪', 'name': 'BAE', 'code': '+971'},
    {'flag': '🇶🇦', 'name': 'Katar', 'code': '+974'},
    {'flag': '🇮🇷', 'name': 'İran', 'code': '+98'},
    {'flag': '🇷🇺', 'name': 'Rusya', 'code': '+7'},
    {'flag': '🇬🇷', 'name': 'Yunanistan', 'code': '+30'},
    {'flag': '🇧🇬', 'name': 'Bulgaristan', 'code': '+359'},
  ];

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.85,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A237E).withValues(alpha: 0.97),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Column(children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, color: Colors.white24),
            const SizedBox(height: 16),
            const Text('Ülke Kodu Seç', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(color: Colors.white12, height: 24),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl, itemCount: _countries.length,
                itemBuilder: (_, i) {
                  final c = _countries[i];
                  final isSelected = c['code'] == _countryCode;
                  return ListTile(
                    leading: Text(c['flag']!, style: const TextStyle(fontSize: 24)),
                    title: Text(c['name']!, style: TextStyle(color: isSelected ? Colors.lightBlueAccent : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    trailing: Text(c['code']!, style: TextStyle(color: isSelected ? Colors.lightBlueAccent : Colors.white54, fontWeight: FontWeight.bold)),
                    onTap: () {
                      setState(() { _countryCode = c['code']!; _countryFlag = c['flag']!; });
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  Future<void> _signup() async {
    if (_nameCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      _snack('Ad, email ve şifre zorunludur', Colors.red); return;
    }
    if (_phoneCtrl.text.isEmpty) {
      _snack('Telefon numarası zorunludur', Colors.red); return;
    }
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      _snack('Geçerli bir telefon numarası girin (min. 10 hane)', Colors.red); return;
    }

    setState(() => _loading = true);
    final res = await _svc.signup(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text.trim(),
      fullName: _nameCtrl.text.trim(),
      phoneNumber: '$_countryCode$digits',
    );
    setState(() => _loading = false);
    if (!mounted) return;
    if (res['success'] == true) {
      // Doğrulama ekranına geç — debugCode'u da ilet (email gelmezse gösterilir)
      final verified = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => UserVerifyScreen(
          userId: res['userId'],
          email: _emailCtrl.text.trim(),
          debugCode: res['debugCode'],
        )),
      );
      if (!mounted) return;
      if (verified == true) {
        // Doğrulama başarılı → login ekranına yönlendir (push, replacement değil)
        if (!mounted) return;
        final user = await Navigator.push<AppUser>(
          context,
          MaterialPageRoute(builder: (_) => UserLoginScreen(
            prefillEmail: _emailCtrl.text.trim(),
          )),
        );
        // LoginScreen'den dönen user → SignupScreen'i de kapat
        if (user != null && mounted) Navigator.pop(context, user);
      }
    } else {
      _snack(res['error'] ?? 'Kayıt başarısız', Colors.red);
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
          gradient: LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1A237E)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            children: [
              Row(children: [
                IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
                const Text('Kayıt Ol', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 24),
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
                      _field(_nameCtrl, 'Ad Soyad', Icons.badge_outlined),
                      const SizedBox(height: 14),
                      _field(_emailCtrl, 'Email', Icons.email_outlined, type: TextInputType.emailAddress),
                      const SizedBox(height: 14),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        GestureDetector(
                          onTap: _showCountryPicker,
                          child: Container(
                            height: 52, padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(_countryFlag, style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 6),
                              Text(_countryCode, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 18),
                            ]),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _phoneCtrl, keyboardType: TextInputType.phone,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: '5XX XXX XX XX',
                              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                              prefixIcon: const Icon(Icons.phone_outlined, color: Colors.white60),
                              filled: true, fillColor: Colors.white.withValues(alpha: 0.08),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.25))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.25))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.white, width: 1.5)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 14),
                      _field(_passCtrl, 'Şifre', Icons.lock_outline, obscure: _obscure,
                          suffix: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.white60),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          )),
                      const SizedBox(height: 24),
                      _loading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : SizedBox(
                              width: double.infinity, height: 52,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                onPressed: _signup,
                                icon: const Icon(Icons.how_to_reg, color: Color(0xFF1A237E)),
                                label: const Text('Kayıt Ol', style: TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ),
                    ]),
                  ),
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
    _nameCtrl.dispose(); _emailCtrl.dispose(); _phoneCtrl.dispose(); _passCtrl.dispose();
    super.dispose();
  }
}