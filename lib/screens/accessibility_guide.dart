import 'package:flutter/material.dart';

class AccessibilityGuideScreen extends StatelessWidget {
  const AccessibilityGuideScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        title: const Text('Panduan Asisten Belajar', style: TextStyle(color: Color(0xFF9B7EFF))),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Apa itu Asisten Belajar?', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              'Asisten Belajar membantu Anda membaca teks dari aplikasi lain (browser, PDF, WhatsApp) lalu memberikan jawaban atau penjelasan AI melalui notifikasi.',
              style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 24),
            const Text('Cara aktivasi', style: TextStyle(color: Color(0xFF9B7EFF), fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _stepTile('1', 'Buka Settings → Accessibility → Winatra AI → Aktifkan.'),
            _stepTile('2', 'Kembali ke aplikasi dan pilih trigger Volume Up 2x.'),
            _stepTile('3', 'Buka aplikasi lain dan pilih teks materi atau soal.'),
            _stepTile('4', 'Tekan Volume Up 2x. Tunggu notifikasi jawaban AI.'),
            const SizedBox(height: 24),
            const Text('Cara menggunakan', style: TextStyle(color: Color(0xFF9B7EFF), fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('• Setelah aktif, buka aplikasi lain dan pilih teks soal.', style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 14, height: 1.5)),
            const Text('• Tekan volume up 2x untuk memicu pembacaan teks.', style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 14, height: 1.5)),
            const Text('• Tunggu notifikasi berisi jawaban. Ketuk notifikasi untuk membuka aplikasi jika tersedia.', style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 14, height: 1.5)),
            const SizedBox(height: 24),
            const Text('FAQ', style: TextStyle(color: Color(0xFF9B7EFF), fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _faqTile('Kenapa harus aktifkan aksesibilitas?', 'Aksesibilitas diperlukan agar Winatra AI dapat membaca teks dari aplikasi lain dan membantu Anda belajar tanpa copy-paste.'),
            _faqTile('Apakah data saya aman?', 'Winatra AI hanya membaca teks layar untuk membantu. Data tidak disimpan sebagai riwayat pribadi atau dikirim ke server tambahan selain proses AI.'),
            _faqTile('Bisakah dimatikan?', 'Ya. Matikan sementara dari aplikasi atau nonaktifkan layanan di pengaturan sistem kapan saja.'),
            const SizedBox(height: 40),
            const Text('Tip', style: TextStyle(color: Color(0xFF9B7EFF), fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('Jika teks tidak terbaca pada gambar, coba salin teks terlebih dahulu atau gunakan mode keyboard / notifikasi biasa.', style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 14, height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _stepTile(String step, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 14, backgroundColor: const Color(0xFF6B4EFF), child: Text(step, style: const TextStyle(color: Colors.white, fontSize: 14))),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 14, height: 1.5))),
        ],
      ),
    );
  }

  Widget _faqTile(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(answer, style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}
