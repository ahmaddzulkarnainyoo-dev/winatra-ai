import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SpecializationPicker extends StatefulWidget {
  final String? currentSpecialization;
  final VoidCallback? onSpecializationChanged;

  const SpecializationPicker({
    Key? key,
    this.currentSpecialization,
    this.onSpecializationChanged,
  }) : super(key: key);

  @override
  _SpecializationPickerState createState() => _SpecializationPickerState();
}

class _SpecializationPickerState extends State<SpecializationPicker> {
  // Daftar lengkap spesialisasi
  static const Map<String, List<String>> SPECIALIZATIONS = {
    'Mata Kuliah Universitas': [
      'Fisika',
      'Kimia',
      'Biologi',
      'Matematika',
      'Statistika',
      'Ilmu Komputer',
      'Teknik Sipil',
      'Teknik Elektro',
      'Teknik Mesin',
      'Hukum',
      'Ekonomi',
      'Akuntansi',
      'Manajemen',
      'Psikologi',
      'Sosiologi',
      'Filsafat',
      'Sejarah',
      'Geografi',
      'Linguistik',
      'Sastra',
      'Pendidikan',
      'Kesehatan Masyarakat',
      'Kedokteran',
      'Farmasi',
      'Keperawatan',
      'Arsitektur',
      'Seni Rupa',
      'Desain Komunikasi Visual',
      'Hubungan Internasional',
      'Ilmu Politik',
      'Komunikasi',
      'Jurnalistik',
    ],
    'Mata Pelajaran SMA/SMP/SD': [
      'Matematika Wajib',
      'Matematika Peminatan',
      'Fisika',
      'Kimia',
      'Biologi',
      'Ekonomi',
      'Geografi',
      'Sejarah',
      'Sosiologi',
      'Antropologi',
      'Bahasa Indonesia',
      'Bahasa Inggris',
      'Bahasa Arab',
      'PKN',
      'Agama Islam',
      'Agama Kristen',
      'Agama Katolik',
      'Agama Hindu',
      'Agama Buddha',
      'Seni Budaya',
      'Prakarya',
      'PJOK',
      'Informatika (TIK)',
      'Kewirausahaan',
    ],
  };

  String? selectedSpecialization;
  String searchQuery = '';
  bool isPremium = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadSelectedSpecialization();
    await _checkPremiumStatus();
  }

  Future<void> _loadSelectedSpecialization() async {
    final prefs = await SharedPreferences.getInstance();
    final spec = prefs.getString('user_specialization') ?? 'general';
    setState(() {
      selectedSpecialization = spec;
    });
  }

  Future<void> _checkPremiumStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => isPremium = false);
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        setState(() => isPremium = false);
        return;
      }

      final isPremiumFlag = doc.get('isPremium') as bool? ?? false;
      final expiry = doc.get('premiumExpiry') as Timestamp?;

      bool isExpired = false;
      if (expiry != null) {
        isExpired = expiry.toDate().isBefore(DateTime.now());
      }

      setState(() => isPremium = isPremiumFlag && !isExpired);
    } catch (e) {
      setState(() => isPremium = false);
    }
  }

  Future<void> _saveSpecialization(String spec) async {
    if (!isPremium && spec != 'general') {
      _showPremiumDialog();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_specialization', spec);

    setState(() {
      selectedSpecialization = spec;
    });

    // Tampilkan notifikasi sukses
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          spec == 'general'
              ? 'Spesialisasi direset ke General'
              : 'Spesialisasi diubah ke $spec',
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF6B4EFF),
      ),
    );

    // Panggil callback jika ada
    widget.onSpecializationChanged?.call();
  }

  void _showPremiumDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text(
          'Fitur Premium',
          style: TextStyle(color: Color(0xFF9B7EFF)),
        ),
        content: const Text(
          'Fitur pemilihan spesialisasi hanya tersedia untuk pengguna Premium. Upgrade sekarang untuk mendapatkan jawaban AI yang lebih spesifik sesuai bidang ilmu Anda!',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Tutup',
              style: TextStyle(color: Color(0xFF9B7EFF)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigasi ke halaman upgrade/langganan
            },
            child: const Text(
              'Upgrade Sekarang',
              style: TextStyle(
                color: Color(0xFF6B4EFF),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getAllSpecializations() {
    final all = <String>['general'];
    SPECIALIZATIONS.forEach((_, items) {
      all.addAll(items);
    });
    return all;
  }

  List<String> _filterSpecializations(String query) {
    final all = _getAllSpecializations();
    if (query.isEmpty) {
      return all;
    }
    return all
        .where((spec) => spec.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  void _showSpecializationBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0D1A),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                border: Border(
                  bottom: BorderSide(
                    color: const Color(0xFF6B4EFF).withOpacity(0.3),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pilih Spesialisasi AI',
                    style: const TextStyle(
                      color: Color(0xFF9B7EFF),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isPremium
                        ? 'Pilih bidang ilmu agar AI menjawab lebih spesifik'
                        : '🔒 Fitur untuk pengguna Premium',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            if (isPremium)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  border: Border(
                    bottom: BorderSide(
                      color: const Color(0xFF6B4EFF).withOpacity(0.2),
                    ),
                  ),
                ),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Cari spesialisasi...',
                    hintStyle: TextStyle(color: Colors.white30),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.white30,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFF6B4EFF),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: const Color(0xFF6B4EFF).withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFF6B4EFF),
                      ),
                    ),
                  ),
                ),
              ),

            // List
            Expanded(
              child: isPremium
                  ? _buildSpecializationList(scrollController)
                  : _buildLockedContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecializationList(ScrollController scrollController) {
    final filtered = _filterSpecializations(searchQuery);

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final spec = filtered[index];
        final isSelected = selectedSpecialization == spec;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6B4EFF) : const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF9B7EFF)
                  : const Color(0xFF6B4EFF).withOpacity(0.3),
            ),
          ),
          child: ListTile(
            title: Text(
              spec == 'general' ? 'General / Tanpa Spesialisasi' : spec,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            leading: Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? Colors.white : Colors.white54,
            ),
            onTap: () {
              _saveSpecialization(spec);
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }

  Widget _buildLockedContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock_outline,
            size: 48,
            color: Color(0xFF9B7EFF),
          ),
          const SizedBox(height: 16),
          const Text(
            'Fitur Premium',
            style: TextStyle(
              color: Color(0xFF9B7EFF),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: const Text(
              'Upgrade ke Premium untuk membuka fitur pemilihan spesialisasi dan dapatkan jawaban AI yang lebih mendalam sesuai bidang ilmu Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigasi ke halaman upgrade/langganan
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B4EFF),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Upgrade Sekarang',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Button untuk buka picker
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ElevatedButton.icon(
            onPressed: _showSpecializationBottomSheet,
            icon: const Icon(Icons.school, color: Colors.white),
            label: Text(
              selectedSpecialization == null || selectedSpecialization == 'general'
                  ? 'Pilih Spesialisasi (General)'
                  : 'Spesialisasi: ${selectedSpecialization}',
              style: const TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isPremium
                  ? const Color(0xFF6B4EFF)
                  : const Color(0xFF6B4EFF).withOpacity(0.5),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
