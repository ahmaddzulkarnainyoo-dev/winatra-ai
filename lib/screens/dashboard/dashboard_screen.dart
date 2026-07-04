import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/app_mode_provider.dart';
import '../../providers/brain_provider.dart';
import '../../services/limit_service.dart';
import '../../services/chat_history_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadQuota();
    _loadRecentChats();
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
          // Header
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

          // AI Mode Card
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
                            : 'Terhubung ke server Groq',
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

          // Quota Card
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

          // Recent Documents
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

          // Recent Chats
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

          // Quick Actions
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