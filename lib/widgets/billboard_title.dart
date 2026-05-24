import 'dart:async';
import 'package:flutter/material.dart';

class BillboardTitle extends StatefulWidget {
  const BillboardTitle({super.key});

  @override
  State<BillboardTitle> createState() => _BillboardTitleState();
}

class _BillboardTitleState extends State<BillboardTitle> {
  int _index = 0;
  Timer? _timer;

  final List<String> _messages = [
    "Rota Öneri Sistemi",
    "Senin Şehrin, Senin Rehberin.",
    "Erzurum Büyükşehir Belediyesi",
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 3500), (timer) {
      if (mounted) {
        setState(() => _index = (_index + 1) % _messages.length);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            "assets/icons/erzbblogoformain.png",
            height: 28,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              transitionBuilder: (child, animation) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 1.0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutBack,
                )),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Text(
                _messages[_index],
                key: ValueKey(_messages[_index]),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'ProductSans',
                  color: Color(0xFF1A237E),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}