import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        title: const Text('Dukung Kami', style: TextStyle(color: Color(0xFF9B7EFF))),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF9B7EFF)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('Bantu Kami Berbagi', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF9B7EFF))),
            const SizedBox(height: 16),
            const Text(
              'Donasi Anda akan kami salurkan sepenuhnya untuk membantu mereka yang membutuhkan.',
              style: TextStyle(fontSize: 14, color: Color(0xFFCCCCCC), height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Image.asset('assets/qris.png', width: 250, height: 250, errorBuilder: (_, __, ___) => const Icon(Icons.qr_code, color: Colors.white, size: 100)),
            const SizedBox(height: 24),
            const Text('Scan QR Code untuk Donasi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            const Text(
              'Setelah melakukan donasi, kirim bukti transfer ke Instagram @winatraa__24.\n\nKami akan mengunggah bukti penyaluran donasi secara transparan di Instagram agar Anda bisa melihat langsung dampak dari bantuan Anda.',
              style: TextStyle(fontSize: 13, color: Color(0xFFCCCCCC), height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                const url = 'https://www.instagram.com/winatraa__24?igsh=cHRlc3A5eTFyM3N2';
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.camera_alt, color: Colors.white),
              label: const Text('Follow Instagram', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B4EFF)),
            ),
            const SizedBox(height: 16),
            const Text('💝 Terima Kasih!', style: TextStyle(fontSize: 14, color: Color(0xFF6B4EFF), fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Setiap donasi, sekecil apa pun, sangat berarti.',
              style: TextStyle(fontSize: 12, color: Color(0xFF9999BB)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
