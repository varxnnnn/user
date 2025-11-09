import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String? sponsorId;
  DateTime selectedMonth = DateTime.now();
  bool showPreviousMilestones = false;

  @override
  void initState() {
    super.initState();
    _loadSponsorId();
  }

  Future<void> _loadSponsorId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      sponsorId = prefs.getString('sponsorId');
    });
  }

  Future<void> _createMilestone(BuildContext context) async {
    if (sponsorId == null) return;

    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController targetController = TextEditingController();
    String? selectedRewardId;
    int rewardQuantity = 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create New Milestone'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Milestone Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: targetController,
                  decoration: const InputDecoration(
                    labelText: 'Target Completions',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('sponsor_rewards')
                      .where('sponsor_id', isEqualTo: sponsorId)
                      .where('status', isEqualTo: 'active')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }

                    final rewards = snapshot.data!.docs;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Select Reward:'),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: selectedRewardId,
                          items: rewards.map((reward) {
                            final data = reward.data() as Map<String, dynamic>;
                            return DropdownMenuItem(
                              value: reward.id,
                              child: Text('${data['title']} (Available: ${data['available_quantity']})'),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => selectedRewardId = value),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Reward Quantity per Achievement',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) => setState(() => 
                            rewardQuantity = int.tryParse(value) ?? 1
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (titleController.text.isEmpty ||
                    descriptionController.text.isEmpty ||
                    targetController.text.isEmpty ||
                    selectedRewardId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }

                final milestone = {
                  'title': titleController.text,
                  'description': descriptionController.text,
                  'target': int.parse(targetController.text),
                  'current_completions': 0,
                  'reward_id': selectedRewardId,
                  'reward_quantity': rewardQuantity,
                  'created_at': Timestamp.now(),
                  'month': Timestamp.fromDate(DateTime(
                    selectedMonth.year,
                    selectedMonth.month,
                    1,
                  )),
                  'status': 'active',
                  'sponsor_id': sponsorId,
                };

                try {
                  await FirebaseFirestore.instance
                      .collection('sponsor_milestones')
                      .add(milestone);
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Milestone created successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error creating milestone: $e')),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (sponsorId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Milestones & Reports'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Current Milestones'),
              Tab(text: 'Previous Milestones'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_month),
              onPressed: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: selectedMonth,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  initialDatePickerMode: DatePickerMode.year,
                );
                if (picked != null) {
                  setState(() {
                    selectedMonth = picked;
                  });
                }
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildCurrentMilestones(),
            _buildPreviousMilestones(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _createMilestone(context),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildCurrentMilestones() {
    final startOfMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final endOfMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sponsor_milestones')
          .where('sponsor_id', isEqualTo: sponsorId)
          .where('month', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
          .where('month', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final milestones = snapshot.data!.docs;
        
        if (milestones.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'No milestones for ${DateFormat('MMMM yyyy').format(selectedMonth)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _createMilestone(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Milestone'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: milestones.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final milestone = milestones[index].data() as Map<String, dynamic>;
            final progress = (milestone['current_completions'] / milestone['target'] * 100).toInt();

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            milestone['title'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text('$progress%'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(milestone['description']),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: milestone['current_completions'] / milestone['target'],
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${milestone['current_completions']}/${milestone['target']} completions',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('sponsor_rewards')
                          .doc(milestone['reward_id'])
                          .get(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox();
                        
                        final reward = snapshot.data!.data() as Map<String, dynamic>;
                        return Text(
                          'Reward: ${reward['title']} (${milestone['reward_quantity']} per achievement)',
                          style: const TextStyle(color: Colors.blue),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPreviousMilestones() {
    final startOfMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sponsor_milestones')
          .where('sponsor_id', isEqualTo: sponsorId)
          .where('month', isLessThan: Timestamp.fromDate(startOfMonth))
          .orderBy('month', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final milestones = snapshot.data!.docs;
        
        if (milestones.isEmpty) {
          return const Center(
            child: Text('No previous milestones found'),
          );
        }

        // Group milestones by month
        final Map<String, List<DocumentSnapshot>> groupedMilestones = {};
        for (var milestone in milestones) {
          final data = milestone.data() as Map<String, dynamic>;
          final month = DateFormat('MMMM yyyy').format((data['month'] as Timestamp).toDate());
          groupedMilestones.putIfAbsent(month, () => []);
          groupedMilestones[month]!.add(milestone);
        }

        return ListView.builder(
          itemCount: groupedMilestones.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final month = groupedMilestones.keys.elementAt(index);
            final monthMilestones = groupedMilestones[month]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    month,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                ...monthMilestones.map((milestone) {
                  final data = milestone.data() as Map<String, dynamic>;
                  final progress = (data['current_completions'] / data['target'] * 100).toInt();
                  final isCompleted = data['current_completions'] >= data['target'];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      title: Text(data['title']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['description']),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: data['current_completions'] / data['target'],
                            backgroundColor: Colors.grey[200],
                            color: isCompleted ? Colors.green : null,
                          ),
                          Text(
                            '$progress% Complete (${data['current_completions']}/${data['target']})',
                            style: TextStyle(
                              color: isCompleted ? Colors.green : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            );
          },
        );
      },
    );
  }
}
