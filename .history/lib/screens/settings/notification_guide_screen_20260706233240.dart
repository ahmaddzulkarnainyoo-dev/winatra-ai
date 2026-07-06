import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_mode_provider.dart';

class NotificationGuideScreen extends StatelessWidget {
  const NotificationGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appMode = context.watch<AppModeProvider>();

    return Scaffold(
      backgroundColor: appMode.bgColor,
      appBar: AppBar(
        backgroundColor: appMode.bgColor,
        title: Text(
          'Panduan Notifikasi',
          style: TextStyle(
            color: appMode.headerTextColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── APA ITU NOTIFIKASI WINATRA ──
            _buildSection(
              appMode: appMode,
              icon: Icons.notifications_active,
              title: 'Apa itu Notifikasi Winatra?',
              content:
                  'Notifikasi Winatra adalah fitur yang memungkinkan Anda mengakses Winatra AI '
                  'kapan saja tanpa harus membuka aplikasi. Cukup salin teks pertanyaan, '
                  'dan Winatra akan memberikan jawaban langsung di notifikasi.\n\n'
                  'Fitur ini sangat berguna saat Anda belajar di aplikasi lain, membaca artikel, '
                  'atau mengerjakan tugas — tanpa perlu bolak-balik ke aplikasi Winatra.',
            ),
            const SizedBox(height: 20),

            // ── CARA KERJA ──
            _buildSection(
              appMode: appMode,
              icon: Icons.timeline,
              title: 'Cara Kerja',
              content:
                  '1. Aktifkan fitur Notifikasi di menu "Fitur Aktif" pada Beranda.\n'
                  '2. Salin teks pertanyaan (akhiri dengan tanda tanya "?").\n'
                  '3. Buka panel notifikasi, tekan tombol "Jawab".\n'
                  '4. Winatra akan menampilkan "Berpikir..." lalu memberikan jawaban.\n'
                  '5. Untuk mode Essay, jawaban otomatis disalin ke clipboard.\n'
                  '6. Untuk mode PG, jawaban ditampilkan dengan tombol "Kenapa?" untuk penjelasan.',
            ),
            const SizedBox(height: 20),

            // ── MODE AUTO-SOLVE ──
            _buildSection(
              appMode: appMode,
              icon: Icons.auto_awesome,
              title: 'Mode Auto-Solve',
              content:
                  'Dengan mode Auto-Solve ON, Winatra akan otomatis mendeteksi ketika Anda '
                  'menyalin teks yang berakhiran tanda tanya ("?"), lalu langsung memprosesnya.\n\n'
                  'Anda tidak perlu menekan tombol "Jawab" secara manual — semuanya otomatis!\n\n'
                  'Mode ini bisa diaktifkan/dinonaktifkan dari notifikasi persistent Winatra.',
            ),
            const SizedBox(height: 20),

            // ── MODE ESSAY VS PG ──
            _buildSection(
              appMode: appMode,
              icon: Icons.swap_horiz,
              title: 'Mode Essay vs PG',
              content:
                  '📝 Mode Essay:\n'
                  '- Jawaban berupa teks panjang dan lengkap.\n'
                  '- Jawaban otomatis disalin ke clipboard.\n'
                  '- Cocok untuk soal uraian, esai, atau pertanyaan terbuka.\n\n'
                  '❓ Mode PG (Pilihan Ganda):\n'
                  '- Jawaban hanya berupa huruf A, B, C, atau D.\n'
                  '- Ditampilkan di notifikasi dengan tombol "Kenapa?"\n'
                  '- Tombol "Kenapa?" akan memberikan penjelasan mengapa jawaban itu benar.\n'
                  '- Cocok untuk soal pilihan ganda.',
            ),
            const SizedBox(height: 20),

            // ── TOMBOL DI NOTIFIKASI ──
            _buildSection(
              appMode: appMode,
              icon: Icons.touch_app,
              title: 'Tombol di Notifikasi',
              content:
                  'Notifikasi persistent Winatra memiliki 3 tombol:\n\n'
                  '1. 🔄 Ganti Mode — Berganti antara mode Essay dan PG.\n'
                  '2. ❓ Jawab — Memproses teks yang sudah disalin di clipboard.\n'
                  '3. ✉️ Tanya — Sama seperti Jawab, untuk bertanya langsung.\n\n'
                  'Setelah jawaban muncul, Anda juga bisa:\n'
                  '- 📋 Salin — Menyalin jawaban ke clipboard.\n'
                  '- ❓ Kenapa? — (Mode PG) Mendapatkan penjelasan jawaban.',
            ),
            const SizedBox(height: 20),

            // ── TIPS ──
            _buildSection(
              appMode: appMode,
              icon: Icons.lightbulb_outline,
              title: 'Tips Penggunaan',
              content:
                  '💡 Pastikan teks yang disalin berakhiran tanda tanya ("?") '
                  'agar Auto-Solve mendeteksinya.\n\n'
                  '💡 Gunakan mode Essay untuk tugas menulis, mode PG untuk '
                  'latihan soal pilihan ganda.\n\n'
                  '💡 Jawaban bisa langsung disisipkan ke aplikasi lain '
                  'karena otomatis tersalin ke clipboard.\n\n'
                  '💡 Notifikasi bersifat persistent — tidak akan hilang '
                  'sampai Anda menutupnya secara manual.',
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required AppModeProvider appMode,
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appMode.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: appMode.cardBorderColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: appMode.accentColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: appMode.headerTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              color: appMode.textColor.withOpacity(0.85),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}