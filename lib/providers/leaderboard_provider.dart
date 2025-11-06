import 'package:flutter/foundation.dart';
import 'package:giftardo/core/services/leaderboard_service.dart';

class LeaderboardProvider with ChangeNotifier {
  final LeaderboardService _service = LeaderboardService();
  
  List<Map<String, dynamic>> _leaders = [];
  bool _isLoading = true;

  List<Map<String, dynamic>> get leaders => _leaders;
  bool get isLoading => _isLoading;

  Future<void> loadLeaderboard() async {
    _isLoading = true;
    notifyListeners();
    _leaders = await _service.fetchLeaderboard();
    _isLoading = false;
    notifyListeners();
  }
}