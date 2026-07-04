import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A speech bubble widget for the Winatra robot character.
/// Displays random funny messages, pantun, proverbs, and small talk
/// to entertain users while waiting for downloads.
class RobotSpeechBubble extends StatefulWidget {
  final Color bubbleColor;
  final Color textColor;
  final Color accentColor;
  final Duration messageInterval;

  const RobotSpeechBubble({
    super.key,
    this.bubbleColor = const Color(0xFF2A2A3E),
    this.textColor = Colors.white,
    this.accentColor = const Color(0xFF6B4EFF),
    this.messageInterval = const Duration(seconds: 6),
  });

  @override
  State<RobotSpeechBubble> createState() => _RobotSpeechBubbleState();
}

class _RobotSpeechBubbleState extends State<RobotSpeechBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  String _currentMessage = '';
  int _currentIndex = 0;
  final _random = math.Random();

  static const List<String> _messages = [
    // ── Pantun ──
    'Pergi ke pasar beli pepaya,\njangan lupa bawa keranjang.\nSabarr ya, lagi didownload nih,\nbiar nanti makin semangat belajar! 📚',
    'Ada bebek di sawah,\nberenang sambil cari ikan.\nModel AI-nya lagi diunduh,\nsabar ya, jangan keburu panikan! 🦆',
    'Jalan-jalan ke kota Gading,\njangan lupa bawa oleh-oleh.\nProses download masih berjalan,\ninsyaAllah sebentar lagi selesai, hehe~ 🎯',
    'Beli mangga di pasar baru,\ndibungkus pakai daun pisang.\nTenang aja, ini bukan karet,\nmodelnya turun pelan-pelan, yang sabar ya! 🥭',
    'Naik delman ke Cilacap,\njangan lupa mampir ke Curug.\nDownload-nya masih nyicil,\nbiar nanti jawabannya nggak rugi~ 🚃',

    // ── Basa-basi & Hiburan ──
    'Sabarr bosque... good things take time! ⏳',
    'Lebih cepat dari kura-kura naik skuter! 🐢🛴',
    'Lagi ngunduh ilmu nih... sabar dikit ya! 🧠',
    'Ada ayam, ada bebek, downloadnya sabar dikit dikit, hehe 🐔',
    'Model AI-nya lagi jalan-jalan dulu, bentar lagi balik 🚶‍♂️',
    'Yang sabar ya, ini lebih cepet dari matiin lampu terus nyalain lagi 💡',
    'Proses 99%... eh cuma 2% 😅 sabar ya!',
    'Lagi ambil napas dulu... modelnya berat soalnya 😤',
    'Jangan ditutup-tutup, nanti modelnya nyasar lho! 🗺️',
    'Hitung mundur: 3... 2... 1... eh masih loading 😂',

    // ── Pepatah & Motivasi ──
    'Sabar itu pahit, tapi hasilnya manis kayak AI ini 🍯',
    'Alah bisa karena biasa, AI bisa karena belajar dari data 📖',
    'Sedikit-sedikit, lama-lama jadi bukit... modelnya juga gitu 🏔️',
    'Bersakit-sakit dahulu, bersenang-senang kemudian... chat AI puas! 🎉',
    'Tak ada rotan, akar pun jadi... yang penting AI-nya jalan! 🌿',

    // ── Ngajak Ngobrol ──
    'Eh, kamu suka mie ayam? Aku suka ngolah data! 🍜',
    'Coba tebak, warna kesukaan aku apa? Ungu dong, soalnya AI-licious! 💜',
    'Kalau lagi nunggu, biasanya kamu ngapain? Aku sih ngitung byte~ 🔢',
    'Fun fact: aku bisa baca 512 karakter per detik! Cepet kan? ⚡',
    'Kamu tau nggak? Aku ini robot, tapi hati aku pake kode etik! 🤖❤️',
    'Hari ini belajar apa aja? Cerita dong, aku dengerin! 👂',
    'Kalau aku jadi manusia, aku pengen jadi guru... soalnya suka ngajar AI! 👨‍🏫',
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _currentMessage = _messages[_random.nextInt(_messages.length)];
    _fadeController.value = 1.0;
    _startMessageRotation();
  }

  void _startMessageRotation() {
    Future.delayed(widget.messageInterval, () {
      if (!mounted) return;
      _fadeController.reverse().then((_) {
        if (!mounted) return;
        setState(() {
          _currentIndex = _random.nextInt(_messages.length);
          _currentMessage = _messages[_currentIndex];
        });
        _fadeController.forward();
      });
      _startMessageRotation();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Speech bubble body
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: widget.bubbleColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.accentColor.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.accentColor.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                _currentMessage,
                style: TextStyle(
                  color: widget.textColor.withOpacity(0.95),
                  fontSize: 12,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Speech bubble tail (pointing down-left)
            Positioned(
              left: 20,
              bottom: -8,
              child: ClipPath(
                clipper: _BubbleTailClipper(),
                child: Container(
                  width: 16,
                  height: 10,
                  decoration: BoxDecoration(
                    color: widget.bubbleColor,
                    border: Border(
                      left: BorderSide(
                        color: widget.accentColor.withOpacity(0.3),
                        width: 1.5,
                      ),
                      bottom: BorderSide(
                        color: widget.accentColor.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BubbleTailClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_BubbleTailClipper old) => false;
}