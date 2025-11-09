import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class CreateMilestoneTab extends StatefulWidget {
  const CreateMilestoneTab({super.key});

  @override
  _CreateMilestoneTabState createState() => _CreateMilestoneTabState();
}

class _CreateMilestoneTabState extends State<CreateMilestoneTab> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController rewardController = TextEditingController();
  
  String? sponsorId;
  bool loading = false;

  // Predefined 10 levels for each milestone
  final List<Map<String, dynamic>> defaultLevels = [
    {'task_count': 5, 'description': 'Complete 5 tasks'},
    {'task_count': 10, 'description': 'Complete 10 tasks'},
    {'task_count': 20, 'description': 'Complete 20 tasks'},
    {'task_count': 30, 'description': 'Complete 30 tasks'},
    {'task_count': 50, 'description': 'Complete 50 tasks'},
    {'task_count': 75, 'description': 'Complete 75 tasks'},
    {'task_count': 100, 'description': 'Complete 100 tasks'},
    {'task_count': 150, 'description': 'Complete 150 tasks'},
    {'task_count': 200, 'description': 'Complete 200 tasks'},
    {'task_count': 250, 'description': 'Complete 250 tasks'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSponsorId();
    // Set default reward to 10
    rewardController.text = '10';
  }

  Future<void> _loadSponsorId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      sponsorId = prefs.getString('sponsorId');
    });
  }

  String _getCurrentMonthName() {
    return DateFormat('MMMM yyyy').format(DateTime.now());
  }

  Future<void> createMilestone() async {
    if (titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    final reward = int.tryParse(rewardController.text) ?? 10;

    if (sponsorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sponsor ID not found')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final currentMonth = _getCurrentMonthName();
      
      // Check if milestone already exists for this month
      final existingMilestone = await FirebaseFirestore.instance
          .collection('milestones')
          .where('month', isEqualTo: currentMonth)
          .limit(1)
          .get();

      if (existingMilestone.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Milestone already exists for $currentMonth'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => loading = false);
        return;
      }

      // Create milestone document
      final milestoneRef = FirebaseFirestore.instance.collection('milestones').doc();
      final milestoneId = milestoneRef.id;

      // Create milestone data (for all users, not assigned to specific user)
      final milestoneData = {
        'title': titleController.text.trim(),
        'month': currentMonth,
        'reward': reward, // Default reward per level
        'createdBy': sponsorId,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await milestoneRef.set(milestoneData);

      // Create 10 levels for this milestone
      final batch = FirebaseFirestore.instance.batch();

      for (int i = 0; i < defaultLevels.length; i++) {
        final level = defaultLevels[i];
        final levelRef = FirebaseFirestore.instance
            .collection('milestones')
            .doc(milestoneId)
            .collection('levels')
            .doc();

        final levelData = {
          'milestone_id': milestoneId,
          'level_number': i + 1,
          'task_count': level['task_count'],
          'description': level['description'],
          'reward': reward, // 10 coins per level
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        };

        batch.set(levelRef, levelData);
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Milestone created successfully for $currentMonth!'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear form
      titleController.clear();
      rewardController.text = '10';
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating milestone: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentMonth = _getCurrentMonthName();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create Milestone for $currentMonth',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This milestone will be available for all users',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title *',
                      hintText: 'e.g., November Challenge',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: rewardController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Reward per Level (coins)',
                      hintText: 'Default: 10',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Levels Preview
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Milestone Levels (10 levels)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...defaultLevels.asMap().entries.map((entry) {
                            final index = entry.key;
                            final level = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      level['description'],
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  Text(
                                    '+${rewardController.text.isEmpty ? '10' : rewardController.text} coins',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: loading ? null : createMilestone,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Create Milestone',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    rewardController.dispose();
    super.dispose();
  }
}
