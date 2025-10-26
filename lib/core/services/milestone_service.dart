import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MilestoneService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  Future<List<Map<String, dynamic>>> fetchTasks() async {
    if (_uid == null) return [];

    final taskSnapshot = await _firestore
        .collection('tasks')
        .where('is_active', isEqualTo: true)
        .get();

    final List<Map<String, dynamic>> tasks = [];
    for (var doc in taskSnapshot.docs) {
      final data = doc.data();
      final taskId = doc.id;

      // Get user task progress
      final userTaskSnapshot = await _firestore
          .collection('user_tasks')
          .where('user_id', isEqualTo: _uid)
          .where('task_id', isEqualTo: taskId)
          .limit(1)
          .get();

      bool completed = false;
      if (userTaskSnapshot.docs.isNotEmpty) {
        final userTask = userTaskSnapshot.docs.first.data();
        completed = userTask['status'] == 'completed';
      }

      tasks.add({
        "id": taskId,
        "title": data['title'] ?? "Complete Task",
        "subtitle": data['description'] ?? "Complete this task",
        "points": data['reward']['points'] ?? 0,
        "completed": completed,
      });
    }
    return tasks;
  }
}