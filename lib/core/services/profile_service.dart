// lib/core/services/profile_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>> fetchUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("No user logged in");

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) throw Exception("User profile not found");

    var userData = doc.data()!;

    // 🔸 Generate referral code if missing
    if (userData['referralCode'] == null) {
      String code = _generateReferralCode(userData['name'] ?? 'User', user.uid);
      await _firestore.collection('users').doc(user.uid).update({
        'referralCode': code,
        'updated_at': FieldValue.serverTimestamp(),
      });
      userData['referralCode'] = code;
    }

    // 🔸 Fetch TOTAL REWARDS EARNED by counting the user's redemptions
    int totalRewards = 0;
    try {
      final redemptions = await _firestore
          .collection('redemptions')
          .where('user_id', isEqualTo: user.uid)
          .get();
      // The total number of rewards a user has earned is simply the count of their redemption documents.
      totalRewards = redemptions.docs.length;
    } catch (e) {
      // If there's an error, we'll default to 0.
      // It's good practice to log this error.
      print('Error fetching total rewards: $e');
      totalRewards = 0;
    }

    userData['totalRewards'] = totalRewards;
    return userData;
  }

  String _generateReferralCode(String name, String uid) {
    String namePart = name.length >= 4
        ? name.substring(0, 4).toUpperCase()
        : name.toUpperCase();
    String uidPart = uid.length >= 4
        ? uid.substring(uid.length - 4).toUpperCase()
        : uid.toUpperCase();
    return '$namePart$uidPart';
  }

  Future<void> updateNotificationPreference(bool enabled) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'notifications_enabled': enabled,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> updateLanguage(String language) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'language': language,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
  }
}
