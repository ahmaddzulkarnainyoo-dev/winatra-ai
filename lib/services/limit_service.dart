import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LimitService {
  static const int DAILY_LIMIT = 15;
  static const String PREFS_NAME = "winatra_prefs";
  static const String KEY_REMAINING = "remaining_quota";
  static const String KEY_IS_PREMIUM = "is_premium";
  static const String KEY_PREMIUM_EXPIRY = "premium_expiry";

  /// Cek apakah user adalah premium dan masih berlaku
  static Future<bool> isPremium() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data == null) return false;

      final isPremiumFlag = data['isPremium'] ?? false;
      if (!isPremiumFlag) return false;

      final premiumExpiry = (data['premiumExpiry'] as Timestamp?)?.toDate();
      if (premiumExpiry == null) return true; // Jika tidak ada expiry, premium selamanya
      return premiumExpiry.isAfter(DateTime.now());
    } catch (e) {
      print('LimitService: Error checking isPremium: $e');
      return false;
    }
  }

  /// Sinkronisasi status premium ke SharedPreferences
  static Future<void> syncPremiumStatusToPrefs() async {
    final premium = await isPremium();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(KEY_IS_PREMIUM, premium);
    print('LimitService: syncPremiumStatusToPrefs -> is_premium = $premium');
  }

  static Future<void> syncRemainingToPrefs() async {
    final remaining = await getRemainingQuota();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(KEY_REMAINING, remaining);
    print('LimitService: syncRemainingToPrefs -> remaining_quota = $remaining');
  }

  static Future<int> getRemainingQuota() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;
    
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (data == null) return 0;

      // Cek premium
      final isPremiumFlag = data['isPremium'] ?? false;
      if (isPremiumFlag) {
        final premiumExpiry = (data['premiumExpiry'] as Timestamp?)?.toDate();
        if (premiumExpiry == null || premiumExpiry.isAfter(DateTime.now())) {
          return -1; // -1 = unlimited (premium)
        }
      }

      // Cek daily limit
      final lastDate = data['lastCountDate'] as Timestamp?;
      final today = DateTime.now().toUtc();
      int dailyCount = data['dailyCount'] ?? 0;

      if (lastDate == null || lastDate.toDate().day != today.day) {
        dailyCount = 0;
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'dailyCount': 0,
          'lastCountDate': Timestamp.fromDate(today),
        });
      }

      final remaining = DAILY_LIMIT - dailyCount;
      return remaining > 0 ? remaining : 0;
    } catch (e) {
      print('LimitService: Error getting remaining quota: $e');
      return 0;
    }
  }

  static Future<bool> checkLimit() async {
    final remaining = await getRemainingQuota();
    if (remaining == -1) return true; // Premium, unlimited
    final ok = remaining > 0;
    await syncRemainingToPrefs();
    return ok;
  }

  /// Cek limit dan kurangi quota jika berhasil
  static Future<bool> checkAndDecrementLimit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    // Cek premium dulu
    final premium = await isPremium();
    if (premium) {
      print('LimitService: User is premium, no limit');
      return true;
    }

    // Cek dan kurangi limit
    final remaining = await getRemainingQuota();
    if (remaining <= 0) {
      print('LimitService: Limit exceeded');
      return false;
    }

    // Increment count
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'dailyCount': FieldValue.increment(1),
    });
    
    // Update local
    await syncRemainingToPrefs();
    print('LimitService: Limit decremented');
    return true;
  }

  static Future<void> incrementCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'dailyCount': FieldValue.increment(1),
    });
    await syncRemainingToPrefs();
    print('LimitService: incrementCount called');
  }

  /// Update remaining quota di Firestore
  static Future<void> updateFirestoreRemaining(int newRemaining) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'remainingQuota': newRemaining,
      });
      print('LimitService: Updated Firestore remaining = $newRemaining');
    } catch (e) {
      print('LimitService: Error updating Firestore remaining: $e');
    }
  }
}