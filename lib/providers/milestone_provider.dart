import 'package:flutter/foundation.dart';
import 'package:giftardo/core/services/milestone_service.dart';

class MilestoneProvider with ChangeNotifier {
  final MilestoneService _service = MilestoneService();
  
  Map<String, dynamic>? _currentMilestone;
  List<Map<String, dynamic>> _previousMilestones = [];
  bool _isLoading = true;
  int _completedTasksCount = 0;

  Map<String, dynamic>? get currentMilestone => _currentMilestone;
  List<Map<String, dynamic>> get previousMilestones => _previousMilestones;
  bool get isLoading => _isLoading;
  int get completedTasksCount => _completedTasksCount;

  List<Map<String, dynamic>> get levels {
    if (_currentMilestone == null) return [];
    return _currentMilestone!['levels'] as List<Map<String, dynamic>>;
  }

  int get completedLevelsCount {
    return levels.where((level) => level['completed'] == true).length;
  }

  String get monthName {
    return _currentMilestone?['month'] ?? 'Current Month';
  }

  String get milestoneTitle {
    return _currentMilestone?['title'] ?? 'Milestone';
  }

  Future<void> loadMilestones() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Load current month milestone
      _currentMilestone = await _service.fetchCurrentMonthMilestone();
      
      // Load previous milestones
      _previousMilestones = await _service.fetchPreviousMilestones();
      
      // Get completed tasks count - use milestone-specific count if available
      if (_currentMilestone != null) {
        _completedTasksCount = _currentMilestone!['total_completed_tasks'] as int? ?? 0;
      } else {
        _completedTasksCount = 0;
      }
      
      // Update levels based on completed tasks
      if (_currentMilestone != null) {
        _refreshLevelsCanClaim();
      }
    } catch (e) {
      print('Error loading milestones: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _refreshLevelsCanClaim() {
    if (_currentMilestone == null) return;
    
    final levels = _currentMilestone!['levels'] as List<Map<String, dynamic>>;
    for (var level in levels) {
      if (!level['completed']) {
        final taskCount = level['task_count'] ?? 0;
        level['can_claim'] = _completedTasksCount >= taskCount;
      }
    }
  }

  Future<bool> claimLevelReward(String levelId, int reward) async {
    if (_currentMilestone == null) return false;
    
    final milestoneId = _currentMilestone!['id'] as String;
    final success = await _service.claimLevelReward(milestoneId, levelId, reward);
    
    if (success) {
      // Update local state
      final levelIndex = levels.indexWhere((l) => l['id'] == levelId);
      if (levelIndex != -1) {
        levels[levelIndex]['completed'] = true;
        levels[levelIndex]['can_claim'] = false;
        notifyListeners();
      }
    }
    
    return success;
  }

  Future<void> refreshMilestones() async {
    await loadMilestones();
  }
}
