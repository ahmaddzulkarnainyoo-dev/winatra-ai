import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../services/limit_service.dart'; // import limit service
import 'support_screen.dart'; // untuk navigasi premium

class KeyboardModeScreen extends StatefulWidget {
  const KeyboardModeScreen({Key? key}) : super(key: key);

  @override
  _KeyboardModeScreenState createState() => _KeyboardModeScreenState();
}

class _KeyboardModeScreenState extends State<KeyboardModeScreen> {
  bool keyboardEnabled = true;
  int remainingQuota = 0;
  bool isLoadingQuota = true;

  @override
  void initState() {
    super.initState();
    _loadKeyboardEnabled();
    _loadQuota();
  }

  Future<void> _loadKeyboardEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      keyboardEnabled = prefs.getBool('keyboard_enabled') ?? true;
    });
  }

  Future<void> _loadQuota() async {
    final quota = await LimitService.getRemainingQuota();
    setState(() {
      remainingQuota = quota;
      isLoadingQuota = false;
    });
  }

  Future<void> _toggleKeyboardEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('keyboard_enabled', value);
    setState(() {
      keyboardEnabled = value;
    });
    if (!value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keyboard Winatra dinonaktifkan. Aktifkan kembali kapan saja di sini.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keyboard Winatra diaktifkan. Pastikan keyboard sudah dipilih di pengaturan sistem.')),
      );
    }
  }

  void _openKeyboardSettings() {
    try {
      const platform = MethodChannel('winatra/service');
      platform.invokeMethod('openKeyboardSettings');
    } catch (e) {
      const platform = MethodChannel('winatra/service');
      platform.invokeMethod('openLanguageInputSettings');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        title: const Text('Mode Keyboard', style: TextStyle(color: Color(0xFF9B7EFF))),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Keyboard Winatra AI',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF9B7EFF)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Aktifkan keyboard khusus ini untuk menggunakan AI di semua aplikasi tanpa notifikasi. Keyboard memiliki 3 tab: Ketik, Tanya AI, dan Baca.',
              style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 14),
            ),
            const SizedBox(height: 24),
            // ---- Status kuota premium ----
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF6B4EFF)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Sisa Kuota Hari Ini', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  if (isLoadingQuota)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  else if (remainingQuota == -1)
                    const Text('Unlimited (Premium)', style: TextStyle(color: Color(0xFF00FFAA), fontWeight: FontWeight.bold))
                  else
                    Text('$remainingQuota / 15', style: const TextStyle(color: Color(0xFF9B7EFF), fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportScreen()));
              },
              icon: const Icon(Icons.stars, color: Colors.white),
              label: const Text('Upgrade ke Premium (Rp5.000/hari)', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B4EFF), minimumSize: const Size(double.infinity, 45)),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Aktifkan Keyboard', style: TextStyle(color: Colors.white, fontSize: 16)),
                Switch(
                  value: keyboardEnabled,
                  onChanged: _toggleKeyboardEnabled,
                  activeColor: const Color(0xFF6B4EFF),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (keyboardEnabled)
              Column(
                children: [
                  const Text(
                    'Langkah aktivasi keyboard (lakukan sekali saja):',
                    style: TextStyle(color: Color(0xFF9B7EFF), fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('1. Buka Pengaturan → Sistem → Bahasa & Input → Keyboard', style: TextStyle(color: Color(0xFFCCCCCC))),
                  const Text('2. Pilih "Winatra Keyboard" dan aktifkan', style: TextStyle(color: Color(0xFFCCCCCC))),
                  const Text('3. Saat mengetik, pilih Winatra Keyboard dari switcher keyboard', style: TextStyle(color: Color(0xFFCCCCCC))),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _openKeyboardSettings,
                    icon: const Icon(Icons.settings),
                    label: const Text('Buka Pengaturan Keyboard'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B4EFF)),
                  ),
                ],
              )
            else
              const Text(
                'Keyboard dinonaktifkan. Aktifkan switch di atas untuk menggunakan.',
                style: TextStyle(color: Colors.orange),
              ),
          ],
        ),
      ),
    );
  }
}