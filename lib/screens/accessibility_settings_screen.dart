import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/accessibility_service.dart';
import 'accessibility_guide.dart';

class AccessibilitySettingsScreen extends StatefulWidget {
  const AccessibilitySettingsScreen({Key? key}) : super(key: key);

  @override
  State<AccessibilitySettingsScreen> createState() => _AccessibilitySettingsScreenState();
}

class _AccessibilitySettingsScreenState extends State<AccessibilitySettingsScreen> {
  bool serviceEnabled = false;
  bool listeningEnabled = true;
  int selectedTrigger = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = await AccessibilityService.isServiceEnabled();
    setState(() {
      serviceEnabled = enabled;
      listeningEnabled = prefs.getBool('accessibility_listening_enabled') ?? true;
      selectedTrigger = prefs.getInt('accessibility_trigger') ?? 0;
      loading = false;
    });
  }

  Future<void> _openAccessibilitySettings() async {
    await AccessibilityService.requestAccessibilityPermission();
    await Future.delayed(const Duration(milliseconds: 400));
    _loadStatus();
  }

  Future<void> _toggleListening(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('accessibility_listening_enabled', value);
    setState(() {
      listeningEnabled = value;
    });
    if (value) {
      await AccessibilityService.startListening();
    } else {
      await AccessibilityService.stopListening();
    }
  }

  Future<void> _selectTrigger(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accessibility_trigger', index);
    setState(() {
      selectedTrigger = index;
    });
  }

  Future<void> _tryNow() async {
    final text = await AccessibilityService.getSelectedText();
    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih teks di aplikasi lain lalu coba lagi.')),
      );
      return;
    }
    await AccessibilityService.processText(text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Memproses teks aksesibilitas. Tunggu notifikasi.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        title: const Text('Asisten Belajar', style: TextStyle(color: Color(0xFF9B7EFF))),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccessibilityGuideScreen())),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF9B7EFF)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Aktifkan Asisten Belajar', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'Winatra AI akan membaca teks yang Anda pilih atau tampilkan di layar dan memberi jawaban AI melalui notifikasi.',
                    style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  _statusCard(),
                  const SizedBox(height: 20),
                  _actionCard(),
                  const SizedBox(height: 20),
                  _triggerCard(),
                  const SizedBox(height: 20),
                  _guideCard(),
                  const SizedBox(height: 20),
                  _warningCard(),
                ],
              ),
            ),
    );
  }

  Widget _statusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Status Layanan', style: TextStyle(color: Color(0xFF9B7EFF), fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(serviceEnabled ? Icons.check_circle : Icons.error_outline, color: serviceEnabled ? Colors.greenAccent : Colors.amberAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  serviceEnabled ? 'Winatra Accessibility Service aktif.' : 'Layanan belum diaktifkan. Buka Pengaturan Aksesibilitas.',
                  style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            value: listeningEnabled,
            title: const Text('Matikan sementara', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Layanan tetap aktif di pengaturan, tapi tidak membaca teks sementara.', style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12)),
            activeColor: const Color(0xFF6B4EFF),
            onChanged: _toggleListening,
          ),
        ],
      ),
    );
  }

  Widget _actionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Aksi Cepat', style: TextStyle(color: Color(0xFF9B7EFF), fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _openAccessibilitySettings,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B4EFF), padding: const EdgeInsets.all(14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Buka Pengaturan Aksesibilitas', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _tryNow,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7DFF), padding: const EdgeInsets.all(14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Coba Sekarang', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccessibilityGuideScreen())),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF44475A), padding: const EdgeInsets.all(12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Buka Panduan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _triggerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pilihan Trigger', style: TextStyle(color: Color(0xFF9B7EFF), fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _triggerOption(0, 'Tekan volume up 2x', true),
          _triggerOption(1, 'Tombol mengambang (ikon nanti)', false),
          _triggerOption(2, 'Voice command (opsional)', false),
        ],
      ),
    );
  }

  Widget _triggerOption(int index, String title, bool available) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Radio.adaptive(value: index, groupValue: selectedTrigger, onChanged: available ? (value) { if (value != null) _selectTrigger(value as int); } : null, activeColor: const Color(0xFF6B4EFF)),
      title: Text(title, style: TextStyle(color: available ? Colors.white : const Color(0xFF777799))),
      subtitle: !available ? const Text('Nanti akan dikembangkan.', style: TextStyle(color: Color(0xFF666688), fontSize: 12)) : null,
      onTap: available ? () => _selectTrigger(index) : null,
    );
  }

  Widget _guideCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Panduan Cepat', style: TextStyle(color: Color(0xFF9B7EFF), fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('1. Buka pengaturan aksesibilitas dan aktifkan Winatra AI.', style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 14)),
          const Text('2. Kembali ke aplikasi, pilih trigger volume up 2x.', style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 14)),
          const Text('3. Buka aplikasi lain, pilih teks atau biarkan AI membaca layar.', style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 14)),
          const Text('4. Tunggu notifikasi jawaban AI.', style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _warningCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF6B4EFF))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Catatan Privasi', style: TextStyle(color: Color(0xFF9B7EFF), fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          Text('Fitur ini membaca teks di layar untuk membantu belajar. Winatra AI tidak menyimpan atau mengirim data pribadi ke server.', style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}
