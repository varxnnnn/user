import 'package:flutter/foundation.dart';
import 'package:giftardo/core/services/leaderboard_service.dart';

class LeaderboardProvider with ChangeNotifier {
  final LeaderboardService _service = LeaderboardService();

  List<Map<String, dynamic>> _leaderboard = [];
  bool _isLoading = true;
  String? _error;
  int? _currentUserRank;

  // Getters
  List<Map<String, dynamic>> get leaderboard => _leaderboard;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int? get currentUserRank => _currentUserRank;

  /// Loads the leaderboard data from the service
  Future<void> loadLeaderboard() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _service.fetchLeaderboard();

      // Assuming the API or service returns a list of maps with structure:
      // {
      //   "rank": int,
      //   "name": String,
      //   "points": int,
      //   "isCurrentUser": bool
      // }

      _leaderboard = List<Map<String, dynamic>>.from(data);

      // Identify the current user rank (if present)
      final currentUser = _leaderboard.firstWhere(
            (entry) => entry['isCurrentUser'] == true,
        orElse: () => {},
      );

      _currentUserRank = currentUser.isNotEmpty ? currentUser['rank'] as int? : null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
