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
  final TextEditingController defaultRewardController = TextEditingController();
  
  String? sponsorId;
  bool loading = false;

  // Editable levels - sponsor can modify task count and rewards
  List<Map<String, dynamic>> editableLevels = [
    {'task_count': 5, 'description': 'Complete 5 tasks', 'reward': 10},
    {'task_count': 10, 'description': 'Complete 10 tasks', 'reward': 10},
    {'task_count': 20, 'description': 'Complete 20 tasks', 'reward': 10},
    {'task_count': 30, 'description': 'Complete 30 tasks', 'reward': 10},
    {'task_count': 50, 'description': 'Complete 50 tasks', 'reward': 10},
    {'task_count': 75, 'description': 'Complete 75 tasks', 'reward': 10},
    {'task_count': 100, 'description': 'Complete 100 tasks', 'reward': 10},
    {'task_count': 150, 'description': 'Complete 150 tasks', 'reward': 10},
    {'task_count': 200, 'description': 'Complete 200 tasks', 'reward': 10},
    {'task_count': 250, 'description': 'Complete 250 tasks', 'reward': 10},
  ];

  @override
  void initState() {
    super.initState();
    _loadSponsorId();
    defaultRewardController.text = '10';
  }

  void _updateAllLevelRewards() {
    final reward = int.tryParse(defaultRewardController.text) ?? 10;
    setState(() {
      for (var level in editableLevels) {
        level['reward'] = reward;
      }
    });
  }
  
  void _updateLevelTaskCount(int index, String value) {
    final taskCount = int.tryParse(value) ?? editableLevels[index]['task_count'];
    setState(() {
      editableLevels[index]['task_count'] = taskCount;
      editableLevels[index]['description'] = 'Complete $taskCount tasks';
    });
  }
  
  void _updateLevelReward(int index, String value) {
    final reward = int.tryParse(value) ?? editableLevels[index]['reward'];
    setState(() {
      editableLevels[index]['reward'] = reward;
    });
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

    final reward = int.tryParse(defaultRewardController.text) ?? 10;

    if (sponsorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sponsor ID not found')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final currentMonth = _getCurrentMonthName();
      final now = DateTime.now();
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      
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
        'endDate': Timestamp.fromDate(endOfMonth),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await milestoneRef.set(milestoneData);

      // Create 10 levels for this milestone
      final batch = FirebaseFirestore.instance.batch();

      for (int i = 0; i < editableLevels.length; i++) {
        final level = editableLevels[i];
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
          'reward': level['reward'], // Use individual level reward
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
      defaultRewardController.text = '10';
      // Reset levels to default
      setState(() {
        editableLevels = [
          {'task_count': 5, 'description': 'Complete 5 tasks', 'reward': 10},
          {'task_count': 10, 'description': 'Complete 10 tasks', 'reward': 10},
          {'task_count': 20, 'description': 'Complete 20 tasks', 'reward': 10},
          {'task_count': 30, 'description': 'Complete 30 tasks', 'reward': 10},
          {'task_count': 50, 'description': 'Complete 50 tasks', 'reward': 10},
          {'task_count': 75, 'description': 'Complete 75 tasks', 'reward': 10},
          {'task_count': 100, 'description': 'Complete 100 tasks', 'reward': 10},
          {'task_count': 150, 'description': 'Complete 150 tasks', 'reward': 10},
          {'task_count': 200, 'description': 'Complete 200 tasks', 'reward': 10},
          {'task_count': 250, 'description': 'Complete 250 tasks', 'reward': 10},
        ];
      });
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
                  
                  // Default Reward for All Levels
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: defaultRewardController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Default Reward per Level (coins only)',
                            hintText: '10',
                            border: OutlineInputBorder(),
                            helperText: 'Set same reward for all levels',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _updateAllLevelRewards,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        ),
                        child: const Text('Apply to All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Editable Levels
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Customize Milestone Levels',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${editableLevels.length} levels',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Set task count and coin reward for each level',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...editableLevels.asMap().entries.map((entry) {
                            final index = entry.key;
                            final level = entry.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  // Level Number
                                  Container(
                                    width: 36,
                                    height: 36,
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
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  
                                  // Task Count Input
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Tasks',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        isDense: true,
                                      ),
                                      controller: TextEditingController(
                                        text: level['task_count'].toString(),
                                      ),
                                      onChanged: (value) => _updateLevelTaskCount(index, value),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  
                                  // Reward Input
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: 'Coins',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        isDense: true,
                                        prefixIcon: Icon(Icons.monetization_on, size: 16),
                                      ),
                                      controller: TextEditingController(
                                        text: level['reward'].toString(),
                                      ),
                                      onChanged: (value) => _updateLevelReward(index, value),
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
    defaultRewardController.dispose();
    super.dispose();
  }
}
