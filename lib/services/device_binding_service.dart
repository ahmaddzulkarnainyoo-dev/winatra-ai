import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeviceBindingService {
  static const MethodChannel _channel = MethodChannel('winatra/service');

  static Future<String?> getAndroidId() async {
    try {
      final String androidId = await _channel.invokeMethod('getAndroidId');
      return androidId;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> bindCurrentDevice(String userId) async {
    try {
      final deviceId = await getAndroidId();
      final docRef = FirebaseFirestore.instance.collection('device_bindings').doc(userId);
      final doc = await docRef.get();

      if (doc.exists) {
        // Tidak membandingkan deviceId, langsung izinkan login
        await docRef.update({'lastActive': FieldValue.serverTimestamp()});
        return true;
      } else {
        await docRef.set({
          'deviceId': deviceId ?? 'unknown',
          'boundAt': FieldValue.serverTimestamp(),
          'lastActive': FieldValue.serverTimestamp(),
        });
        return true;
      }
    } catch (e) {
      return true; // fallback: izinkan login
    }
  }
}
