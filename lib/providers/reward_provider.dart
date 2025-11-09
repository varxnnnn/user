// lib/providers/reward_provider.dart

import 'package:flutter/foundation.dart';
import 'package:giftardo/core/services/reward_service.dart';

class RewardProvider with ChangeNotifier {
  final RewardService _service = RewardService();
  
  List<Map<String, dynamic>> _rewards = [];
  bool _isLoading = true;
  Map<String, dynamic>? _currentRewardDetail; // For detail screen

  List<Map<String, dynamic>> get rewards => _rewards;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get currentRewardDetail => _currentRewardDetail;

  Future<void> loadRewards() async {
    _isLoading = true;
    notifyListeners();
    _rewards = await _service.fetchUserRewards();
    _isLoading = false;
    notifyListeners();
  }

  // Load single reward detail for the detail screen
  Future<void> loadRewardDetail(String rewardId) async {
    _currentRewardDetail = null;
    notifyListeners();
    _currentRewardDetail = await _service.fetchRewardById(rewardId);
    notifyListeners();
  }
}