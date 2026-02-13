import 'dart:ui';
import 'package:flutter/material.dart';
import 'user_auth_service.dart';

class UserLoginScreen extends StatefulWidget {
  const UserLoginScreen({super.key});
  @override
  State<UserLoginScreen> createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends State<UserLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _svc = UserAuthService();
  bool _loading = false;
  bool _obscure = true;

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
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded, size: 60, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text('Kullanıcı Girişi',
                    style: TextStyle(
                        color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text('Erzurum Şehir Rehberi',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
              ),
              const SizedBox(height: 36),

           
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: Column(children: [
                      _field(_emailCtrl, 'Email', Icons.email_outlined,
                          type: TextInputType.emailAddress),
                      const SizedBox(height: 14),
                      _field(_passCtrl, 'Şifre', Icons.lock_outline,
                          obscure: _obscure,
                          suffix: IconButton(
                            icon: Icon(
                                _obscure ? Icons.visibility_off : Icons.visibility,
                                color: Colors.white60),
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
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: _login,
                                icon: const Icon(Icons.login,
                                    color: Color(0xFF1A237E)),
                                label: const Text('Giriş Yap',
                                    style: TextStyle(
                                        color: Color(0xFF1A237E),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ),
                            ),
                    ]),
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
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('Hesabınız yok mu? ',
                        style: TextStyle(color: Colors.white.withOpacity(0.85))),
                    const Text('Kayıt Olun',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white)),
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
      controller: ctrl,
      obscureText: obscure,
      keyboardType: type,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: Colors.white60),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.25))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.25))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white, width: 1.5)),
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

  Future<void> _signup() async {
    if (_nameCtrl.text.isEmpty || _emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      _snack('Ad, email ve şifre zorunludur', Colors.red);
      return;
    }
    setState(() => _loading = true);
    final res = await _svc.signup(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text.trim(),
      fullName: _nameCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
    );
    setState(() => _loading = false);
    if (!mounted) return;
    if (res['success']) {
      final user = await Navigator.push<AppUser>(
        context,
        MaterialPageRoute(
          builder: (_) => UserVerifyScreen(
              userId: res['userId'], email: _emailCtrl.text.trim()),
        ),
      );
      if (user != null && mounted) Navigator.pop(context, user);
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            children: [
              Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text('Kayıt Ol',
                    style: TextStyle(
                        color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: Column(children: [
                      _field(_nameCtrl, 'Ad Soyad', Icons.badge_outlined),
                      const SizedBox(height: 14),
                      _field(_emailCtrl, 'Email', Icons.email_outlined,
                          type: TextInputType.emailAddress),
                      const SizedBox(height: 14),
                      _field(_phoneCtrl, 'Telefon (İsteğe Bağlı)', Icons.phone_outlined,
                          type: TextInputType.phone),
                      const SizedBox(height: 14),
                      _field(_passCtrl, 'Şifre', Icons.lock_outline, obscure: _obscure,
                          suffix: IconButton(
                            icon: Icon(
                                _obscure ? Icons.visibility_off : Icons.visibility,
                                color: Colors.white60),
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
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: _signup,
                                icon: const Icon(Icons.how_to_reg,
                                    color: Color(0xFF1A237E)),
                                label: const Text('Kayıt Ol',
                                    style: TextStyle(
                                        color: Color(0xFF1A237E),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
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
      controller: ctrl,
      obscureText: obscure,
      keyboardType: type,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: Colors.white60),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.25))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.25))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }
}

class UserVerifyScreen extends StatefulWidget {
  final String userId;
  final String email;
  const UserVerifyScreen({super.key, required this.userId, required this.email});
  @override
  State<UserVerifyScreen> createState() => _UserVerifyScreenState();
}

class _UserVerifyScreenState extends State<UserVerifyScreen> {
  final _codeCtrl = TextEditingController();
  final _svc = UserAuthService();
  bool _loading = false;

  Future<void> _verify() async {
    if (_codeCtrl.text.length != 6) {
      _snack('6 haneli kodu girin', Colors.red);
      return;
    }
    setState(() => _loading = true);
    final res = await _svc.verify(userId: widget.userId, code: _codeCtrl.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);
    if (res['success']) {
      _snack('Hesap doğrulandı! Giriş yapılıyor...', Colors.green);
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      Navigator.pop(context); 
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
            colors: [Color(0xFF0D47A1), Color(0xFF1A237E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ]),
                const Spacer(),
                const Icon(Icons.mark_email_unread_outlined, size: 80, color: Colors.white70),
                const SizedBox(height: 20),
                const Text('Email Doğrulama',
                    style: TextStyle(
                        color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(widget.email,
                    style: const TextStyle(color: Colors.white60, fontSize: 14)),
                const SizedBox(height: 6),
                const Text('adresine gönderilen 6 haneli kodu girin.',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                    textAlign: TextAlign.center),
                const SizedBox(height: 32),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Column(children: [
                        TextField(
                          controller: _codeCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 8),
                          decoration: InputDecoration(
                            hintText: '------',
                            hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 28,
                                letterSpacing: 8),
                            counterText: '',
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.08),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    BorderSide(color: Colors.white.withOpacity(0.2))),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    BorderSide(color: Colors.white.withOpacity(0.2))),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    const BorderSide(color: Colors.white, width: 1.5)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16)),
                                  ),
                                  onPressed: _verify,
                                  child: const Text('Doğrula',
                                      style: TextStyle(
                                          color: Color(0xFF1A237E),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                ),
                              ),
                      ]),
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }
}