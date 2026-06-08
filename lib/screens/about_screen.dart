import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        title: const Text('Tentang Aplikasi'),
        backgroundColor: const Color(0xFF0D0D1A),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF9B7EFF)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: FlutterLogo(size: 80),
            ),
            const SizedBox(height: 24),
            const Text('Winatra AI', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            const Text('Versi 1.0.3', style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 24),
            const Text(
              'Winatra AI adalah aplikasi shortcut AI dengan notifikasi persistent dan keyboard custom. '
              'Dapat digunakan untuk membantu belajar, mengerjakan soal, diskusi, dan lain-lain.',
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const Text('© 2025 Winatra AI Team', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
