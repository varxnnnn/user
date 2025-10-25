import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:giftardo/core/services/reward_allocation_service.dart';
import 'package:provider/provider.dart';
import '../../../providers/poll_provider.dart';
import 'poll_result_page.dart';

class PollDetailPage extends StatefulWidget {
  final String userId;
  final String activityId;
  final String title;
  final String description;
  final String sponsorName;
  final String sponsorLogo;
  final int pointsAwarded;
  final String rewardType;

  const PollDetailPage({
    Key? key,
    required this.userId,
    required this.activityId,
    required this.title,
    required this.description,
    required this.sponsorName,
    required this.sponsorLogo,
    required this.pointsAwarded,
    required this.rewardType,
    required List<Map<String, dynamic>> questions,
  }) : super(key: key);

  @override
  State<PollDetailPage> createState() => _PollDetailPageState();
}

class _PollDetailPageState extends State<PollDetailPage> {
  List<Map<String, dynamic>> _questions = [];
  final Map<int, String> _answers = {};
  bool _loadingQuestions = true;
  bool _isSubmitting = false;
  int _actualRewardValue = 0;
  String? _rewardCode;
  String? _actualRewardType;
  String? _rewardTitle;
  String? _rewardDescription;

  @override
  void initState() {
    super.initState();
    _loadPollQuestions();
    _loadRewardMeta();
  }

  Future<void> _loadRewardMeta() async {
    try {
      final activityDoc = await FirebaseFirestore.instance
          .collection('sponsor_activities')
          .doc(widget.activityId)
          .get();

      if (activityDoc.exists) {
        final data = activityDoc.data()!;
        final rewardAllocation = data['reward_allocation'] as Map<String, dynamic>?;
        final rewardId = rewardAllocation?['reward_id'] as String?;
        if (rewardId != null) {
          final rdoc = await FirebaseFirestore.instance
              .collection('sponsor_rewards')
              .doc(rewardId)
              .get();
          if (rdoc.exists) {
            final rdata = rdoc.data()!;
            setState(() {
              _rewardTitle = rdata['title'] as String?;
              _rewardDescription = rdata['description'] as String?;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading reward meta: $e');
    }
  }

  Future<void> _loadPollQuestions() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('sponsor_activities')
          .doc(widget.activityId)
          .collection('questions')
          .get();

      final questions = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'question_text': data['question_text'],
          'options': List<String>.from(data['options'] ?? []),
          'votes': List<int>.from(data['votes'] ?? []),
        };
      }).toList();

      setState(() {
        _questions = questions;
        _loadingQuestions = false;
      });
    } catch (e) {
      debugPrint("Error loading poll questions: $e");
      setState(() {
        _loadingQuestions = false;
      });
    }
  }

  Future<void> _saveAbandonedAttempt() async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(widget.userId);
      await userRef.collection('poll_attempts').doc(widget.activityId).set({
        'activityId': widget.activityId,
        'activityTitle': widget.title,
        'description': widget.description,
        'sponsorName': widget.sponsorName,
        'rewardType': widget.rewardType,
        'rewardedItem': 0,
        'rewardCode': null,
        'rewardTitle': null,
        'rewardDescription': null,
        'answers': _answers.map((k, v) => MapEntry(k.toString(), v)),
        'timestamp': FieldValue.serverTimestamp(),
        'userId': widget.userId,
        'isAbandoned': true,
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'activitiesCompleted': FieldValue.increment(1)});
    } catch (e) {
      debugPrint("Error saving abandoned poll attempt: $e");
    }
  }

  Future<bool> _onWillPop() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Exit Poll?"),
        content: const Text("Are you sure you want to exit? Your progress will be saved as completed."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Yes"),
          ),
        ],
      ),
    ) ??
        false;

    if (shouldPop) {
      await _saveAbandonedAttempt();
      if (mounted) Navigator.of(context).pop();
    }
    return shouldPop;
  }

  Future<void> _submitPoll() async {
    if (_answers.length < _questions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please answer all questions")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Update votes for each question
      for (int i = 0; i < _questions.length; i++) {
        final q = _questions[i];
        final selectedOption = _answers[i];
        if (selectedOption != null) {
          final optionIndex = q['options'].indexOf(selectedOption);
          if (optionIndex >= 0) {
            q['votes'][optionIndex] = (q['votes'][optionIndex] ?? 0) + 1;

            await FirebaseFirestore.instance
                .collection('sponsor_activities')
                .doc(widget.activityId)
                .collection('questions')
                .doc(q['id'])
                .update({'votes': q['votes']});
          }
        }
      }

      // Save user's poll attempt
      final userRef = FirebaseFirestore.instance.collection('users').doc(widget.userId);
      await userRef.collection('poll_attempts').doc(widget.activityId).set({
        'activityId': widget.activityId,
        'activityTitle': widget.title,
        'description': widget.description,
        'sponsorName': widget.sponsorName,
        'rewardType': widget.rewardType,
        'rewardedItem': 0,
        'rewardCode': null,
        'rewardTitle': null,
        'rewardDescription': null,
        'answers': _answers.map((k, v) => MapEntry(k.toString(), v)),
        'timestamp': FieldValue.serverTimestamp(),
        'userId': widget.userId,
      });

      // Increment activitiesCompleted
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'activitiesCompleted': FieldValue.increment(1)});

      // Allocate reward
      final rewardService = RewardAllocationService();
      final activityDoc = await FirebaseFirestore.instance
          .collection('sponsor_activities')
          .doc(widget.activityId)
          .get();

      if (activityDoc.exists) {
        final data = activityDoc.data()!;
        final sponsorId = data['sponsor_id'] as String?;
        final rewardAllocation = data['reward_allocation'] as Map<String, dynamic>?;
        final rewardId = rewardAllocation?['reward_id'] as String?;

        if (sponsorId != null && rewardId != null) {
          final rewardResult = await rewardService.allocateRewardToUser(
            activityId: widget.activityId,
            userId: widget.userId,
            sponsorId: sponsorId,
            rewardId: rewardId,
          );

          if (rewardResult != null) {
            _actualRewardValue = rewardResult['reward_value'] as int? ?? 0;
            _rewardCode = rewardResult['reward_code'] as String?;
            _actualRewardType = rewardResult['reward_type'] as String? ?? widget.rewardType;
            _rewardTitle = rewardResult['reward_title'] as String?;
            _rewardDescription = rewardResult['reward_description'] as String?;

            // Update poll attempt with reward details
            await userRef.collection('poll_attempts').doc(widget.activityId).update({
              'rewardedItem': _actualRewardValue,
              'rewardCode': _rewardCode,
              'rewardTitle': _rewardTitle,
              'rewardDescription': _rewardDescription,
              'rewardType': _actualRewardType,
            });
          }
        }
      }

      // Navigate to result page
      if (mounted) {
        // mark as attempted in provider so lists update immediately
        try {
          Provider.of<PollProvider>(context, listen: false).markAttempted(widget.activityId);
        } catch (_) {}
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PollResultPage(
              title: widget.title,
              questions: _questions,
              answers: _answers,
              rewardedItem: _actualRewardValue > 0 ? _actualRewardValue : widget.pointsAwarded,
              rewardType: _actualRewardType ?? widget.rewardType,
              rewardCode: _rewardCode,
              rewardTitle: _rewardTitle,
              rewardDescription: _rewardDescription,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error submitting poll: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title), backgroundColor: Colors.orange),
        body: Stack(
          children: [
            _loadingQuestions
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _questions.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.orange,
                            child: Text(
                              widget.sponsorName.isNotEmpty ? widget.sponsorName[0].toUpperCase() : 'S',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.sponsorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                if (_rewardTitle != null) ...[
                                  Text(_rewardTitle!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  if (_rewardDescription != null)
                                    Text(_rewardDescription!, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                ] else ...[
                                  Text("Reward: ${_actualRewardValue > 0 ? '$_actualRewardValue points' : '${widget.pointsAwarded} points'}"),
                                ],
                                Text(widget.title, style: const TextStyle(fontSize: 16)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final q = _questions[index - 1];
                final question = q['question_text'];
                final options = List<String>.from(q['options']);

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(question, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        ...options.map((option) {
                          return RadioListTile<String>(
                            title: Text(option),
                            value: option,
                            groupValue: _answers[index - 1],
                            onChanged: (val) => setState(() => _answers[index - 1] = val!),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (_isSubmitting)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.45),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitPoll,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSubmitting
                ? Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  "Submitting",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(width: 8),
                SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            )
                : const Text(
              "Submit Poll",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}