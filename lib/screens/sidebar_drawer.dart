import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../providers/app_mode_provider.dart';
import '../services/limit_service.dart';
import '../widgets/glow_text.dart';

class SidebarDrawer extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const SidebarDrawer({
    Key? key,
    required this.selectedIndex,
    required this.onItemTapped,
  }) : super(key: key);

  @override
  State<SidebarDrawer> createState() => _SidebarDrawerState();
}

class _SidebarDrawerState extends State<SidebarDrawer> {
  String _appVersion = '...';
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final premium = await LimitService.isPremium();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
          _isPremium = premium;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _appVersion = '1.0.0';
          _isPremium = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appMode = context.watch<AppModeProvider>();

    return Drawer(
      backgroundColor: appMode.bgColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── HEADER dengan animasi glow ──
          Container(
            decoration: BoxDecoration(
              color: appMode.surfaceColor,
              border: Border(
                bottom: BorderSide(
                  color: appMode.cardBorderColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo kecil
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: appMode.primaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.auto_awesome,
                        color: appMode.accentColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: GlowText(
                          text: 'WINATRA AI',
                          glowColor: appMode.accentColor,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: appMode.accentColor,
                          ),
                        ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'AI Shortcut di Genggaman',
                  style: TextStyle(
                    color: appMode.primaryColor,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── MENU ITEMS ──
          _buildMenuItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home,
            title: 'Beranda',
            index: 0,
          ),
          _buildMenuItem(
            icon: Icons.notifications_outlined,
            activeIcon: Icons.notifications_active,
            title: 'Notifikasi',
            index: 1,
          ),
          _buildMenuItem(
            icon: Icons.keyboard_outlined,
            activeIcon: Icons.keyboard,
            title: 'Keyboard',
            index: 2,
          ),
          _buildMenuItem(
            icon: Icons.chat_bubble_outline,
            activeIcon: Icons.chat_bubble,
            title: 'Ngobrol Bareng Winatra',
            index: 3,
          ),

          // ── DIVIDER ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Divider(color: appMode.cardBorderColor.withOpacity(0.3)),
          ),

          // ── MODE AI TOGGLE ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'MODE AI',
              style: TextStyle(
                color: appMode.textColor.withOpacity(0.5),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          _buildModeToggle(appMode),

          // ── DIVIDER ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Divider(color: appMode.cardBorderColor.withOpacity(0.3)),
          ),

          // ── BOTTOM MENU ──
          _buildMenuItem(
            icon: Icons.favorite_outline,
            activeIcon: Icons.favorite,
            title: 'Dukung Kami',
            index: 4,
          ),
          _buildMenuItem(
            icon: Icons.info_outline,
            activeIcon: Icons.info,
            title: 'Tentang Aplikasi',
            index: 5,
          ),

          const Spacer(),

          // ── LOGOUT & VERSION ──
          _buildMenuItem(
            icon: Icons.logout,
            activeIcon: Icons.logout,
            title: 'Logout',
            index: 10,
            isDestructive: true,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isPremium ? Icons.star : Icons.lock_open,
                      color: _isPremium
                          ? const Color(0xFF00FFAA)
                          : appMode.primaryColor,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isPremium ? 'Premium aktif' : 'Status: Free',
                      style: TextStyle(
                        color: appMode.textColor.withOpacity(0.6),
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'v$_appVersion',
                      style: TextStyle(
                        color: appMode.textColor.withOpacity(0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required IconData activeIcon,
    required String title,
    required int index,
    bool isDestructive = false,
  }) {
    final isSelected = widget.selectedIndex == index;
    final appMode = context.read<AppModeProvider>();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? appMode.surfaceColor : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected
              ? appMode.accentColor
              : isDestructive
                  ? Colors.redAccent
                  : appMode.textColor.withOpacity(0.7),
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected
                ? appMode.accentColor
                : isDestructive
                    ? Colors.redAccent
                    : appMode.textColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        trailing: isSelected
            ? Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: appMode.accentColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            : null,
        onTap: () {
          Navigator.pop(context);
          widget.onItemTapped(index);
        },
      ),
    );
  }

  Widget _buildModeToggle(AppModeProvider appMode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appMode.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: appMode.isOffline
              ? const Color(0xFF00CC88).withOpacity(0.5)
              : const Color(0xFF6B4EFF).withOpacity(0.5),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Online option
              Expanded(
                child: GestureDetector(
                  onTap: () => appMode.setOffline(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
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
                        Icon(
                          Icons.public,
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
              // Offline option
              Expanded(
                child: GestureDetector(
                  onTap: () => appMode.setOffline(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
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
                        Icon(
                          Icons.lock,
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
          // Status indicator
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: appMode.isOffline
                      ? const Color(0xFF00CC88)
                      : const Color(0xFF6B4EFF),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                appMode.isOffline
                    ? 'Semua AI berjalan secara lokal'
                    : 'Terhubung ke server Groq',
                style: TextStyle(
                  color: appMode.textColor.withOpacity(0.5),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}