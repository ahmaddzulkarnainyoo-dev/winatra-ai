import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/app_mode_provider.dart';
import '../../providers/brain_provider.dart';
import '../../services/limit_service.dart';
import '../../services/chat_history_service.dart';
import '../../models/app_feature.dart';
import '../../routes.dart';
import '../notification_mode_screen.dart';
import '../keyboard_mode_screen.dart';
import '../chat_room_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _userName = 'Pengguna';
  String _userEmail = '';
  bool _isPremium = false;
  int _remainingQuota = 0;
  List<Map<String, String>> _recentChats = [];

  /// Status enabled untuk tiap fitur (di-cache di state)
  Map<String, bool> _featureEnabled = {};

  late final List<AppFeature> _features;

  @override
  void initState() {
    super.initState();
    _features = _buildFeatures();
    _loadUserData();
    _loadQuota();
    _loadRecentChats();
    _loadAllFeatureStates();
  }

  List<AppFeature> _buildFeatures() {
    return [
      AppFeature(
        id: 'notification',
        name: 'Mode Notifikasi',
        description: 'AI di notifikasi — copy teks lalu tekan Jawab. Essay (auto-copy) atau PG (pop-up + tombol Kenapa?).',
        icon: Icons.notifications_active,
        detailPage: (_) => const NotificationModeScreen(currentMode: 'Essay'),
      ),
      AppFeature(
        id: 'keyboard',
        name: 'Mode Keyboard',
        description: 'Keyboard AI dengan 3 tab: Ketik, Tanya AI, Baca. Tanpa copy-paste. Bisa di semua aplikasi.',
        icon: Icons.keyboard,
        detailPage: (_) => const KeyboardModeScreen(),
      ),
    ];
  }

  Future<void> _loadAllFeatureStates() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, bool>{};
    for (final f in _features) {
      map[f.id] = prefs.getBool(f.prefsKey) ?? true;
    }
    if (mounted) setState(() => _featureEnabled = map);
  }

  Future<void> _toggleFeature(AppFeature feature, bool value) async {
    await feature.setEnabled(value);
    if (mounted) {
      setState(() => _featureEnabled[feature.id] = value);
    }

    const platform = MethodChannel('winatra/service');
    switch (feature.id) {
      case 'notification':
        try {
          if (value) {
            await platform.invokeMethod('startService');
          } else {
            await platform.invokeMethod('stopService');
            await platform.invokeMethod('cancelNotification');
          }
        } catch (_) {}
        break;
      case 'keyboard':
        if (!value) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Keyboard Winatra dinonaktifkan.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Keyboard Winatra diaktifkan.')),
          );
        }
        break;
    }
  }

  void _openFeatureDetail(AppFeature feature) {
    Navigator.push(context, buildFadeSlideRoute(feature.detailPage(context)));
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

  Future<void> _loadQuota() async {
    final remaining = await LimitService.getRemainingQuota();
    if (mounted) setState(() => _remainingQuota = remaining);
  }

  void _loadRecentChats() {
    final messages = ChatHistoryService.loadMessages();
    if (messages.isNotEmpty) {
      final recent = <String, Map<String, String>>{};
      for (final msg in messages.reversed) {
        if (msg['sender'] == 'user') {
          final key = msg['text'] ?? '';
          if (key.length > 60) {
            recent[key.substring(0, 60)] = {'text': key, 'sender': 'user'};
          } else {
            recent[key] = {'text': key, 'sender': 'user'};
          }
          if (recent.length >= 3) break;
        }
      }
      setState(() => _recentChats = recent.values.toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final appMode = context.watch<AppModeProvider>();
    final brainProvider = context.watch<BrainProvider>();
    final recentDocs = brainProvider.documents.take(3).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── HEADER ──
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: appMode.primaryColor.withOpacity(0.2),
                child: Icon(Icons.person, color: appMode.accentColor, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Halo, $_userName',
                      style: TextStyle(
                        color: appMode.headerTextColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _isPremium ? 'Premium Aktif' : 'Akun Free',
                      style: TextStyle(
                        color: _isPremium
                            ? const Color(0xFF00FFAA)
                            : appMode.textColor.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── AI MODE CARD ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: appMode.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: appMode.isOffline
                    ? const Color(0xFF00CC88).withOpacity(0.5)
                    : appMode.cardBorderColor,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  appMode.isOffline ? Icons.lock : Icons.public,
                  color: appMode.isOffline
                      ? const Color(0xFF00CC88)
                      : appMode.accentColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appMode.isOffline ? 'Mode Offline' : 'Mode Online',
                        style: TextStyle(
                          color: appMode.isOffline
                              ? const Color(0xFF00CC88)
                              : appMode.accentColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        appMode.isOffline
                            ? 'AI berjalan di perangkat Anda'
                            : 'Terhubung ke DeepSeek',
                        style: TextStyle(
                          color: appMode.textColor.withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: appMode.isOffline
                        ? const Color(0xFF00CC88)
                        : const Color(0xFF6B4EFF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── QUOTA CARD ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: appMode.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: appMode.cardBorderColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: appMode.accentColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isPremium ? 'Premium Unlimited' : 'Sisa Tanya Hari Ini',
                        style: TextStyle(
                          color: appMode.headerTextColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _isPremium
                            ? 'Nikmati semua fitur tanpa batas'
                            : '$_remainingQuota pertanyaan tersisa',
                        style: TextStyle(
                          color: appMode.textColor.withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isPremium)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B4EFF).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Upgrade',
                      style: TextStyle(
                        color: Color(0xFF6B4EFF),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── FITUR AKTIF ──
          Row(
            children: [
              Icon(Icons.toggle_on, color: appMode.accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Fitur Aktif',
                style: TextStyle(
                  color: appMode.headerTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._features.map((feature) => _buildFeatureCard(
            context: context,
            feature: feature,
            appMode: appMode,
          )),
          const SizedBox(height: 24),

          // ── RECENT DOCUMENTS ──
          if (recentDocs.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.folder, color: appMode.accentColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Materi Terbaru',
                  style: TextStyle(
                    color: appMode.headerTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...recentDocs.map((doc) => _buildRecentDocCard(doc, appMode)),
            const SizedBox(height: 24),
          ],

          // ── RECENT CHATS ──
          if (_recentChats.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.chat_bubble_outline, color: appMode.accentColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Chat Terakhir',
                  style: TextStyle(
                    color: appMode.headerTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._recentChats.map((chat) => _buildRecentChatCard(chat, appMode)),
            const SizedBox(height: 24),
          ],

          // ── QUICK ACTIONS ──
          Text(
            'Aksi Cepat',
            style: TextStyle(
              color: appMode.headerTextColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  context: context,
                  icon: Icons.add,
                  label: 'Tambah Materi',
                  color: const Color(0xFF6B4EFF),
                  onTap: () {
                    // Navigate to Brain tab (index 1)
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  context: context,
                  icon: Icons.chat,
                  label: 'Chat Sekarang',
                  color: const Color(0xFF00CC88),
                  onTap: () {
                    // Navigate to Chat tab (index 2)
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required BuildContext context,
    required AppFeature feature,
    required AppModeProvider appMode,
  }) {
    final isEnabled = _featureEnabled[feature.id] ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: appMode.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEnabled
              ? appMode.cardBorderColor
              : appMode.cardBorderColor.withOpacity(0.2),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openFeatureDetail(feature),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isEnabled
                      ? appMode.primaryColor.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isEnabled
                        ? appMode.cardBorderColor.withOpacity(0.3)
                        : appMode.cardBorderColor.withOpacity(0.1),
                  ),
                ),
                child: Icon(
                  feature.icon,
                  color: isEnabled ? appMode.accentColor : appMode.textColor.withOpacity(0.3),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isEnabled ? Colors.white : appMode.textColor.withOpacity(0.4),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      feature.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: isEnabled
                            ? appMode.textColor.withOpacity(0.7)
                            : appMode.textColor.withOpacity(0.3),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Toggle switch
              Switch(
                value: isEnabled,
                onChanged: (val) => _toggleFeature(feature, val),
                activeColor: appMode.accentColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentDocCard(Map<String, dynamic> doc, AppModeProvider appMode) {
    final name = doc['name'] as String? ?? 'Unknown';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appMode.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appMode.cardBorderColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.description, color: appMode.accentColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: appMode.accentColor, size: 14),
        ],
      ),
    );
  }

  Widget _buildRecentChatCard(Map<String, String> chat, AppModeProvider appMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appMode.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appMode.cardBorderColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.chat_bubble_outline, color: appMode.accentColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              chat['text'] ?? '',
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: appMode.accentColor, size: 14),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}