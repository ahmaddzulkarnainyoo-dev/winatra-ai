import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../routes.dart';
import '../widgets/animated_pressable.dart';
import 'notification_mode_screen.dart';
import 'keyboard_mode_screen.dart';
import 'offline_ai_screen.dart';
import 'support_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool offlineMode = false;

  @override
  void initState() {
    super.initState();
    _loadOfflineMode();
  }

  Future<void> _loadOfflineMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      offlineMode = prefs.getBool('offline_mode_enabled') ?? false;
    });
  }

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.push(context, buildFadeSlideRoute(page)).then((_) {
      // Refresh offline mode status when returning from another screen
      _loadOfflineMode();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Stack(
              children: [
                Column(
                  children: [
                    Image.asset('assets/logo.png', width: 100, height: 100, errorBuilder: (_, __, ___) => const Icon(Icons.error, color: Colors.red)),
                    const SizedBox(height: 12),
                    const Text('WINATRA AI', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF9B7EFF), letterSpacing: 4)),
                    const Text('AI Shortcut di Genggaman', style: TextStyle(fontSize: 16, color: Color(0xFF6B4EFF))),
                  ],
                ),
                if (offlineMode)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B4EFF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF9B7EFF), width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_off, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            '🔒 Offline',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF141426),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF6B4EFF)),
            ),
            child: const Text(
              'Winatra AI adalah aplikasi AI shortcut untuk belajar dan menjawab pertanyaan cepat langsung dari notifikasi atau keyboard. Gunakan fitur Keyboard, Notifikasi, dan AI Offline untuk pengalaman yang lebih nyaman.',
              style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 13),
              textAlign: TextAlign.justify,
            ),
          ),
          const SizedBox(height: 24),
          const Text('Mode Aktif', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF9B7EFF))),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context: context,
            title: 'Mode Notifikasi',
            description: 'AI di notifikasi — copy teks lalu tekan Jawab. Essay (auto-copy) atau PG (pop-up + tombol Kenapa?).',
            icon: Icons.notifications_active,
            onTap: () => _navigateTo(context, const NotificationModeScreen(currentMode: 'Essay')),
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context: context,
            title: 'Mode Keyboard',
            description: 'Keyboard AI dengan 3 tab: Ketik, Tanya AI, Baca. Tanpa copy-paste. Bisa di semua aplikasi.',
            icon: Icons.keyboard,
            onTap: () => _navigateTo(context, const KeyboardModeScreen()),
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context: context,
            title: 'AI Offline (Winatra Core)',
            description: 'Jalankan AI tanpa internet (dalam pengembangan). Nanti bisa upload materi sendiri.',
            icon: Icons.cloud_off,
            onTap: () => _navigateTo(context, const OfflineAIScreen()),
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                _socialButton('Instagram', '@winatraa__24', 'https://instagram.com/winatraa__24'),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _navigateTo(context, const SupportScreen()),
                  icon: const Icon(Icons.favorite, color: Colors.white),
                  label: const Text('Dukung Kami', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B4EFF)),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => _navigateTo(context, const SupportScreen()),
                  child: const Text('Tentang', style: TextStyle(color: Color(0xFF6B4EFF))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('Beta v0.1.0 | Open Source (segera)', style: TextStyle(color: Color(0xFF666699), fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return AnimatedPressable(
      onTap: onTap,
      child: Card(
        color: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF6B4EFF), width: 1)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF9B7EFF), size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(description, style: const TextStyle(fontSize: 12, color: Color(0xFFCCCCCC))),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Color(0xFF9B7EFF), size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _socialButton(String label, String username, String url) {
    return AnimatedPressable(
      onTap: () async {
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF6B4EFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF9999BB))),
            const SizedBox(width: 8),
            Text(username, style: const TextStyle(color: Color(0xFF9B7EFF), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}


