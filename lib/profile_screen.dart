import 'dart:ui';
import 'package:flutter/material.dart';
import 'user_auth_service.dart';
import 'user_auth_screens.dart';

class ProfileScreen extends StatefulWidget {
  final AppUser? initialUser;
  final void Function(AppUser?)? onUserChanged;

  const ProfileScreen({super.key, this.initialUser, this.onUserChanged});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _svc = UserAuthService();
  AppUser? _user;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _user = widget.initialUser;
    if (_user == null) _loadSavedUser();
  }

  Future<void> _loadSavedUser() async {
    final u = await _svc.getSavedUser();
    if (mounted) setState(() => _user = u);
  }

  Future<void> _refresh() async {
    if (_user == null) return;
    setState(() => _loading = true);
    
    try {
      final fresh = await _svc.refreshProfile(_user!.id);
      
      if (mounted) {
        setState(() {
          if (fresh != null) {
            _user = fresh;
            _svc.saveUser(fresh);
          } else {
            _snack('Profil yenilenemedi', Colors.orange);
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack('Bağlantı hatası: $e', Colors.red);
      }
    }
  }

  Future<void> _openLogin() async {
    final user = await Navigator.push<AppUser>(
      context,
      MaterialPageRoute(builder: (_) => const UserLoginScreen()),
    );
    if (user != null && mounted) {
      setState(() => _user = user);
      widget.onUserChanged?.call(user);
      await _refresh();
    }
  }

  Future<void> _logout() async {
    await _svc.logout();
    if (mounted) {
      setState(() => _user = null);
      widget.onUserChanged?.call(null);
    }
  }

  void _showIyzicoPayment(UserCard card) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false, 
      builder: (ctx) => WillPopScope(
        onWillPop: () async => false, 
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF0D47A1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: IyzicoPaymentForm(
            cardCode: card.cardCode,
            userEmail: _user!.email,
            userName: _user!.fullName,
            onPaymentSuccess: (amount) async {
              Navigator.pop(ctx); 
              setState(() => _loading = true);
              await _refresh(); 
              setState(() => _loading = false);
              _snack('✅ $amount ₺ başarıyla yüklendi!', const Color(0xFF4CAF50));
            },
            onPaymentError: (error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.white, size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ödeme Başarısız',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                error,
                                style: const TextStyle(fontSize: 14, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  backgroundColor: Colors.red.shade700,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 6),
                  margin: EdgeInsets.only(
                    bottom: MediaQuery.of(context).size.height * 0.75, 
                    left: 16,
                    right: 16,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showAddCardDialog() {
    final codeCtrl = TextEditingController();
    final nickCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1A237E).withOpacity(0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Row(children: [
                  Icon(Icons.credit_card, color: Colors.white70, size: 22),
                  SizedBox(width: 10),
                  Text('Kart Ekle',
                      style: TextStyle(
                          color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 20),
                _glassField(codeCtrl, 'Kart Kodu (RFID)', Icons.nfc),
                const SizedBox(height: 12),
                _glassField(nickCtrl, 'Kart Adı  (örn. Öğrenci Kartım)', Icons.label_outline),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('İptal', style: TextStyle(color: Colors.white54)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF42A5F5), 
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        if (codeCtrl.text.isEmpty) {
                          _snack('Kart kodu gerekli', Colors.red);
                          return;
                        }
                        Navigator.pop(ctx);
                        
                        setState(() => _loading = true);
                        final res = await _svc.addCard(
                          userId: _user!.id,
                          cardCode: codeCtrl.text.trim(),
                          cardNickname: nickCtrl.text.trim().isEmpty
                              ? null
                              : nickCtrl.text.trim(),
                        );
                        setState(() => _loading = false);
                        
                        if (res['success']) {
                          await _refresh();
                          _snack('Kart eklendi ✅', const Color(0xFF4CAF50));
                        } else {
                          _snack(res['error'], Colors.red);
                        }
                      },
                      child: const Text('Ekle',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }


  void _showCardDetail(UserCard card) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0D47A1).withOpacity(0.93),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                children: [

                  Center(
                    child: Container(
                      width: 44, height: 5,
                      decoration: BoxDecoration(
                          color: Colors.white24, borderRadius: BorderRadius.circular(3))),
                  ),
                  const SizedBox(height: 20),


                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.blue.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8))
                      ],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.nfc, color: Colors.white60, size: 26),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('RFID',
                              style: TextStyle(color: Colors.white70, fontSize: 11,
                                  letterSpacing: 1.5)),
                        ),
                      ]),
                      const SizedBox(height: 18),
                      Text(card.cardCode,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13,
                              fontFamily: 'monospace', letterSpacing: 3)),
                      const SizedBox(height: 6),
                      Text(card.cardNickname,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 18),
                      Row(children: [
                        const Text('BAKİYE',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 11, letterSpacing: 2)),
                        const Spacer(),
                        Text('${card.balance.toStringAsFixed(2)} ₺',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                      ]),
                    ]),
                  ),

                  const SizedBox(height: 20),

                  Row(children: [
                    _statBox(Icons.calendar_today_outlined, 'Eklenme',
                        _formatDate(card.addedAt)),
                    const SizedBox(width: 12),
                    _statBox(Icons.access_time_rounded, 'Son Kullanım',
                        _formatDate(card.lastUsedAt)),
                  ]),

                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF42A5F5), 
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showIyzicoPayment(card);
                    },
                    icon: const Icon(Icons.payment, color: Colors.white, size: 22),
                    label: const Text('Bakiye Yükle (Kart ile Ödeme)',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  ),

                  const SizedBox(height: 20),

                  Row(children: [
                    const Icon(Icons.receipt_long_outlined, color: Colors.white54, size: 16),
                    const SizedBox(width: 8),
                    const Text('Son İşlemler',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 10),

                  FutureBuilder<List<dynamic>>(
                    future: _svc.getCardHistory(card.cardCode),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(color: Colors.white54),
                          ),
                        );
                      }
                      
                      final logs = snapshot.data!;
                      if (logs.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text('Henüz işlem yok',
                              style: TextStyle(color: Colors.white30),
                              textAlign: TextAlign.center),
                        );
                      }
                      
                      return Column(
                        children: logs.map((t) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Row(children: [
                            Icon(
                              t['Amount'] < 0 ? Icons.arrow_downward : Icons.arrow_upward,
                              color: t['Amount'] < 0 ? Colors.redAccent : const Color(0xFF4CAF50),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t['Description'],
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 2),
                                  Text(t['CreatedAt'].toString().substring(0, 16),
                                      style: const TextStyle(color: Colors.white30, fontSize: 11)),
                                ],
                              ),
                            ),
                            Text('${t['Amount']} ₺',
                                style: TextStyle(
                                    color: t['Amount'] < 0 ? Colors.redAccent : const Color(0xFF4CAF50),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                          ]),
                        )).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            backgroundColor: const Color(0xFF1A237E),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            title: const Text('Kartı Sil',
                                style: TextStyle(color: Colors.white)),
                            content: Text(
                                '"${card.cardNickname}" kartını silmek istediğinizden emin misiniz?',
                                style: const TextStyle(color: Colors.white70)),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('İptal',
                                      style: TextStyle(color: Colors.white54))),
                              ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade400),
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Sil',
                                      style: TextStyle(color: Colors.white))),
                            ],
                          ),
                        );
                        
                        if (confirm == true) {
                          setState(() => _loading = true);
                          final res = await _svc.deleteCard(
                              cardId: card.id, userId: _user!.id);
                          setState(() => _loading = false);
                          
                          if (res['success']) {
                            await _refresh();
                            _snack('Kart silindi ✅', Colors.orange);
                          } else {
                            _snack(res['error'], Colors.red);
                          }
                        }
                      },
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 18),
                      label: const Text('Kartı Kaldır',
                          style: TextStyle(color: Colors.redAccent)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  Widget _statBox(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: Colors.white38, size: 16),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year}';
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Widget _glassField(TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      keyboardType: hint.contains('Tutar') ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
        prefixIcon: Icon(icon, color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.2))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
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
        child: SafeArea(child: _user == null ? _buildGuest() : _buildProfile()),
      ),
    );
  }
  Widget _buildGuest() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Text('Profil',
              style: TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1)),
          child: const Icon(Icons.person_outline_rounded,
              size: 80, color: Colors.white54),
        ),
        const SizedBox(height: 20),
        const Text('Henüz giriş yapmadınız',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Kartlarınızı yönetmek için giriş yapın',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
            textAlign: TextAlign.center),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF42A5F5), 
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
            onPressed: _openLogin,
            icon: const Icon(Icons.login, color: Colors.white),
            label: const Text('Giriş Yap / Kayıt Ol',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
        ),
        const Spacer(),
      ]),
    );
  }


  Widget _buildProfile() {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: const Color(0xFF42A5F5),
      backgroundColor: const Color(0xFF1A237E),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            const Expanded(
              child: Text('Profilim',
                  style: TextStyle(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            if (_loading)
              const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)),
          ]),

          const SizedBox(height: 20),

          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: Row(children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)]),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _user!.fullName.isNotEmpty
                            ? _user!.fullName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(_user!.fullName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(_user!.email,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.65),
                                fontSize: 13)),
                        if (_user!.phoneNumber != null) ...[
                          const SizedBox(height: 3),
                          Text(_user!.phoneNumber!,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 12)),
                        ],
                      ])),
                ]),
              ),
            ),
          ),

          const SizedBox(height: 24),
          Row(children: [
            const Icon(Icons.credit_card, color: Colors.white70, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Kartlarım',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
            ),
            GestureDetector(
              onTap: _showAddCardDialog,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.add, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('Kart Ekle',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),

          const SizedBox(height: 14),

          if (_user!.cards.isEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Column(children: [
                    Icon(Icons.nfc,
                        color: Colors.white.withOpacity(0.3), size: 48),
                    const SizedBox(height: 12),
                    Text('Henüz kart eklenmedi',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 14)),
                    const SizedBox(height: 6),
                    Text('RFID kart kodunuzu ekleyerek başlayın',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 12),
                        textAlign: TextAlign.center),
                  ]),
                ),
              ),
            )
          else
            ..._user!.cards.map((card) => GestureDetector(
                  onTap: () => _showCardDetail(card),
                  child: _buildCardTile(card),
                )),

          const SizedBox(height: 32),
          GestureDetector(
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
              builder: (ctx) => Dialog(
  backgroundColor: Colors.transparent,
  child: ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1565C0).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withOpacity(0.2),
                border: Border.all(
                  color: Colors.redAccent.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Colors.redAccent,
                size: 36,
              ),
            ),
            
            const SizedBox(height: 20),
            
 
            const Text(
              'Çıkış Yap',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            
            const SizedBox(height: 12),
            
     
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Hesabınızdan çıkış yapmak istediğinizden emin misiniz?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
          
            Row(
              children: [
            
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text(
                      'İptal',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE53935), Color(0xFFC62828)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text(
                        'Çıkış Yap',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  ),
),
              );
              if (confirm == true) await _logout();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withOpacity(0.35)),
              ),
              child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded,
                        color: Colors.redAccent, size: 20),
                    SizedBox(width: 8),
                    Text('Çıkış Yap',
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600)),
                  ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardTile(UserCard card) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.18),
                    Colors.white.withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Row(children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.credit_card_rounded,
                    color: Colors.lightBlueAccent, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(card.cardNickname,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(card.cardCode,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                            fontFamily: 'monospace',
                            letterSpacing: 1)),
                  ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${card.balance.toStringAsFixed(2)} ₺',
                    style: const TextStyle(
                        color: Colors.lightBlueAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const Text('Bakiye',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
              ]),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white30, size: 20),
            ]),
          ),
        ),
      ),
    );
  }
}

class IyzicoPaymentForm extends StatefulWidget {
  final String cardCode;
  final String userEmail;
  final String userName;
  final Function(double) onPaymentSuccess;
  final Function(String) onPaymentError;

  const IyzicoPaymentForm({
    super.key,
    required this.cardCode,
    required this.userEmail,
    required this.userName,
    required this.onPaymentSuccess,
    required this.onPaymentError,
  });

  @override
  State<IyzicoPaymentForm> createState() => _IyzicoPaymentFormState();
}

class _IyzicoPaymentFormState extends State<IyzicoPaymentForm> {
  final _amountCtrl = TextEditingController(text: '50');
  final _cardNumberCtrl = TextEditingController(text: '5528790000000008'); 
  final _expMonthCtrl = TextEditingController(text: '12');
  final _expYearCtrl = TextEditingController(text: '30');
  final _cvvCtrl = TextEditingController(text: '123');
  final _nameCtrl = TextEditingController(text: 'Test User');

  final _svc = UserAuthService();
  bool _loading = false;
  final _amounts = [20.0, 50.0, 100.0, 200.0];

  Future<void> _processPayment() async {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (amount <= 0) {
      widget.onPaymentError('⚠️ Geçerli bir tutar girin');
      return;
    }


    if (amount < 10) {
      widget.onPaymentError('⚠️ Minimum yükleme tutarı 10₺');
      return;
    }


    final cardNum = _cardNumberCtrl.text.replaceAll(' ', '');
    if (cardNum.length < 15) {
      widget.onPaymentError('⚠️ Geçersiz kart numarası');
      return;
    }

    if (_expMonthCtrl.text.isEmpty || int.tryParse(_expMonthCtrl.text) == null) {
      widget.onPaymentError('⚠️ Geçersiz ay bilgisi');
      return;
    }

    final month = int.parse(_expMonthCtrl.text);
    if (month < 1 || month > 12) {
      widget.onPaymentError('⚠️ Ay bilgisi 1-12 arasında olmalı');
      return;
    }

    if (_expYearCtrl.text.isEmpty || _expYearCtrl.text.length != 2) {
      widget.onPaymentError('⚠️ Geçersiz yıl bilgisi (örn: 30)');
      return;
    }

    if (_cvvCtrl.text.length < 3) {
      widget.onPaymentError('⚠️ CVV 3 haneli olmalı');
      return;
    }

    if (_nameCtrl.text.trim().isEmpty) {
      widget.onPaymentError('⚠️ Kart sahibi adı gerekli');
      return;
    }

    setState(() => _loading = true);

    try {
      print('💳 Ödeme işlemi başlatılıyor...');
      print('💳 Tutar: $amount TL');
      print('💳 Kart: ${cardNum.substring(0, 4)}****${cardNum.substring(cardNum.length - 4)}');

      final paymentRes = await _svc.processIyzicoPaymentWithCard(
        cardCode: widget.cardCode,
        amount: amount,
        userEmail: widget.userEmail,
        userName: widget.userName,
        cardNumber: _cardNumberCtrl.text,
        cardHolder: _nameCtrl.text,
        expMonth: _expMonthCtrl.text,
        expYear: _expYearCtrl.text,
        cvv: _cvvCtrl.text,
      );

      setState(() => _loading = false);

      if (paymentRes['success']) {
        print('✅ Ödeme başarılı!');
        widget.onPaymentSuccess(amount);
      } else {
        final errorMsg = paymentRes['error'] ?? 'Ödeme başarısız oldu';
        print('❌ Ödeme hatası: $errorMsg');
        widget.onPaymentError(errorMsg);
      }
    } catch (e) {
      setState(() => _loading = false);
      print('❌ İstisnai hata: $e');
      widget.onPaymentError('Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.payment, color: Colors.white70, size: 24),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Güvenli Ödeme',
                    style: TextStyle(
                        color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              ),
            ]),

            const SizedBox(height: 8),
            Text('Kartınıza ${widget.cardCode} bakiye yükleyin',
                style: const TextStyle(color: Colors.white54, fontSize: 13)),

            const SizedBox(height: 24),

            const Text('Yüklenecek Tutar',
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _amounts.map((amt) {
                final isSelected = _amountCtrl.text == amt.toString();
                return GestureDetector(
                  onTap: () => setState(() => _amountCtrl.text = amt.toString()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFF42A5F5), Color(0xFF1E88E5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isSelected ? null : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF42A5F5)
                            : Colors.white.withOpacity(0.2),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      '${amt.toInt()} ₺',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.attach_money, color: Colors.white54),
                hintText: 'Özel tutar girin',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white, width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Text('Kart Bilgileri',
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: Column(children: [
                _buildPaymentField(_cardNumberCtrl, 'Kart Numarası', Icons.credit_card,
                    TextInputType.number, '5528 7900 0000 0008'),
                const SizedBox(height: 12),
                _buildPaymentField(_nameCtrl, 'Kart Sahibi', Icons.person_outline,
                    TextInputType.text, 'AD SOYAD'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: _buildPaymentField(_expMonthCtrl, 'Ay', Icons.calendar_today,
                        TextInputType.number, '12'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPaymentField(_expYearCtrl, 'Yıl', Icons.calendar_today,
                        TextInputType.number, '30'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPaymentField(_cvvCtrl, 'CVV', Icons.lock_outline,
                        TextInputType.number, '123'),
                  ),
                ]),
              ]),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Test modunda çalışıyor. Yukarıdaki kart bilgileri test içindir.',
                    style: TextStyle(color: Colors.amber.shade200, fontSize: 12),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF42A5F5), 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
                onPressed: _loading ? null : _processPayment,
                child: _loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '${_amountCtrl.text} ₺ Öde',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_user, color: Colors.white.withOpacity(0.4), size: 14),
                const SizedBox(width: 6),
                Text(
                  '256-bit SSL ile güvenli ödeme',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentField(TextEditingController ctrl, String label, IconData icon,
      TextInputType type, String hint) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white54),
        ),
      ),
    );
  }
}