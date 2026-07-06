import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'providers/app_mode_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/sidebar_drawer.dart';
import 'services/limit_service.dart';
import 'services/chat_history_service.dart';
import 'services/notification_handler.dart' as bridge;
import 'services/robot_interaction_service.dart';
import 'services/voice_command_service.dart';
import 'providers/robot_state_provider.dart';
import 'providers/assistant_state_provider.dart';
import 'providers/voice_provider.dart';
import 'widgets/floating_robot.dart';
import 'widgets/floating_bubble.dart';
import 'providers/bubble_state_provider.dart';
import 'routes.dart';

const platform = MethodChannel('winatra/service');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Initialize Hive for local storage
  await Hive.initFlutter();
  await ChatHistoryService.initialize();
  
  // Setup MethodChannel bridge for native notification service communication
  bridge.NotificationHandler.setup();
  print('main: NotificationHandler.setup() completed');
  
  AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelKey: 'basic_channel',
        channelName: 'Winatra AI Notifications',
        channelDescription: 'Notifikasi jawaban dan asisten belajar',
        defaultColor: const Color(0xFF6B4EFF),
        importance: NotificationImportance.High,
        channelShowBadge: true,
      ),
    ],
  );

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AppModeProvider()..load()),
      ChangeNotifierProvider(create: (_) {
        final provider = RobotStateProvider();
        provider.startIdleAnimation();
        RobotInteractionService().init(provider);
        return provider;
      }),
      ChangeNotifierProvider(create: (_) {
        final provider = AssistantActiveProvider();
        provider.load();
        return provider;
      }),
      ChangeNotifierProvider(create: (_) {
        final voiceProvider = VoiceProvider();
        // Initialize VoiceCommandService with providers
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // This will be called after all providers are available
        });
        return voiceProvider;
      }),
      ChangeNotifierProvider(create: (_) => BubbleStateProvider()),
    ],
    child: const MyApp(home: SplashScreen()),
  ));
}

class MyApp extends StatelessWidget {
  final Widget home;
  const MyApp({Key? key, required this.home}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appMode = context.watch<AppModeProvider>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: appMode.primaryColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: appMode.bgColor,
        appBarTheme: AppBarTheme(
          backgroundColor: appMode.bgColor,
          foregroundColor: appMode.headerTextColor,
        ),
        cardColor: appMode.surfaceColor,
        dividerColor: appMode.cardBorderColor.withOpacity(0.3),
      ),
      home: Stack(
        children: [
          home,
          // Floating robot overlay for voice assistant (only on mobile)
          if (!kIsWeb)
            const Positioned.fill(
              child: FloatingRobot(),
            ),
          // Floating bubble for quick chat (only on mobile)
          if (!kIsWeb)
            const Positioned.fill(
              child: FloatingBubble(),
            ),
        ],
      ),
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

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scaleAnim = Tween<double>(begin: 0.92, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
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
      if (mounted) Navigator.pushReplacement(context, buildFadeSlideRoute(const TosScreen()));
      return;
    }

    bool isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    if (!isLoggedIn) {
      if (mounted) Navigator.pushReplacement(context, buildFadeSlideRoute(LoginScreen()));
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
          if (mounted) Navigator.pushReplacement(context, buildFadeSlideRoute(MainNavigationScreen()));
        } else {
          if (mounted) Navigator.pushReplacement(context, buildFadeSlideRoute(LoginScreen()));
        }
      } else {
        if (mounted) Navigator.pushReplacement(context, buildFadeSlideRoute(LoginScreen()));
      }
    } catch (e) {
      if (mounted) Navigator.pushReplacement(context, buildFadeSlideRoute(LoginScreen()));
    }
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: ScaleTransition(
        scale: _scaleAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with shimmer effect
                _ShimmerLogo(),
                const SizedBox(height: 24),
                const Text('WINATRA', style: TextStyle(color: Color(0xFF9B7EFF), fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 8)),
                const SizedBox(height: 8),
                const Text('AI BETA', style: TextStyle(color: Color(0xFF6B4EFF), fontSize: 14, letterSpacing: 6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shimmer/Glossy effect overlay on the logo
class _ShimmerLogo extends StatefulWidget {
  @override
  State<_ShimmerLogo> createState() => _ShimmerLogoState();
}

class _ShimmerLogoState extends State<_ShimmerLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Image.asset('assets/logo.png', width: 160, height: 160),
              // Shimmer gradient that moves left to right
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ShimmerPainter(
                      progress: _shimmerController.value,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShimmerPainter extends CustomPainter {
  final double progress;

  _ShimmerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Create a diagonal gradient from top-left to bottom-right
    // that slides across the logo
    final shimmerWidth = size.width * 0.5;
    final start = -shimmerWidth + (progress * (size.width + shimmerWidth * 2));
    
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withOpacity(0.0),
        Colors.white.withOpacity(0.0),
        Colors.white.withOpacity(0.5),
        Colors.white.withOpacity(0.8),
        Colors.white.withOpacity(0.5),
        Colors.white.withOpacity(0.0),
        Colors.white.withOpacity(0.0),
      ],
      stops: const [0.0, 0.1, 0.3, 0.5, 0.7, 0.9, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(
        start,
        0,
        shimmerWidth * 2,
        size.height,
      ));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter oldDelegate) =>
      oldDelegate.progress != progress;
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
    if (mounted) Navigator.pushReplacement(context, buildFadeSlideRoute(LoginScreen()));
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