import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:admin/core/services/reward_allocation_service.dart';

class LuckyDrawParticipantsPage extends StatefulWidget {
  final String activityId;
  final String activityTitle;
  final Map<String, dynamic> activityData;

  const LuckyDrawParticipantsPage({
    Key? key,
    required this.activityId,
    required this.activityTitle,
    required this.activityData,
  }) : super(key: key);

  @override
  State<LuckyDrawParticipantsPage> createState() => _LuckyDrawParticipantsPageState();
}

class _LuckyDrawParticipantsPageState extends State<LuckyDrawParticipantsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RewardAllocationService _rewardService = RewardAllocationService();
  
  List<Map<String, dynamic>> _participants = [];
  Set<String> _selectedParticipantIds = {};
  bool _isLoading = true;
  bool _isSubmitting = false;
  int _rewardQuantity = 0;
  String? _rewardId;
  String? _sponsorId;

  @override
  void initState() {
    super.initState();
    _loadActivityData();
    _loadParticipants();
  }

  Future<void> _loadActivityData() async {
    try {
      final rewardAllocation = widget.activityData['reward_allocation'] as Map<String, dynamic>?;
      if (rewardAllocation != null) {
        setState(() {
          _rewardQuantity = rewardAllocation['allocated_quantity'] as int? ?? 0;
          _rewardId = rewardAllocation['reward_id'] as String?;
        });
      }
      
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _sponsorId = prefs.getString('sponsorId') ?? widget.activityData['sponsor_id'] as String?;
      });
    } catch (e) {
      print('Error loading activity data: $e');
    }
  }

  Future<void> _loadParticipants() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get participants from activity_participants collection
      final participantsSnapshot = await _firestore
          .collection('activity_participants')
          .where('activityId', isEqualTo: widget.activityId)
          .get();

      final List<Map<String, dynamic>> allParticipants = [];

      for (var doc in participantsSnapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String?;
        
        if (userId != null) {
          // Get user details
          final userDoc = await _firestore.collection('users').doc(userId).get();
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            
            allParticipants.add({
              'userId': userId,
              'userName': userData['name'] ?? 'Unknown User',
              'userEmail': userData['email'] ?? '',
              'attemptType': data['activityType'] ?? 'unknown',
              'completedAt': data['completedAt'],
              'attemptId': doc.id,
              'isRewarded': data['isRewarded'] ?? false,
            });
          }
        }
      }

      setState(() {
        _participants = allParticipants;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading participants: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading participants: $e'),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleParticipantSelection(String userId) {
    setState(() {
      if (_selectedParticipantIds.contains(userId)) {
        _selectedParticipantIds.remove(userId);
      } else {
        // For lucky draw, check if we've reached the reward quantity limit
        // For first come first serve, unlimited selection is allowed (they're already rewarded)
        if (widget.activityData['reward_distribution_type'] == 'lucky_draw' && 
            _rewardQuantity > 0 &&
            _selectedParticipantIds.length >= _rewardQuantity) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You can only select up to $_rewardQuantity participant(s) based on allocated rewards'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        }
        _selectedParticipantIds.add(userId);
      }
    });
  }

  Future<void> _assignRewardsToSelected() async {
    if (_selectedParticipantIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one participant')),
      );
      return;
    }

    if (_selectedParticipantIds.length != _rewardQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select exactly $_rewardQuantity participants'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_rewardId == null || _sponsorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing reward or sponsor information')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      int successCount = 0;
      int failCount = 0;

      // First, allocate rewards to selected participants
      for (final userId in _selectedParticipantIds) {
        try {
          final result = await _rewardService.allocateRewardToUser(
            activityId: widget.activityId,
            userId: userId,
            sponsorId: _sponsorId!,
            rewardId: _rewardId!,
          );

          if (result != null) {
            // Update the user's attempt record to mark as rewarded
            await _updateUserAttemptRecord(userId, result);
            successCount++;
          } else {
            failCount++;
          }
        } catch (e) {
          print('Error assigning reward to user $userId: $e');
          failCount++;
        }
      }

      // Mark all non-selected participants as not selected
      final allParticipantIds = _participants.map((p) => p['userId'] as String).toSet();
      final notSelectedIds = allParticipantIds.difference(_selectedParticipantIds);
      
      for (final userId in notSelectedIds) {
        try {
          await _firestore
              .collection('activity_participants')
              .doc('${widget.activityId}_$userId')
              .update({
            'rewardStatus': 'not_selected',
          });
        } catch (e) {
          print('Error marking user $userId as not selected: $e');
        }
      }

      setState(() {
        _isSubmitting = false;
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Rewards Assigned'),
            content: Text(
              'Successfully assigned rewards to $successCount participant(s).\n'
              '${failCount > 0 ? "Failed to assign $failCount reward(s)." : ""}\n'
              '${notSelectedIds.length} participant(s) were not selected.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Go back to previous screen
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error assigning rewards: $e')),
        );
      }
    }
  }

  Future<void> _updateUserAttemptRecord(String userId, Map<String, dynamic> rewardResult) async {
    try {
      // Update in rewards_earned collection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('rewards_earned')
          .doc(widget.activityId)
          .set({
        'activity_id': widget.activityId,
        'reward_assignment_id': rewardResult['assignment_id'],
        'reward_value': rewardResult['reward_value'],
        'reward_code': rewardResult['reward_code'],
        'assigned_item_id': rewardResult['assigned_item_id'],
        'sponsor_id': _sponsorId,
        'reward_id': _rewardId,
        'reward_type': rewardResult['reward_type'],
        'reward_title': rewardResult['reward_title'],
        'status': 'issued',
        'issued_at': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
        'is_lucky_draw_winner': true,
      }, SetOptions(merge: true));

      // Update participant record in activity_participants collection
      await _firestore
          .collection('activity_participants')
          .doc('${widget.activityId}_$userId')
          .update({
        'isRewarded': true,
        'rewardCode': rewardResult['reward_code'],
        'rewardedAt': FieldValue.serverTimestamp(),
        'rewardStatus': 'rewarded',
      });

      // Also update the attempt record to mark as rewarded
      // Find and update the attempt record
      final quizAttempts = await _firestore
          .collection('users')
          .doc(userId)
          .collection('quiz_attempts')
          .doc(widget.activityId)
          .get();
      
      if (quizAttempts.exists) {
        await quizAttempts.reference.update({
          'rewarded': true,
          'rewardCode': rewardResult['reward_code'],
          'rewardType': rewardResult['reward_type'],
          'rewardedItem': rewardResult['reward_value'],
        });
      }

      final surveyAttempts = await _firestore
          .collection('users')
          .doc(userId)
          .collection('survey_attempts')
          .doc(widget.activityId)
          .get();
      
      if (surveyAttempts.exists) {
        await surveyAttempts.reference.update({
          'rewarded': true,
          'rewardCode': rewardResult['reward_code'],
          'rewardType': rewardResult['reward_type'],
          'rewardedItem': rewardResult['reward_value'],
        });
      }

      final pollAttempts = await _firestore
          .collection('users')
          .doc(userId)
          .collection('poll_attempts')
          .doc(widget.activityId)
          .get();
      
      if (pollAttempts.exists) {
        await pollAttempts.reference.update({
          'rewarded': true,
          'rewardCode': rewardResult['reward_code'],
          'rewardType': rewardResult['reward_type'],
          'rewardedItem': rewardResult['reward_value'],
        });
      }

      final youtubeAttempts = await _firestore
          .collection('users')
          .doc(userId)
          .collection('youtube_attempts')
          .doc(widget.activityId)
          .get();
      
      if (youtubeAttempts.exists) {
        await youtubeAttempts.reference.update({
          'rewarded': true,
          'rewardCode': rewardResult['reward_code'],
          'rewardType': rewardResult['reward_type'],
          'rewardedItem': rewardResult['reward_value'],
        });
      }
    } catch (e) {
      print('Error updating user attempt record: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rewardDistributionType = widget.activityData['reward_distribution_type'] as String? ?? 'first_come_first_serve';
    final isLuckyDraw = rewardDistributionType == 'lucky_draw';
    final endDate = widget.activityData['end_date'] as Timestamp?;
    final now = DateTime.now();
    final canAssignRewards = isLuckyDraw 
        ? (endDate != null && now.isAfter(endDate.toDate()))
        : true; // First come first serve can always view participants

    return Scaffold(
      appBar: AppBar(
        title: Text(isLuckyDraw ? 'Lucky Draw Participants' : 'Activity Participants'),
        actions: [
          if (_selectedParticipantIds.isNotEmpty && isLuckyDraw)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: Text(
                  '${_selectedParticipantIds.length}/$_rewardQuantity selected',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Info Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: isLuckyDraw ? Colors.purple.shade50 : Colors.green.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.activityTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isLuckyDraw ? Colors.purple : Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isLuckyDraw ? 'Lucky Draw' : 'First Come First Serve',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Reward Quantity: $_rewardQuantity'),
                Text('Total Participants: ${_participants.length}'),
                if (isLuckyDraw) ...[
                  Text('Selected: ${_selectedParticipantIds.length}'),
                  if (endDate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'End Date: ${_formatDate(endDate)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                    if (!canAssignRewards)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: Colors.orange[800]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Rewards can only be assigned after the activity end date.',
                                  style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ],
            ),
          ),

          // Participants List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _participants.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No participants yet'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _participants.length,
                        itemBuilder: (context, index) {
                          final participant = _participants[index];
                          final userId = participant['userId'] as String;
                          final isSelected = _selectedParticipantIds.contains(userId);
                          final completedAt = participant['completedAt'] as Timestamp?;
                          final isRewarded = participant['isRewarded'] as bool? ?? false;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            color: isSelected 
                                ? Colors.green.shade50 
                                : isRewarded 
                                    ? Colors.blue.shade50 
                                    : null,
                            child: ListTile(
                              leading: isLuckyDraw && canAssignRewards
                                  ? Checkbox(
                                      value: isSelected,
                                      onChanged: (value) {
                                        _toggleParticipantSelection(userId);
                                      },
                                    )
                                  : isRewarded
                                      ? const Icon(Icons.check_circle, color: Colors.green)
                                      : const Icon(Icons.person, color: Colors.grey),
                              title: Text(
                                participant['userName'] as String? ?? 'Unknown User',
                                style: TextStyle(
                                  fontWeight: isSelected || isRewarded
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(participant['userEmail'] as String? ?? ''),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Chip(
                                        label: Text(
                                          participant['attemptType'] as String? ?? 'unknown',
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                        backgroundColor: Colors.blue.shade100,
                                      ),
                                      const SizedBox(width: 8),
                                      if (completedAt != null)
                                        Text(
                                          'Completed: ${_formatDate(completedAt)}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                    ],
                                  ),
                                  if (isRewarded && !isLuckyDraw)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check_circle, size: 14, color: Colors.green[800]),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Rewarded',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.green[800],
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Submit Button (only for lucky draw after end date)
          if (isLuckyDraw && canAssignRewards && _selectedParticipantIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _assignRewardsToSelected,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Assign Rewards to ${_selectedParticipantIds.length} Selected Participant(s)',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    try {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown date';
    }
  }
}

