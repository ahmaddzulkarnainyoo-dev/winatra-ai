import 'package:flutter/material.dart';
// import '../services/offline_ai_service.dart';

class AITrainingScreen extends StatefulWidget {
  const AITrainingScreen({Key? key}) : super(key: key);

  @override
  State<AITrainingScreen> createState() => _AITrainingScreenState();
}

class _AITrainingScreenState extends State<AITrainingScreen> {
  // final _service = OfflineAIService.instance;
  final _questionCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();
  List<Map<String, dynamic>> pairs = [];
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // final data = await _service.getTrainingPairs();
    // setState(() { pairs = data; });
    print('TODO: Load training pairs from service');
  }

  Future<void> _save() async {
    final q = _questionCtrl.text.trim();
    final a = _answerCtrl.text.trim();
    if (q.isEmpty || a.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Isi pertanyaan dan jawaban dulu!'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }
    setState(() { isSaving = true; });
    // await _service.addTrainingPair(q, a);
    _questionCtrl.clear();
    _answerCtrl.clear();
    await _load();
    setState(() { isSaving = false; });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Data latih disimpan!'),
        backgroundColor: Colors.green,
      ));
    }
  }

  Future<void> _delete(String id) async {
    // await _service.deleteTrainingPair(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        title: const Text('Latih AI Offline', style: TextStyle(color: Color(0xFF9B7EFF))),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // INFO BOX
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF6B4EFF).withOpacity(0.5)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Color(0xFF9B7EFF), size: 18),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'Tambah pasangan Q&A. AI akan gunakan data ini sebagai referensi saat menjawab pertanyaan serupa.',
                  style: TextStyle(color: Color(0xFFCCCCCC), fontSize: 12),
                )),
              ]),
            ),
            const SizedBox(height: 20),

            // INPUT
            const Text('Pertanyaan:', style: TextStyle(color: Color(0xFF9B7EFF), fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _questionCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: _inputDecor('Contoh: Apa itu fotosintesis?'),
            ),
            const SizedBox(height: 12),
            const Text('Jawaban:', style: TextStyle(color: Color(0xFF9B7EFF), fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _answerCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 5,
              decoration: _inputDecor('Contoh: Fotosintesis adalah proses tumbuhan mengubah cahaya matahari menjadi energi...'),
            ),
            const SizedBox(height: 16),

            // SAVE BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : _save,
                icon: isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save, color: Colors.white),
                label: Text(isSaving ? 'Menyimpan...' : 'Simpan Data Latih', style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B4EFF),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // LIST
            Row(children: [
              const Text('Data Tersimpan', style: TextStyle(color: Color(0xFF9B7EFF), fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF6B4EFF), borderRadius: BorderRadius.circular(10)),
                child: Text('${pairs.length}', style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 8),

            if (pairs.isEmpty)
              const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Belum ada data latih.\nTambah Q&A di atas.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF666688))),
              ))
            else
              ...pairs.reversed.map((p) => _pairTile(p)),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecor(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF555577)),
    enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF333355)), borderRadius: BorderRadius.circular(10)),
    focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFF6B4EFF)), borderRadius: BorderRadius.circular(10)),
    filled: true,
    fillColor: const Color(0xFF1A1A2E),
  );

  Widget _pairTile(Map<String, dynamic> pair) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF1A1A2E),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFF333355)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.help_outline, color: Color(0xFF9B7EFF), size: 14),
        const SizedBox(width: 4),
        Expanded(child: Text(pair['question'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis)),
        GestureDetector(onTap: () => _delete(pair['id'].toString()), child: const Icon(Icons.close, color: Colors.redAccent, size: 16)),
      ]),
      const SizedBox(height: 6),
      const Divider(color: Color(0xFF333355), height: 1),
      const SizedBox(height: 6),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.lightbulb_outline, color: Colors.greenAccent, size: 14),
        const SizedBox(width: 4),
        Expanded(child: Text(pair['answer'] ?? '', style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 12), maxLines: 3, overflow: TextOverflow.ellipsis)),
      ]),
    ]),
  );

  @override
  void dispose() {
    _questionCtrl.dispose();
    _answerCtrl.dispose();
    super.dispose();
  }
}