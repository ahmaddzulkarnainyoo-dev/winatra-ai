# UX Evaluation Report

## Ringkasan Temuan
- Batas harian untuk akun non-premium masih ditampilkan sebagai 15 di beberapa UI, padahal spesifikasi baru adalah 8.
- Panduan mode keyboard kurang jelas mengenai fungsi tiga tab: Ketik, Tanya AI, dan Baca.
- Penjelasan mode notifikasi belum memadai untuk membedakan Auto-Solve, Manual, dan Diskusi.
- Menu drawer tidak menampilkan informasi versi aplikasi dan status pengguna.
- Pesan kesalahan di fitur AI Offline masih menggunakan bahasa Inggris dan belum sepenuhnya nyaman.
- Informasi format file yang didukung sudah ditampilkan, tetapi bisa dijelaskan lebih jelas di UI upload.
- Halaman beranda belum menyampaikan secara langsung ringkasan fungsi utama aplikasi.

## Perbaikan yang Dilakukan
1. Ubah limit harian non-premium menjadi 8 di seluruh layanan batas.
2. Perbarui teks kuota pada `KeyboardModeScreen` dan `NotificationModeScreen` agar menggunakan nilai `LimitService.DAILY_LIMIT`.
3. Tambahkan panduan singkat tab keyboard di `keyboard_mode_screen.dart`.
4. Tambahkan penjelasan mode notifikasi menggunakan `ExpansionTile` di `notification_mode_screen.dart`.
5. Tambahkan informasi versi aplikasi dan status pengguna Premium/Free di `sidebar_drawer.dart`.
6. Perbarui pesan status dan error pada `offline_ai_screen.dart` ke Bahasa Indonesia yang lebih ramah.
7. Tambahkan ringkasan fungsi aplikasi di halaman utama (`home_screen.dart`).

## Catatan untuk Tim
- Pastikan backend Firestore sinkronisasi kuota harian tetap konsisten setelah perubahan limit.
- Validasi kembali logika premium agar tidak mempengaruhi kuota 8 untuk pengguna bebas.
- Pertimbangkan menambahkan unit test untuk logika kuota, jika belum ada.
