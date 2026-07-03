import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../providers/app_mode_provider.dart';
import '../routes.dart';
import '../widgets/animated_pressable.dart';
import 'notification_mode_screen.dart';
import 'keyboard_mode_screen.dart';
import 'chat_room_screen.dart';
import 'support_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  void _navigateTo(BuildContext context, Widget page) {
    Navigator.push(context, buildFadeSlideRoute(page));
  }

  @override
  Widget build(BuildContext context) {
    final appMode = context.watch<AppModeProvider>();

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
                    Text(
                      'WINATRA AI',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: appMode.accentColor,
                        letterSpacing: 4,
                      ),
                    ),
                    Text(
                      'AI Shortcut di Genggaman',
                      style: TextStyle(
                        fontSize: 16,
                        color: appMode.primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── MODE BADGE ──
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: appMode.surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: appMode.isOffline
                      ? const Color(0xFF00CC88).withOpacity(0.5)
                      : appMode.cardBorderColor,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    appMode.isOffline ? Icons.lock : Icons.public,
                    size: 16,
                    color: appMode.isOffline
                        ? const Color(0xFF00CC88)
                        : appMode.accentColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    appMode.isOffline ? 'Mode Offline Aktif' : 'Mode Online',
                    style: TextStyle(
                      color: appMode.isOffline
                          ? const Color(0xFF00CC88)
                          : appMode.accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ── DESKRIPSI ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: appMode.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: appMode.cardBorderColor),
            ),
            child: Text(
              'Winatra AI adalah aplikasi AI shortcut untuk belajar dan menjawab pertanyaan cepat langsung dari notifikasi atau keyboard. Gunakan fitur Keyboard, Notifikasi, dan Bot Chat untuk pengalaman yang lebih nyaman.',
              style: TextStyle(
                color: appMode.textColor,
                fontSize: 13,
              ),
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
            title: 'Ngobrol Bareng Winatra',
            description: 'Chat dengan AI. Bisa online (Groq) atau offline (lokal). Upload materi untuk jawaban lebih akurat.',
            icon: Icons.chat_bubble,
            onTap: () => _navigateTo(context, const ChatRoomScreen()),
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
    final appMode = context.read<AppModeProvider>();
    return AnimatedPressable(
      onTap: onTap,
      child: Card(
        color: appMode.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: appMode.cardBorderColor, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: appMode.accentColor, size: 40),
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
              Icon(Icons.arrow_forward_ios, color: appMode.accentColor, size: 16),
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