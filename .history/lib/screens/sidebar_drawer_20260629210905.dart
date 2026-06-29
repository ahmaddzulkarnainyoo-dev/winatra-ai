import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/limit_service.dart';

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
    return Drawer(
      backgroundColor: const Color(0xFF0D0D1A),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Color(0xFF1A1A2E),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'WINATRA AI',
                  style: TextStyle(
                    color: Color(0xFF9B7EFF),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'AI Shortcut di Genggaman',
                  style: TextStyle(
                    color: Color(0xFF6B4EFF),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.home,
            title: 'Beranda',
            index: 0,
            selectedIndex: widget.selectedIndex,
            onTap: () => widget.onItemTapped(0),
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.notifications_active,
            title: 'Notifikasi',
            index: 1,
            selectedIndex: widget.selectedIndex,
            onTap: () => widget.onItemTapped(1),
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.keyboard,
            title: 'Keyboard',
            index: 2,
            selectedIndex: widget.selectedIndex,
            onTap: () => widget.onItemTapped(2),
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.cloud_off,
            title: 'AI Offline',
            index: 3,
            selectedIndex: widget.selectedIndex,
            onTap: () => widget.onItemTapped(3),
          ),
          const Divider(color: Color(0xFF333355)),
          _buildDrawerItem(
            context: context,
            icon: Icons.favorite,
            title: 'Dukung Kami',
            index: 4,
            selectedIndex: widget.selectedIndex,
            onTap: () => widget.onItemTapped(4),
          ),
          _buildDrawerItem(
            context: context,
            icon: Icons.info_outline,
            title: 'Tentang Aplikasi',
            index: 5,
            selectedIndex: widget.selectedIndex,
            onTap: () => widget.onItemTapped(5),
          ),
          const Divider(color: Color(0xFF333355)),
          const SizedBox(height: 8),
          _buildDrawerItem(
            context: context,
            icon: Icons.logout,
            title: 'Logout',
            index: 10,
            selectedIndex: widget.selectedIndex,
            onTap: () => widget.onItemTapped(10),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Versi: $_appVersion', style: const TextStyle(color: Color(0xFF9999BB), fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(_isPremium ? Icons.star : Icons.lock_open, color: _isPremium ? const Color(0xFF00FFAA) : const Color(0xFF6B4EFF), size: 16),
                    const SizedBox(width: 6),
                    Text(_isPremium ? 'Premium aktif' : 'Status: Free', style: const TextStyle(color: Color(0xFF9999BB), fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required int index,
    required int selectedIndex,
    required VoidCallback onTap,
  }) {
    final isSelected = selectedIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFF9B7EFF) : const Color(0xFF9999BB)),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? const Color(0xFF9B7EFF) : const Color(0xFFCCCCCC),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      tileColor: isSelected ? const Color(0xFF1A1A2E) : null,
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }
}


