import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static final FirebaseRemoteConfig remoteConfig = FirebaseRemoteConfig.instance;

  static Future<void> initialize() async {
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(hours: 1), // bisa diubah untuk testing
    ));
    await remoteConfig.fetchAndActivate();
  }

  static Future<void> checkForUpdate(BuildContext context) async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String currentVersion = packageInfo.version;

    String minVersion = remoteConfig.getString('min_version');
    bool forceUpdate = remoteConfig.getBool('force_update');
    String updateUrl = remoteConfig.getString('update_url');

    // Jika min_version kosong atau tidak ada, skip
    if (minVersion.isEmpty) return;

    if (_isVersionLower(currentVersion, minVersion)) {
      _showUpdateDialog(context, forceUpdate, updateUrl);
    }
  }

  static bool _isVersionLower(String current, String min) {
    List<int> currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> minParts = min.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < currentParts.length; i++) {
      if (i >= minParts.length) return false;
      if (currentParts[i] < minParts[i]) return true;
      if (currentParts[i] > minParts[i]) return false;
    }
    return currentParts.length < minParts.length; // jika current lebih pendek dari min, anggap lebih rendah
  }

  static void _showUpdateDialog(BuildContext context, bool force, String url) {
    showDialog(
      context: context,
      barrierDismissible: !force,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(force ? "Update Wajib" : "Update Tersedia"),
          content: Text(force
              ? "Aplikasi versi lama sudah tidak didukung. Silakan update ke versi terbaru."
              : "Ada versi baru dengan fitur menarik. Update sekarang?"),
          actions: [
            if (!force)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Nanti"),
              ),
            TextButton(
              onPressed: () async {
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                }
                if (force) {
                  // Jika force, tutup aplikasi? atau tetap di dialog
                  // Tapi lebih baik izinkan user buka link, dialog tetap ada sampai update.
                }
                Navigator.of(context).pop(); // tutup dialog
              },
              child: const Text("Update"),
            ),
          ],
        );
      },
    );
  }
}