// lib/core/services/task_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TaskServicem {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  Future<List<Map<String, dynamic>>> fetchUserTasks() async {
    if (_uid == null) return [];

    // 1. Fetch all active tasks
    final taskSnapshot = await _firestore
        .collection('tasks')
        .where('is_active', isEqualTo: true)
        .get();

    final List<Map<String, dynamic>> tasks = [];

    for (var taskDoc in taskSnapshot.docs) {
      final taskData = taskDoc.data();
      final taskId = taskDoc.id;
      final requiredCount = taskData['condition']['count'] ?? 1;
      final taskType = taskData['type'] ?? 'quiz';

      // 2. Count completed user activities of this type
      final activitySnapshot = await _firestore
          .collection('user_activities')
          .where('user_id', isEqualTo: _uid)
          .where('status', isEqualTo: 'completed')
          .get();

      int completedCount = 0;
      for (var act in activitySnapshot.docs) {
        final actData = act.data();
        final activityId = actData['activity_id'];
        
        // Get activity type from sponsor_activities
        final sponsorActivity = await _firestore
            .collection('sponsor_activities')
            .doc(activityId)
            .get();
            
        if (sponsorActivity.exists && 
            sponsorActivity.data()?['type'] == taskType) {
          completedCount++;
        }
      }

      final isCompleted = completedCount >= requiredCount;

      tasks.add({
        "id": taskId,
        "title": taskData['title'] ?? "Complete Task",
        "subtitle": taskData['description'] ?? "Complete this task to earn points",
        "points": taskData['reward']['points'] ?? 0,
        "completed": isCompleted,
        "progress": requiredCount > 0 ? (completedCount / requiredCount).clamp(0.0, 1.0) : 0.0,
      });
    }

    return tasks;
  }
}