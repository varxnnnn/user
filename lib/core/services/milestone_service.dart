import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class MilestoneService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  String _getCurrentMonthName() {
    return DateFormat('MMMM yyyy').format(DateTime.now());
  }

  // Fetch current month's milestone with levels
  Future<Map<String, dynamic>?> fetchCurrentMonthMilestone() async {
    if (_uid == null) return null;

    try {
      final currentMonth = _getCurrentMonthName();
      
      final milestoneSnapshot = await _firestore
          .collection('milestones')
          .where('month', isEqualTo: currentMonth)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (milestoneSnapshot.docs.isEmpty) return null;

      final milestoneDoc = milestoneSnapshot.docs.first;
      final milestoneData = milestoneDoc.data();
      final milestoneId = milestoneDoc.id;

      // Fetch levels for this milestone
      final levelsSnapshot = await _firestore
          .collection('milestones')
          .doc(milestoneId)
          .collection('levels')
          .orderBy('level_number')
          .get();

      // Get user's total completed tasks count for this month
      final completedTasksCount = await getCurrentMonthCompletedTasks();

      // Get user's milestone progress (completed levels)
      final userProgressDoc = await _firestore
          .collection('milestones')
          .doc(milestoneId)
          .collection('user_progress')
          .doc(_uid)
          .get();

      final completedLevelIds = userProgressDoc.exists
          ? (userProgressDoc.data()?['completed_level_ids'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              []
          : [];

      // Build levels list with completion status
      final List<Map<String, dynamic>> levels = [];
      for (var levelDoc in levelsSnapshot.docs) {
        final levelData = levelDoc.data();
        final levelId = levelDoc.id;
        final levelNumber = levelData['level_number'] ?? 0;
        final taskCount = levelData['task_count'] ?? 0;
        final isCompleted = completedLevelIds.contains(levelId);
        final canClaim = !isCompleted && completedTasksCount >= taskCount;

        levels.add({
          'id': levelId,
          'milestone_id': milestoneId,
          'level_number': levelNumber,
          'description': levelData['description'] ?? '',
          'task_count': taskCount,
          'reward': levelData['reward'] ?? 10,
          'completed': isCompleted,
          'can_claim': canClaim,
        });
      }

      return {
        'id': milestoneId,
        'title': milestoneData['title'] ?? 'Milestone',
        'month': milestoneData['month'] ?? currentMonth,
        'levels': levels,
        'total_completed_tasks': completedTasksCount,
      };
    } catch (e) {
      print('Error fetching milestone: $e');
      return null;
    }
  }

  // Fetch all previous milestones
  Future<List<Map<String, dynamic>>> fetchPreviousMilestones() async {
    if (_uid == null) return [];

    try {
      final currentMonth = _getCurrentMonthName();
      
      // Get all active milestones
      final snapshot = await _firestore
          .collection('milestones')
          .where('status', isEqualTo: 'active')
          .get();

      final List<Map<String, dynamic>> milestones = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final milestoneMonth = data['month'] as String? ?? '';
        
        // Filter out current month client-side
        if (milestoneMonth == currentMonth) continue;
        
        final milestoneId = doc.id;
        
        // Get user progress for this milestone
        final userProgressDoc = await _firestore
            .collection('milestones')
            .doc(milestoneId)
            .collection('user_progress')
            .doc(_uid)
            .get();

        final completedLevelIds = userProgressDoc.exists
            ? (userProgressDoc.data()?['completed_level_ids'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                []
            : [];

        // Count total levels
        final levelsSnapshot = await _firestore
            .collection('milestones')
            .doc(milestoneId)
            .collection('levels')
            .get();

        milestones.add({
          'id': milestoneId,
          'title': data['title'] ?? 'Milestone',
          'month': milestoneMonth,
          'completed_levels': completedLevelIds.length,
          'total_levels': levelsSnapshot.docs.length,
          'total_earned': completedLevelIds.length * (data['reward'] ?? 10),
        });
      }

      // Sort by month descending
      milestones.sort((a, b) => (b['month'] as String).compareTo(a['month'] as String));

      return milestones;
    } catch (e) {
      print('Error fetching previous milestones: $e');
      return [];
    }
  }

  // Claim reward for completing a level
  Future<bool> claimLevelReward(String milestoneId, String levelId, int reward) async {
    if (_uid == null) return false;

    try {
      // Check if already claimed
      final userProgressDoc = await _firestore
          .collection('milestones')
          .doc(milestoneId)
          .collection('user_progress')
          .doc(_uid)
          .get();

      final completedLevelIds = userProgressDoc.exists
          ? (userProgressDoc.data()?['completed_level_ids'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              []
          : [];

      if (completedLevelIds.contains(levelId)) {
        return false; // Already claimed
      }

      // Get user's total completed tasks for this month
      final completedTasksCount = await getCurrentMonthCompletedTasks();

      // Get level requirement
      final levelDoc = await _firestore
          .collection('milestones')
          .doc(milestoneId)
          .collection('levels')
          .doc(levelId)
          .get();

      if (!levelDoc.exists) return false;

      final levelData = levelDoc.data()!;
      final taskCount = levelData['task_count'] as int? ?? 0;

      // Check if user has completed enough tasks
      if (completedTasksCount < taskCount) {
        return false; // Not enough tasks completed
      }

      // Update user progress
      completedLevelIds.add(levelId);
      await _firestore
          .collection('milestones')
          .doc(milestoneId)
          .collection('user_progress')
          .doc(_uid)
          .set({
        'completed_level_ids': completedLevelIds,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update user wallet (add coins)
      final userDoc = await _firestore.collection('users').doc(_uid).get();
      if (userDoc.exists) {
        final currentCoins = userDoc.data()?['totalCoins'] ?? 0;
        final currentPoints = userDoc.data()?['points'] ?? 0;
        
        await _firestore.collection('users').doc(_uid).update({
          'totalCoins': currentCoins + reward,
          'points': currentPoints + reward,
        });
      }

      return true;
    } catch (e) {
      print('Error claiming level reward: $e');
      return false;
    }
  }

  // Get user's total completed tasks count for current month
  Future<int> getCurrentMonthCompletedTasks() async {
    if (_uid == null) return 0;

    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      int totalCount = 0;

      // Count poll attempts
      final pollAttempts = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('poll_attempts')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .where('isAbandoned', isEqualTo: false)
          .get();
      totalCount += pollAttempts.docs.length;

      // Count quiz attempts  
      final quizAttempts = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('quiz_attempts')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();
      totalCount += quizAttempts.docs.length;

      // Count survey attempts
      final surveyAttempts = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('survey_attempts')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();
      totalCount += surveyAttempts.docs.length;

      // Count YouTube/advertise video attempts
      final youtubeAttempts = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('youtube_attempts')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();
      totalCount += youtubeAttempts.docs.length;

      return totalCount;
    } catch (e) {
      print('Error getting completed tasks: $e');
      return 0;
    }
  }
}
