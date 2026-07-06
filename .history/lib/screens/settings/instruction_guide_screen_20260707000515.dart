import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_mode_provider.dart';

/// Panduan Instruksi - Guide for users on how to give proper voice commands.
class InstructionGuideScreen extends StatelessWidget {
  const InstructionGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appMode = context.watch<AppModeProvider>();

    return Scaffold(
      backgroundColor: appMode.bgColor,
      appBar: AppBar(
        backgroundColor: appMode.bgColor,
        title: Text(
          'Panduan Instruksi',
          style: TextStyle(
            color: appMode.headerTextColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: appMode.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF6B4EFF).withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.menu_book_rounded,
                  color: const Color(0xFF6B4EFF),
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'Cara Memberi Perintah ke Winatra',
                  style: TextStyle(
                    color: appMode.headerTextColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Gunakan perintah yang jelas dan spesifik agar Winatra bisa memahami dan menjalankan instruksi Anda dengan tepat.',
                  style: TextStyle(
                    color: appMode.textColor.withOpacity(0.7),
                    fontSize: 13,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section: Perintah Sederhana
          _buildSectionTitle('Perintah Sederhana', appMode),
          const SizedBox(height: 8),
          _buildCommandCard(
            appMode,
            [
              _CommandExample(
                icon: Icons.open_in_new,
                label: 'Buka Aplikasi',
                correct: '"Buka WhatsApp"',
                wrong: '"Tolong bukain WA ya"',
                note: 'Sebutkan nama aplikasi dengan jelas.',
              ),
              _CommandExample(
                icon: Icons.search,
                label: 'Cari di Internet',
                correct: '"Cari resep nasi goreng"',
                wrong: '"Cariin dong"',
                note: 'Sebutkan topik yang ingin dicari.',
              ),
              _CommandExample(
                icon: Icons.visibility_off,
                label: 'Sembunyikan Robot',
                correct: '"Sembunyikan robot"',
                wrong: '"Pergi"',
                note: 'Gunakan kata "sembunyikan" atau "hide".',
              ),
              _CommandExample(
                icon: Icons.visibility,
                label: 'Tampilkan Robot',
                correct: '"Tampilkan robot"',
                wrong: '"Mana robotnya?"',
                note: 'Gunakan kata "tampilkan" atau "show".',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Section: Perintah Kompleks
          _buildSectionTitle('Perintah Kompleks', appMode),
          const SizedBox(height: 8),
          _buildCommandCard(
            appMode,
            [
              _CommandExample(
                icon: Icons.school,
                label: 'Akses E-Learning',
                correct: '"Buka Google, cari elearning.ui.ac.id"',
                wrong: '"Buka e-learning"',
                note: 'Sebutkan URL atau nama platform dengan lengkap.',
              ),
              _CommandExample(
                icon: Icons.quiz,
                label: 'Tanya Soal',
                correct: '"Jawab soal: [copy soal]"',
                wrong: '"Tolong jawab"',
                note: 'Copy soal terlebih dahulu, lalu beri perintah.',
              ),
              _CommandExample(
                icon: Icons.info,
                label: 'Cari Informasi',
                correct: '"Cari ibu kota Indonesia"',
                wrong: '"Cari"',
                note: 'Sebutkan topik spesifik yang ingin diketahui.',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Section: Tips
          _buildSectionTitle('Tips & Trik', appMode),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: appMode.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00CC88).withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTipItem(
                  Icons.mic,
                  'Gunakan suara yang jelas dan tidak terlalu cepat.',
                  appMode,
                ),
                const SizedBox(height: 12),
                _buildTipItem(
                  Icons.hearing,
                  'Tunggu robot selesai berbicara sebelum memberi perintah baru.',
                  appMode,
                ),
                const SizedBox(height: 12),
                _buildTipItem(
                  Icons.replay,
                  'Jika perintah tidak dikenali, coba ulangi dengan kata yang berbeda.',
                  appMode,
                ),
                const SizedBox(height: 12),
                _buildTipItem(
                  Icons.settings_voice,
                  'Aktifkan "Suara Aktif" di Settings untuk pengalaman hands-free.',
                  appMode,
                ),
                const SizedBox(height: 12),
                _buildTipItem(
                  Icons.touch_app,
                  'Tap robot untuk memulai interaksi suara, tap lagi untuk membatalkan.',
                  appMode,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, AppModeProvider appMode) {
    return Text(
      title,
      style: TextStyle(
        color: appMode.headerTextColor,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildCommandCard(
    AppModeProvider appMode,
    List<_CommandExample> examples,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: appMode.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appMode.cardBorderColor.withOpacity(0.2)),
      ),
      child: Column(
        children: examples.map((example) {
          return _buildExampleItem(example, appMode);
        }).toList(),
      ),
    );
  }

  Widget _buildExampleItem(_CommandExample example, AppModeProvider appMode) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(example.icon, color: const Color(0xFF6B4EFF), size: 20),
              const SizedBox(width: 8),
              Text(
                example.label,
                style: TextStyle(
                  color: appMode.headerTextColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Correct example
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle,
                  color: const Color(0xFF00CC88), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '✅ ${example.correct}',
                  style: TextStyle(
                    color: const Color(0xFF00CC88),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Wrong example
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cancel,
                  color: const Color(0xFFFF5252), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '❌ ${example.wrong}',
                  style: TextStyle(
                    color: const Color(0xFFFF5252).withOpacity(0.8),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Note
          Text(
            '💡 ${example.note}',
            style: TextStyle(
              color: appMode.textColor.withOpacity(0.5),
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(IconData icon, String text, AppModeProvider appMode) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF00CC88), size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: appMode.textColor.withOpacity(0.8),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _CommandExample {
  final IconData icon;
  final String label;
  final String correct;
  final String wrong;
  final String note;

  const _CommandExample({
    required this.icon,
    required this.label,
    required this.correct,
    required this.wrong,
    required this.note,
  });
}