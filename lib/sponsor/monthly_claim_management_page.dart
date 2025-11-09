import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class MonthlyClaimManagementPage extends StatefulWidget {
  const MonthlyClaimManagementPage({Key? key}) : super(key: key);

  @override
  State<MonthlyClaimManagementPage> createState() => _MonthlyClaimManagementPageState();
}

class _MonthlyClaimManagementPageState extends State<MonthlyClaimManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedMonthId;
  String? _sponsorId;
  Set<String> _selectedParticipants = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadSponsorId();
  }

  Future<void> _loadSponsorId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sponsorId = prefs.getString('sponsorId');
    });
  }

  Future<void> _allocateRewards() async {
    if (_selectedParticipants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one participant')),
      );
      return;
    }

    // Show reward allocation dialog
    final result = await _showRewardAllocationDialog();
    if (result == null) return;

    setState(() => _isSubmitting = true);

    try {
      int successCount = 0;
      int failCount = 0;

      for (final userId in _selectedParticipants) {
        try {
          // Update participant status to selected
          await _firestore
              .collection('monthly_claims')
              .doc(_selectedMonthId)
              .collection('participants')
              .doc(userId)
              .update({
            'status': 'selected',
            'reward': {
              'type': result['type'],
              'value': result['value'],
              'title': result['title'],
              'description': result['description'],
              'code': 'MONTHLY-${DateTime.now().millisecondsSinceEpoch}-$userId',
            },
            'selectedAt': FieldValue.serverTimestamp(),
            'selectedBy': _sponsorId,
          });

          // Add to user's rewards_earned
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('rewards_earned')
              .doc('monthly_${_selectedMonthId}')
              .set({
            'activity_id': 'monthly_claim_$_selectedMonthId',
            'reward_value': result['value'],
            'reward_code': 'MONTHLY-${DateTime.now().millisecondsSinceEpoch}-$userId',
            'reward_type': result['type'],
            'reward_title': result['title'],
            'reward_description': result['description'],
            'status': 'issued',
            'issued_at': FieldValue.serverTimestamp(),
            'timestamp': FieldValue.serverTimestamp(),
            'source': 'monthly_lucky_draw',
          });

          successCount++;
        } catch (e) {
          print('Error allocating reward to $userId: $e');
          failCount++;
        }
      }

      // Mark non-selected participants
      final allParticipantsSnapshot = await _firestore
          .collection('monthly_claims')
          .doc(_selectedMonthId)
          .collection('participants')
          .get();

      for (final doc in allParticipantsSnapshot.docs) {
        if (!_selectedParticipants.contains(doc.id)) {
          await doc.reference.update({'status': 'not_selected'});
        }
      }

      setState(() => _isSubmitting = false);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Rewards Allocated'),
            content: Text(
              'Successfully allocated rewards to $successCount participant(s).\\n'
              '${failCount > 0 ? "Failed: $failCount" : ""}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        
        setState(() => _selectedParticipants.clear());
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _showRewardAllocationDialog() async {
    final typeController = TextEditingController(text: 'coins');
    final valueController = TextEditingController();
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Allocate Reward'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: typeController,
                decoration: const InputDecoration(
                  labelText: 'Reward Type (coins/product)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: valueController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Value/Amount',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Reward Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (valueController.text.isEmpty || titleController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill required fields')),
                );
                return;
              }
              
              Navigator.of(context).pop({
                'type': typeController.text,
                'value': int.tryParse(valueController.text) ?? 0,
                'title': titleController.text,
                'description': descriptionController.text,
              });
            },
            child: const Text('Allocate'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Month Selector
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('monthly_claims')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Text(
                    'Error loading months: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              var months = snapshot.data?.docs ?? [];
              
              // Sort months in memory (newest first)
              months.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aYear = aData['year'] ?? 0;
                final bYear = bData['year'] ?? 0;
                final aMonth = aData['month'] ?? 0;
                final bMonth = bData['month'] ?? 0;
                
                if (aYear != bYear) {
                  return bYear.compareTo(aYear);
                }
                return bMonth.compareTo(aMonth);
              });
              
              if (months.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.celebration_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'No Monthly Claims Yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Users will appear here when they claim monthly entries from the app.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }
              
              return DropdownButtonFormField<String>(
                value: _selectedMonthId,
                hint: const Text('Select Month'),
                decoration: const InputDecoration(
                  labelText: 'Month',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: months.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final year = data['year'];
                  final month = data['month'];
                  final monthName = DateFormat('MMMM yyyy')
                      .format(DateTime(year, month));
                  
                  return DropdownMenuItem(
                    value: doc.id,
                    child: Text('$monthName (${data['totalParticipants'] ?? 0} participants)'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedMonthId = value;
                    _selectedParticipants.clear();
                  });
                },
              );
            },
          ),
        ),

        // Participants List
        if (_selectedMonthId != null)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('monthly_claims')
                  .doc(_selectedMonthId)
                  .collection('participants')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No participants'));
                }

                final participants = snapshot.data!.docs;

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.blue.shade50,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_selectedParticipants.length} selected',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          ElevatedButton(
                            onPressed: _selectedParticipants.isEmpty || _isSubmitting
                                ? null
                                : _allocateRewards,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Allocate Rewards'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: participants.length,
                        itemBuilder: (context, index) {
                          final participant = participants[index];
                          final data = participant.data() as Map<String, dynamic>;
                          final userId = participant.id;
                          final status = data['status'] ?? 'pending';
                          final isSelected = _selectedParticipants.contains(userId);

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            color: status == 'selected'
                                ? Colors.green.shade50
                                : status == 'not_selected'
                                    ? Colors.grey.shade100
                                    : null,
                            child: CheckboxListTile(
                              value: isSelected,
                              onChanged: status == 'pending'
                                  ? (value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedParticipants.add(userId);
                                        } else {
                                          _selectedParticipants.remove(userId);
                                        }
                                      });
                                    }
                                  : null,
                              title: Text(data['userName'] ?? 'Unknown'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(data['userEmail'] ?? ''),
                                  Text(
                                    'Activity: ${data['activityTitle'] ?? 'N/A'}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Chip(
                                    label: Text(
                                      status.toUpperCase(),
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    backgroundColor: status == 'selected'
                                        ? Colors.green
                                        : status == 'not_selected'
                                            ? Colors.red
                                            : Colors.orange,
                                    labelStyle: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          )
        else
          const Expanded(
            child: Center(child: Text('Select a month to view participants')),
          ),
      ],
    );
  }
}
