import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/app_mode_provider.dart';
import '../providers/brain_provider.dart';
import '../services/limit_service.dart';
import '../routes.dart';
import 'dashboard/dashboard_screen.dart';
import 'brain/brain_screen.dart';
import 'chat_room_screen.dart';
import 'settings/settings_screen.dart';
import 'sidebar_drawer.dart';
import 'login_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const DashboardScreen(),
      const BrainScreen(),
      const ChatRoomScreen(),
      const SettingsScreen(),
    ];
  }

  void _onItemTapped(int index) async {
    if (index == 10) {
      // Logout
      try {
        final userId = FirebaseAuth.instance.currentUser?.uid;
        if (userId != null) {
          await FirebaseFirestore.instance.collection('device_bindings').doc(userId).delete();
        }
      } catch (e) {}
      if (mounted) Navigator.pop(context);
      await FirebaseAuth.instance.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_logged_in');
      if (mounted) {
        Navigator.pushReplacement(context, buildFadeSlideRoute(const LoginScreen()));
      }
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appMode = context.watch<AppModeProvider>();

    return ChangeNotifierProvider(
      create: (_) => BrainProvider(),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: appMode.bgColor,
        body: IndexedStack(
          index: _selectedIndex,
          children: _pages,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: appMode.cardBorderColor.withOpacity(0.3),
                width: 0.5,
              ),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            backgroundColor: appMode.bgColor,
            selectedItemColor: appMode.accentColor,
            unselectedItemColor: appMode.textColor.withOpacity(0.4),
            type: BottomNavigationBarType.fixed,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Beranda',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_tree_outlined),
                activeIcon: Icon(Icons.account_tree),
                label: 'The Brain',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.chat_bubble_outline),
                activeIcon: Icon(Icons.chat_bubble),
                label: 'Chat',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings),
                label: 'Pengaturan',
              ),
            ],
          ),
        ),
        drawerEnableOpenDragGesture: true,
        drawerScrimColor: Colors.black54,
        drawer: SidebarDrawer(
          selectedIndex: _selectedIndex,
          onItemTapped: _onItemTapped,
        ),
      ),
    );
  }
}