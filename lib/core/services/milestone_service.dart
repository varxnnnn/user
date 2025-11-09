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
      final now = DateTime.now();
      
      // First, check and update expired milestones
      await _autoExpireMilestones();
      
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
      final milestoneCreatedAt = milestoneData['createdAt'] as Timestamp?;
      final endDate = milestoneData['endDate'] as Timestamp?;
      
      // Check if milestone has ended
      if (endDate != null && now.isAfter(endDate.toDate())) {
        print('⚠️ Milestone has ended, updating status...');
        await _firestore.collection('milestones').doc(milestoneId).update({
          'status': 'ended',
          'endedAt': FieldValue.serverTimestamp(),
        });
        return null; // Don't show ended milestone as current
      }

      // Fetch levels for this milestone
      final levelsSnapshot = await _firestore
          .collection('milestones')
          .doc(milestoneId)
          .collection('levels')
          .orderBy('level_number')
          .get();

      // Get user's milestone progress (includes tracked activity count)
      final userProgressDoc = await _firestore
          .collection('milestones')
          .doc(milestoneId)
          .collection('user_progress')
          .doc(_uid)
          .get();

      // Use tracked activity count (more reliable than querying all collections)
      final completedTasksCount = userProgressDoc.exists
          ? (userProgressDoc.data()?['total_activities'] as int? ?? 0)
          : 0;
      
      print('📊 User progress - Activities: $completedTasksCount');

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
  
  // Track activity completion for milestone progress (NEW TRACKING SYSTEM)
  Future<void> trackActivityCompletion({
    required String activityId,
    required String activityType,
  }) async {
    if (_uid == null) return;

    try {
      final currentMonth = _getCurrentMonthName();
      
      // Get current active milestone
      final milestoneSnapshot = await _firestore
          .collection('milestones')
          .where('month', isEqualTo: currentMonth)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (milestoneSnapshot.docs.isEmpty) {
        print('⚠️ No active milestone found for $currentMonth');
        return;
      }

      final milestoneDoc = milestoneSnapshot.docs.first;
      final milestoneId = milestoneDoc.id;
      final milestoneCreatedAt = milestoneDoc.data()['createdAt'] as Timestamp?;
      
      if (milestoneCreatedAt == null) return;
      
      final now = Timestamp.now();
      
      // Only track if activity was completed AFTER milestone creation
      if (now.millisecondsSinceEpoch <= milestoneCreatedAt.millisecondsSinceEpoch) {
        print('⏰ Activity completed before milestone, not tracking');
        return;
      }

      print('\n📌 Tracking activity for milestone...');
      print('   Activity: $activityType ($activityId)');
      print('   Milestone: $milestoneId');
      print('   User: $_uid');

      // Record in participant_activities collection
      await _firestore
          .collection('milestones')
          .doc(milestoneId)
          .collection('participant_activities')
          .doc('${_uid}_$activityId')
          .set({
        'user_id': _uid,
        'activity_id': activityId,
        'activity_type': activityType,
        'completed_at': FieldValue.serverTimestamp(),
        'milestone_id': milestoneId,
        'month': currentMonth,
      });

      // Update user's total activity count
      final userProgressRef = _firestore
          .collection('milestones')
          .doc(milestoneId)
          .collection('user_progress')
          .doc(_uid);
          
      final userProgressDoc = await userProgressRef.get();
      final currentCount = userProgressDoc.exists 
          ? (userProgressDoc.data()?['total_activities'] as int? ?? 0)
          : 0;
      
      await userProgressRef.set({
        'total_activities': currentCount + 1,
        'last_activity_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      print('✅ Tracked! Total activities: ${currentCount + 1}\n');
      
    } catch (e) {
      print('❌ Error tracking milestone activity: $e');
    }
  }

  // Claim reward for completing a level
  Future<bool> claimLevelReward(String milestoneId, String levelId, int reward) async {
    if (_uid == null) return false;

    try {
      print('\n🎯 Attempting to claim level reward...');
      print('   Milestone ID: $milestoneId');
      print('   Level ID: $levelId');
      print('   Reward: $reward coins');
      
      // Get milestone creation timestamp
      final milestoneDoc = await _firestore
          .collection('milestones')
          .doc(milestoneId)
          .get();
      
      if (!milestoneDoc.exists) {
        print('❌ Milestone not found');
        return false;
      }
      
      final milestoneCreatedAt = milestoneDoc.data()?['createdAt'] as Timestamp?;
      
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
        print('⚠️ Level already claimed');
        return false; // Already claimed
      }

      // Get user's total completed tasks from tracked activities (more reliable)
      final completedTasksCount = userProgressDoc.exists
          ? (userProgressDoc.data()?['total_activities'] as int? ?? 0)
          : 0;
      print('   Tasks completed (from tracking): $completedTasksCount');

      // Get level requirement
      final levelDoc = await _firestore
          .collection('milestones')
          .doc(milestoneId)
          .collection('levels')
          .doc(levelId)
          .get();

      if (!levelDoc.exists) {
        print('❌ Level not found');
        return false;
      }

      final levelData = levelDoc.data()!;
      final taskCount = levelData['task_count'] as int? ?? 0;
      final levelNumber = levelData['level_number'] as int? ?? 0;
      print('   Required tasks: $taskCount');

      // Check if user has completed enough tasks
      if (completedTasksCount < taskCount) {
        print('❌ Not enough tasks completed ($completedTasksCount < $taskCount)');
        return false; // Not enough tasks completed
      }

      print('✅ Requirements met! Claiming reward...');
      
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
        print('✅ Added $reward coins to wallet');
      }
      
      // Record milestone reward in user's wallet history
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('milestone_rewards')
          .add({
        'milestone_id': milestoneId,
        'level_id': levelId,
        'level_number': levelNumber,
        'reward': reward,
        'claimed_at': FieldValue.serverTimestamp(),
        'month': milestoneDoc.data()?['month'] ?? '',
        'milestone_title': milestoneDoc.data()?['title'] ?? 'Milestone',
      });
      print('✅ Recorded in milestone_rewards collection\n');

      return true;
    } catch (e, stackTrace) {
      print('❌ Error claiming level reward: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  // Get user's total completed tasks count AFTER milestone was created
  Future<int> getCompletedTasksAfterMilestoneCreation(Timestamp? milestoneCreatedAt) async {
    if (_uid == null) return 0;
    if (milestoneCreatedAt == null) return 0;

    try {
      final now = DateTime.now();
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      final creationDate = milestoneCreatedAt.toDate();

      int totalCount = 0;

      // Count poll attempts completed AFTER milestone creation
      final pollAttempts = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('poll_attempts')
          .where('timestamp', isGreaterThan: milestoneCreatedAt)
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .where('isAbandoned', isEqualTo: false)
          .get();
      totalCount += pollAttempts.docs.length;

      // Count quiz attempts completed AFTER milestone creation
      final quizAttempts = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('quiz_attempts')
          .where('timestamp', isGreaterThan: milestoneCreatedAt)
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();
      totalCount += quizAttempts.docs.length;

      // Count survey attempts completed AFTER milestone creation
      final surveyAttempts = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('survey_attempts')
          .where('timestamp', isGreaterThan: milestoneCreatedAt)
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();
      totalCount += surveyAttempts.docs.length;

      // Count YouTube/advertise video attempts completed AFTER milestone creation
      final youtubeAttempts = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('youtube_attempts')
          .where('timestamp', isGreaterThan: milestoneCreatedAt)
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .get();
      totalCount += youtubeAttempts.docs.length;

      print('📊 Milestone tasks count: $totalCount (created at: $creationDate)');
      return totalCount;
    } catch (e) {
      print('Error getting completed tasks after milestone creation: $e');
      return 0;
    }
  }

  // Get user's total completed tasks count for current month (kept for backward compatibility)
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
  
  // Auto-expire milestones that have passed their end date
  Future<void> _autoExpireMilestones() async {
    try {
      final now = DateTime.now();
      final expiredMilestones = await _firestore
          .collection('milestones')
          .where('status', isEqualTo: 'active')
          .where('endDate', isLessThan: Timestamp.fromDate(now))
          .get();

      if (expiredMilestones.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in expiredMilestones.docs) {
          batch.update(doc.reference, {
            'status': 'ended',
            'endedAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
        print('✅ Auto-expired ${expiredMilestones.docs.length} milestone(s)');
      }
    } catch (e) {
      print('Error auto-expiring milestones: $e');
    }
  }
  
  // Get user's milestone rewards history for wallet display
  Future<List<Map<String, dynamic>>> getMilestoneRewardsHistory() async {
    if (_uid == null) return [];

    try {
      final rewardsSnapshot = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('milestone_rewards')
          .orderBy('claimed_at', descending: true)
          .get();

      return rewardsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'milestone_title': data['milestone_title'] ?? 'Milestone',
          'month': data['month'] ?? '',
          'level_number': data['level_number'] ?? 0,
          'reward': data['reward'] ?? 0,
          'claimed_at': data['claimed_at'] as Timestamp?,
        };
      }).toList();
    } catch (e) {
      print('Error getting milestone rewards history: $e');
      return [];
    }
  }
}
