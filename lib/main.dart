import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/notification_mode_screen.dart';
import 'screens/keyboard_mode_screen.dart';
import 'screens/sidebar_drawer.dart';
import 'screens/support_screen.dart';
import 'services/limit_service.dart'; // <-- Tambah import ini

const platform = MethodChannel('winatra/service');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  runApp(const MyApp(home: SplashScreen()));
}

class MyApp extends StatelessWidget {
  final Widget home;
  const MyApp({Key? key, required this.home}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6B4EFF)),
        useMaterial3: true,
      ),
      home: home,
    );
  }
}

// Top-level functions for Remote Config check - accessible from all screens
Future<void> checkForUpdate(BuildContext context) async {
  try {
    final remoteConfig = FirebaseRemoteConfig.instance;
    debugPrint('[RemoteConfig] Starting update check...');
    
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(minutes: 1),
      minimumFetchInterval: Duration.zero,
    ));
    
    final activated = await remoteConfig.fetchAndActivate();
    debugPrint('[RemoteConfig] Fetch and activate completed. activated=$activated');

    final minVersion = remoteConfig.getString('min_version');
    final forceUpdate = remoteConfig.getBool('force_update');
    final updateUrl = remoteConfig.getString('update_url');

    debugPrint('[RemoteConfig] min_version: "$minVersion"');
    debugPrint('[RemoteConfig] force_update: $forceUpdate');
    debugPrint('[RemoteConfig] update_url: "$updateUrl"');

    if (minVersion.isEmpty) {
      debugPrint('[RemoteConfig] min_version is empty, skipping update check');
      return;
    }
    if (updateUrl.isEmpty) {
      debugPrint('[RemoteConfig] update_url is empty, skipping update check');
      return;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version.split('+').first;
    debugPrint('[RemoteConfig] Current app version: $currentVersion');

    final versionComparison = compareVersions(currentVersion, minVersion);
    debugPrint('[RemoteConfig] Version comparison result: $versionComparison (current vs min)');

    if (versionComparison < 0 && forceUpdate) {
      debugPrint('[RemoteConfig] Update required! Showing dialog...');
      if (context.mounted) {
        showForceUpdateDialog(context, updateUrl);
      }
    } else {
      debugPrint('[RemoteConfig] No update required. versionComparison=$versionComparison, forceUpdate=$forceUpdate');
    }
  } catch (e) {
    debugPrint('[RemoteConfig] Force update check failed: $e');
  }
}

int compareVersions(String current, String required) {
  final currentParts = current.split('.').map(int.tryParse).whereType<int>().toList();
  final requiredParts = required.split('.').map(int.tryParse).whereType<int>().toList();

  for (int i = 0; i < 3; i++) {
    final curr = i < currentParts.length ? currentParts[i] : 0;
    final req = i < requiredParts.length ? requiredParts[i] : 0;
    if (curr < req) return -1;
    if (curr > req) return 1;
  }
  return 0;
}

void showForceUpdateDialog(BuildContext context, String updateUrl) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      title: const Text('Update Diperlukan', style: TextStyle(color: Color(0xFF9B7EFF))),
      content: const Text(
        'Versi aplikasi Anda sudah lama. Silakan update ke versi terbaru untuk lanjut menggunakan aplikasi.',
        style: TextStyle(color: Color(0xFFCCCCCC)),
      ),
      actions: [
        ElevatedButton(
          onPressed: () async {
            if (await canLaunchUrl(Uri.parse(updateUrl))) {
              await launchUrl(Uri.parse(updateUrl), mode: LaunchMode.externalApplication);
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B4EFF)),
          child: const Text('Update', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

class MainAppWrapper extends StatefulWidget {
  const MainAppWrapper({Key? key}) : super(key: key);

  @override
  State<MainAppWrapper> createState() => _MainAppWrapperState();
}

class _MainAppWrapperState extends State<MainAppWrapper> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;

  void _onItemTapped(int index) async {
    if (index == 10) {
      // Hapus device binding sebelum logout
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
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
      }
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const HomeScreen(),
      NotificationModeScreen(currentMode: 'Essay'),
      const KeyboardModeScreen(),
      const SupportScreen(),
      const _AboutScreen(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await checkForUpdate(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF0D0D1A),
      body: Stack(
        children: [
          _pages[_selectedIndex],
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.topLeft,
                child: Material(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(12),
                  child: IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    tooltip: 'Buka menu',
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      drawerEnableOpenDragGesture: true,
      drawerScrimColor: Colors.black54,
      drawer: SidebarDrawer(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}

class _AboutScreen extends StatelessWidget {
  const _AboutScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        title: const Text('Tentang Winatra AI', style: TextStyle(color: Color(0xFF9B7EFF))),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF9B7EFF)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Winatra AI', style: TextStyle(color: Color(0xFF9B7EFF), fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text('AI Shortcut untuk pelajar, pekerja, dan kreator Indonesia. Gratis selamanya.', style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 14, height: 1.6)),
            SizedBox(height: 20),
            Text('Beta v0.1.0', style: TextStyle(color: Color(0xFF666699), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    
    // Check for updates early
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await checkForUpdate(context);
    });
    
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _navigateToNextScreen();
    });
  }

  Future<void> _navigateToNextScreen() async {
    final prefs = await SharedPreferences.getInstance();
    bool tosAccepted = prefs.getBool('tos_accepted') ?? false;

    if (!tosAccepted) {
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TosScreen()));
      return;
    }

    bool isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    if (!isLoggedIn) {
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
      return;
    }

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        String status = (doc['status'] ?? 'pending').toString().trim();
        if (status == 'approved') {
          try { await platform.invokeMethod('startService'); } catch (e) {}
          // Sinkronkan limit setelah login sukses
          await LimitService.syncRemainingToPrefs();
          if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainAppWrapper()));
        } else {
          if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
        }
      } else {
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
      }
    } catch (e) {
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
    }
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo.png', width: 160, height: 160),
              const SizedBox(height: 24),
              const Text('WINATRA', style: TextStyle(color: Color(0xFF9B7EFF), fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 8)),
              const SizedBox(height: 8),
              const Text('AI BETA', style: TextStyle(color: Color(0xFF6B4EFF), fontSize: 14, letterSpacing: 6)),
            ],
          ),
        ),
      ),
    );
  }
}

class TosScreen extends StatefulWidget {
  const TosScreen({Key? key}) : super(key: key);
  @override
  _TosScreenState createState() => _TosScreenState();
}

class _TosScreenState extends State<TosScreen> {
  bool _agreed = false;

  Future<void> _accept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tos_accepted', true);
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        title: const Text('Syarat & Ketentuan', style: TextStyle(color: Color(0xFF9B7EFF))),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  'WINATRA AI — VERSI BETA\n\nSelamat datang di Winatra AI. Dengan menggunakan aplikasi ini, kamu menyetujui bahwa fitur AI hanya sebagai alat bantu. Jangan gunakan untuk tindakan yang melanggar hukum atau integritas akademik secara tidak bertanggung jawab.\n\nData kamu disimpan secara lokal dan di Firebase untuk keperluan autentikasi. Kami tidak menjual data kamu.',
                  style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 13, height: 1.6),
                ),
              ),
            ),
            Row(
              children: [
                Checkbox(
                  value: _agreed,
                  onChanged: (val) => setState(() => _agreed = val ?? false),
                  activeColor: const Color(0xFF6B4EFF),
                ),
                const Expanded(
                  child: Text('Saya telah membaca dan menyetujui syarat & ketentuan', style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 13)),
                ),
              ],
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _agreed ? _accept : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B4EFF),
                  disabledBackgroundColor: const Color(0xFF333355),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Setuju & Lanjutkan', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}