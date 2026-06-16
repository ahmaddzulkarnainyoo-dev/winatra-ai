import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/specialization_picker.dart';

const platform = MethodChannel('winatra/service');

class NotificationModeScreen extends StatefulWidget {
  final String currentMode;
  const NotificationModeScreen({Key? key, required this.currentMode}) : super(key: key);

  @override
  _NotificationModeScreenState createState() => _NotificationModeScreenState();
}

class _NotificationModeScreenState extends State<NotificationModeScreen> {
  late String mode;
  bool autoSolve = false;
  bool notifEnabled = true;
  bool offlineMode = false;
  int remainingQuota = 0;

  @override
  void initState() {
    super.initState();
    mode = widget.currentMode;
    _loadAutoSolve();
    _loadNotifEnabled();
    _loadRemainingQuota();
    _loadOfflineMode();
  }

  Future<void> _loadAutoSolve() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      autoSolve = prefs.getBool('auto_solve') ?? false;
    });
  }

  Future<void> _loadNotifEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      notifEnabled = prefs.getBool('notif_enabled') ?? true;
    });
    if (notifEnabled) {
      try { await platform.invokeMethod('startService'); } catch (e) {}
    } else {
      try { await platform.invokeMethod('stopService'); } catch (e) {}
    }
  }

  Future<void> _loadRemainingQuota() async {
    final prefs = await SharedPreferences.getInstance();
    final remaining = prefs.getInt('remaining_quota');
    if (remaining != null) {
      setState(() {
        remainingQuota = remaining;
      });
    }
  }

  Future<void> _toggleNotifEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_enabled', value);
    setState(() {
      notifEnabled = value;
    });
    if (value) {
      try { await platform.invokeMethod('startService'); } catch (e) {}
    } else {
      try { await platform.invokeMethod('stopService'); } catch (e) {}
      try { await platform.invokeMethod('cancelNotification'); } catch (e) {}
    }
  }

  Future<void> _toggleAutoSolve(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_solve', value);
    setState(() {
      autoSolve = value;
    });
    try {
      await platform.invokeMethod('setAutoSolve', {'enabled': value});
    } catch (e) {}
  }

  Future<void> _toggleMode() async {
    final prefs = await SharedPreferences.getInstance();
    String newMode = (mode == 'Essay') ? 'PG' : 'Essay';
    await prefs.setString('mode', newMode);
    try { await platform.invokeMethod('syncMode', {'mode': newMode}); } catch (e) {}
    setState(() => mode = newMode);
  }

  Future<void> _loadOfflineMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      offlineMode = prefs.getBool('offline_mode_enabled') ?? false;
    });
  }

  Future<void> _toggleOfflineMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('offline_mode_enabled', value);
    setState(() {
      offlineMode = value;
    });
    
    // Sinkronisasi ke Android service
    try {
      await platform.invokeMethod('setOfflineMode', {'enabled': value});
    } catch (e) {}
    
    // Tampilkan dialog edukasi jika offline mode diaktifkan
    if (value && mounted) {
      _showOfflineEducationDialog();
    }
  }

  void _showOfflineEducationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            '🔒 Mode Offline Aktif',
            style: TextStyle(color: Color(0xFF9B7EFF), fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sekarang semua pertanyaan akan diproses oleh AI offline di HP Anda.',
                  style: TextStyle(color: Color(0xFFCCCCDD), fontSize: 14),
                ),
                const SizedBox(height: 16),
                const Text(
                  '✅ Keuntungan:',
                  style: TextStyle(color: Color(0xFF6B4EFF), fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Tanpa internet — hemat kuota\n• Privasi terjaga — data tidak keluar HP\n• Cepat — tidak perlu tunggu API',
                  style: TextStyle(color: Color(0xFFBBBBEE), fontSize: 13),
                ),
                const SizedBox(height: 16),
                const Text(
                  '💡 Tips untuk jawaban lebih akurat:',
                  style: TextStyle(color: Color(0xFF6B4EFF), fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Upload dokumen (PDF/DOCX/TXT) di halaman "AI Offline"\n• Jawaban akan menggunakan materi yang Anda upload\n• Mode offline cocok untuk belajar tanpa gangguan',
                  style: TextStyle(color: Color(0xFFBBBBEE), fontSize: 13),
                ),
                const SizedBox(height: 16),
                const Text(
                  'ℹ️ Catatan:',
                  style: TextStyle(color: Color(0xFFFFB84D), fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Jika model lokal tidak tersedia, akan otomatis fallback ke AI online.',
                  style: TextStyle(color: Color(0xFFBBBBEE), fontSize: 13),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B4EFF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Saya Mengerti', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        title: const Text('Mode Notifikasi', style: TextStyle(color: Color(0xFF9B7EFF))),
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo.png', width: 120, height: 120),
            const SizedBox(height: 16),
            const Text('Winatra AI Shortcut', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF6B4EFF))),
              child: Text('Mode aktif: $mode', style: const TextStyle(color: Color(0xFF9B7EFF), fontSize: 14)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _toggleMode,
              icon: const Icon(Icons.swap_horiz, color: Colors.white),
              label: Text('Ganti ke ${mode == "Essay" ? "PG" : "Essay"}', style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B4EFF),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            // Tambahkan SpecializationPicker
            SpecializationPicker(
              currentSpecialization: null,
              onSpecializationChanged: () {
                // Reload state jika diperlukan
                setState(() {});
              },
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF6B4EFF)),
              ),
              child: remainingQuota == -1
                  ? const Text('Akses unlimited (Premium)', style: TextStyle(color: Color(0xFF9B7EFF), fontSize: 14))
                  : Text('Sisa kuota hari ini: $remainingQuota dari 15', style: const TextStyle(color: Color(0xFF9B7EFF), fontSize: 14)),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Auto-solve', style: TextStyle(color: Colors.white)),
                Switch(value: autoSolve, onChanged: _toggleAutoSolve, activeColor: const Color(0xFF6B4EFF)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Aktifkan Notifikasi AI', style: TextStyle(color: Colors.white)),
                Switch(value: notifEnabled, onChanged: _toggleNotifEnabled, activeColor: const Color(0xFF6B4EFF)),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: offlineMode ? const Color(0xFF6B4EFF) : const Color(0xFF333355), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '🔒 Mode Offline',
                            style: TextStyle(color: Color(0xFF9B7EFF), fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          const SizedBox(
                            width: 240,
                            child: Text(
                              'Gunakan AI lokal tanpa internet. Jawaban berdasarkan model offline & dokumen yang diupload.',
                              style: TextStyle(color: Color(0xFF7B7B9E), fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Switch(value: offlineMode, onChanged: _toggleOfflineMode, activeColor: const Color(0xFF6B4EFF)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _showOfflineEducationDialog(),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFF6B4EFF), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Pelajari lebih lanjut',
                          style: TextStyle(color: Color(0xFF6B4EFF), fontSize: 12, decoration: TextDecoration.underline),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  Text('📋 Cara Pakai:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF9B7EFF))),
                  SizedBox(height: 8),
                  Text('1. Copy pertanyaan (akhiri dengan ? untuk Auto-solve)', style: TextStyle(fontSize: 13, color: Color(0xFFBBBBEE))),
                  Text('2. Buka notifikasi, tekan tombol "Jawab"', style: TextStyle(fontSize: 13, color: Color(0xFFBBBBEE))),
                  Text('3. Mode PG: jawaban pop-up + tombol "Kenapa?"', style: TextStyle(fontSize: 13, color: Color(0xFFBBBBEE))),
                  Text('4. Mode Essay: jawaban auto-copy ke clipboard', style: TextStyle(fontSize: 13, color: Color(0xFFBBBBEE))),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Beta v0.1.0', style: TextStyle(color: Color(0xFF444466), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
