import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../providers/app_mode_provider.dart';
import '../../providers/assistant_state_provider.dart';
import '../../services/limit_service.dart';
import '../../services/notification_handler.dart';
import '../../routes.dart';
import '../login_screen.dart';
import 'notification_guide_screen.dart';
import 'instruction_guide_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _userName = 'Pengguna';
  String _userEmail = '';
  bool _isPremium = false;
  String _appVersion = '1.0.0';
  bool _notificationsEnabled = true;
  bool _isKeyboardEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadAppInfo();
    _loadKeyboardState();
  }

  Future<void> _loadKeyboardState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isKeyboardEnabled = prefs.getBool('keyboard_enabled') ?? false;
      });
    }
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          _userName = user.displayName ?? user.email?.split('@').first ?? 'Pengguna';
          _userEmail = user.email ?? '';
        });
      }
    } catch (_) {}
    final premium = await LimitService.isPremium();
    if (mounted) setState(() => _isPremium = premium);
  }

  Future<void> _loadAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = packageInfo.version);
    } catch (_) {}
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Logout',
          style: TextStyle(color: Color(0xFF9B7EFF), fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Yakin ingin logout?',
          style: TextStyle(color: Color(0xFFCCCCCC)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Color(0xFFFF5252))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_logged_in');
      if (mounted) {
        Navigator.pushReplacement(context, buildFadeSlideRoute(LoginScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appMode = context.watch<AppModeProvider>();
    final assistant = context.watch<AssistantActiveProvider>();

    return Scaffold(
      backgroundColor: appMode.bgColor,
      appBar: AppBar(
        backgroundColor: appMode.bgColor,
        title: Text(
          'Pengaturan',
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
          // Profile Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: appMode.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: appMode.cardBorderColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: appMode.primaryColor.withOpacity(0.2),
                  child: Icon(Icons.person, color: appMode.accentColor, size: 36),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userName,
                        style: TextStyle(
                          color: appMode.headerTextColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _userEmail,
                        style: TextStyle(
                          color: appMode.textColor.withOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _isPremium
                              ? const Color(0xFF00FFAA).withOpacity(0.15)
                              : appMode.textColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _isPremium ? 'Premium' : 'Free',
                          style: TextStyle(
                            color: _isPremium
                                ? const Color(0xFF00FFAA)
                                : appMode.textColor.withOpacity(0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // AI Mode Toggle
          _buildSectionTitle('Mode AI', appMode),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: appMode.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: appMode.cardBorderColor.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => appMode.setOffline(false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !appMode.isOffline
                                ? const Color(0xFF6B4EFF).withOpacity(0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: !appMode.isOffline
                                  ? const Color(0xFF6B4EFF).withOpacity(0.5)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.public,
                                size: 16,
                                color: !appMode.isOffline
                                    ? const Color(0xFF6B4EFF)
                                    : appMode.textColor.withOpacity(0.4),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Online',
                                style: TextStyle(
                                  color: !appMode.isOffline
                                      ? const Color(0xFF6B4EFF)
                                      : appMode.textColor.withOpacity(0.4),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => appMode.setOffline(true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: appMode.isOffline
                                ? const Color(0xFF00CC88).withOpacity(0.2)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: appMode.isOffline
                                  ? const Color(0xFF00CC88).withOpacity(0.5)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock,
                                size: 16,
                                color: appMode.isOffline
                                    ? const Color(0xFF00CC88)
                                    : appMode.textColor.withOpacity(0.4),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Offline',
                                style: TextStyle(
                                  color: appMode.isOffline
                                      ? const Color(0xFF00CC88)
                                      : appMode.textColor.withOpacity(0.4),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  appMode.isOffline
                      ? 'AI berjalan secara lokal di perangkat Anda'
                      : 'Terhubung ke DeepSeek untuk jawaban lebih akurat',
                  style: TextStyle(
                    color: appMode.textColor.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Asisten Aktif Section ──
          _buildSectionTitle('Asisten Aktif', appMode),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: appMode.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: appMode.cardBorderColor.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    'Aktifkan Asisten Aktif',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Robot selalu siap mendengarkan perintah suara "Halo Winatra"',
                    style: TextStyle(
                      color: appMode.textColor.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                  value: assistant.isActive,
                  activeColor: const Color(0xFF6B4EFF),
                  onChanged: (val) async {
                    await context.read<AssistantActiveProvider>().setActive(val);
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                if (assistant.isActive) ...[
                  const Divider(color: Color(0xFF333355), height: 1, indent: 16, endIndent: 16),
                  SwitchListTile(
                    title: const Text(
                      'Suara Aktif',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    subtitle: Text(
                      'Aktifkan input suara (STT) dan output suara (TTS)',
                      style: TextStyle(
                        color: appMode.textColor.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                    value: assistant.isVoiceEnabled,
                    activeColor: const Color(0xFF6B4EFF),
                    onChanged: (val) async {
                      await context.read<AssistantActiveProvider>().setVoiceEnabled(val);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(color: Color(0xFF333355), height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: Icon(Icons.menu_book_outlined, color: appMode.accentColor, size: 22),
                    title: Text(
                      'Panduan Instruksi',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    subtitle: Text(
                      'Cara memberi perintah yang benar',
                      style: TextStyle(
                        color: appMode.textColor.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                    trailing: Icon(Icons.chevron_right, color: appMode.textColor.withOpacity(0.5)),
                  onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const InstructionGuideScreen()),
                      );
                    },
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  const Divider(color: Color(0xFF333355), height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: Icon(Icons.visibility, color: appMode.accentColor, size: 22),
                    title: Text(
                      'Tampilkan Robot',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    subtitle: Text(
                      assistant.isRobotHidden
                          ? 'Robot sedang disembunyikan. Tap untuk menampilkan.'
                          : 'Robot sedang terlihat di layar.',
                      style: TextStyle(
                        color: appMode.textColor.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                    trailing: Icon(Icons.chevron_right, color: appMode.textColor.withOpacity(0.5)),
                    onTap: () async {
                      await context.read<AssistantActiveProvider>().showRobot();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Robot akan ditampilkan'),
                            backgroundColor: Color(0xFF6B4EFF),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Notifications Section
          _buildSectionTitle('Notifikasi', appMode),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: appMode.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: appMode.cardBorderColor.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    'Aktifkan Notifikasi',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Terima notifikasi jawaban AI',
                    style: TextStyle(
                      color: appMode.textColor.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                  value: _notificationsEnabled,
                  activeColor: const Color(0xFF6B4EFF),
                  onChanged: (val) {
                    setState(() => _notificationsEnabled = val);
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(color: Color(0xFF333355), height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.help_outline, color: appMode.accentColor, size: 22),
                  title: Text(
                    'Panduan Notifikasi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right, color: appMode.textColor.withOpacity(0.5)),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationGuideScreen()),
                    );
                  },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Keyboard Winatra Toggle
          _buildSectionTitle('Keyboard', appMode),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: appMode.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: appMode.cardBorderColor.withOpacity(0.2)),
            ),
            child: SwitchListTile(
              title: const Text(
                'Keyboard Winatra',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              subtitle: Text(
                'Aktifkan keyboard custom untuk akses cepat ke AI',
                style: TextStyle(
                  color: appMode.textColor.withOpacity(0.5),
                  fontSize: 11,
                ),
              ),
              value: _isKeyboardEnabled,
              activeColor: const Color(0xFF6B4EFF),
              onChanged: (value) async {
                if (value) {
                  // Cek apakah keyboard sudah enabled di sistem
                  final enabled = await NotificationHandler.isKeyboardEnabled();
                  if (!enabled) {
                    // Tampilkan dialog
                    final shouldOpen = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF1A1A2E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text(
                          'Aktifkan Keyboard',
                          style: TextStyle(color: Color(0xFF9B7EFF), fontWeight: FontWeight.bold),
                        ),
                        content: const Text(
                          'Keyboard Winatra belum diaktifkan di pengaturan sistem. Buka pengaturan keyboard sekarang?',
                          style: TextStyle(color: Color(0xFFCCCCCC)),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Nanti', style: TextStyle(color: Colors.white70)),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B4EFF)),
                            child: const Text('Buka Pengaturan', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (shouldOpen == true) {
                      await NotificationHandler.openKeyboardSettings();
                    }
                    // Toggle kembali ke off (karena belum aktif)
                    setState(() => _isKeyboardEnabled = false);
                  } else {
                    // Simpan state ke SharedPreferences
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('keyboard_enabled', true);
                    setState(() => _isKeyboardEnabled = true);
                  }
                } else {
                  // Nonaktifkan (hanya simpan state)
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('keyboard_enabled', false);
                  setState(() => _isKeyboardEnabled = false);
                }
              },
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 20),

          // About Section
          _buildSectionTitle('Tentang Aplikasi', appMode),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: appMode.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: appMode.cardBorderColor.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                _buildInfoRow('Versi', 'v$_appVersion', appMode),
                const Divider(color: Color(0xFF333355), height: 20),
                _buildInfoRow('Kontak', 'support@winatra.ai', appMode),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Logout Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Color(0xFFFF5252)),
              label: const Text(
                'Logout',
                style: TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Color(0xFFFF5252).withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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

  Widget _buildInfoRow(String label, String value, AppModeProvider appMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: appMode.textColor.withOpacity(0.7),
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}