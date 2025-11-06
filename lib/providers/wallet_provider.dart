// lib/providers/wallet_provider.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WalletProvider with ChangeNotifier {
  int _walletAmount = 0;

  int get walletAmount => _walletAmount;

  WalletProvider() {
    fetchWalletAmount();
    // Optionally, listen to user changes and refetch
    FirebaseAuth.instance.authStateChanges().listen((user) {
      fetchWalletAmount();
    });
  }

  // Fetch without loader — update silently
  Future<void> fetchWalletAmount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Firestore uses local cache by default → very fast on repeat visits
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.cache)); // 👈 Try cache first

      if (doc.exists) {
        final points = doc.data()?['points'] ?? 0;
        if (points != _walletAmount) {
          _walletAmount = points;
          notifyListeners(); // Only notify if value changed
        }
      }
    } catch (e) {
      // Optional: log error, but don't show UI feedback
      // print("Failed to fetch wallet: $e");
    }
  }

  // (removed duplicate refreshFromServer)

  // Optional: Force-refresh from server (e.g., after earning points)
  Future<void> refreshFromServer() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server)); // Force server

      if (doc.exists) {
        final points = doc.data()?['points'] ?? 0;
        if (points != _walletAmount) {
          _walletAmount = points;
          notifyListeners();
        }
      }
    } catch (e) {
      // Ignore or log
    }
  }
}
