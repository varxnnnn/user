import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:giftardo/core/services/reward_allocation_service.dart';
import 'survey_result_page.dart';
import 'package:provider/provider.dart';
import '../../../providers/survey_provider.dart';

class SurveyDetailPage extends StatefulWidget {
  final String userId;
  final String activityId;
  final String title;
  final String description;
  final String sponsorName;
  final String sponsorLogo;
  final int pointsAwarded;
  final String rewardType;

  const SurveyDetailPage({
    Key? key,
    required this.userId,
    required this.activityId,
    required this.title,
    required this.description,
    required this.sponsorName,
    required this.sponsorLogo,
    required this.pointsAwarded,
    required this.rewardType,
    required dynamic rewardedItem,
    required List<Map<String, dynamic>> questions,
  }) : super(key: key);

  @override
  State<SurveyDetailPage> createState() => _SurveyDetailPageState();
}

class _SurveyDetailPageState extends State<SurveyDetailPage> {
  List<Map<String, dynamic>> _questions = [];
  final Map<int, dynamic> _answers = {};
  bool _loadingQuestions = true;
  bool _isSubmitting = false;
  int _actualRewardValue = 0;
  String? _rewardCode;
  String? _actualRewardType;
  String? _rewardTitle;
  String? _rewardDescription;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadSurveyQuestions();
    _loadRewardMeta();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  

  // _refreshData was removed: not referenced anywhere.

  Future<void> _loadRewardMeta({bool silent = false}) async {
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
            final newTitle = rdata['title'] as String?;
            final newDesc = rdata['description'] as String?;

            // Only update if changed
            if (newTitle != _rewardTitle || newDesc != _rewardDescription) {
              if (!silent || mounted) {
                setState(() {
                  _rewardTitle = newTitle;
                  _rewardDescription = newDesc;
                });
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading reward meta: $e');
    }
  }

  Future<void> _loadSurveyQuestions({bool silent = false}) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('sponsor_activities')
          .doc(widget.activityId)
          .collection('questions')
          .get();

      final newQuestions = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'question_text': data['question_text'],
          'question_type': data['question_type'],
          'options': List<String>.from(data['options'] ?? []),
        };
      }).toList();

      // Check if questions actually changed (by comparing IDs and text)
      bool hasChanged = false;
      if (_questions.length != newQuestions.length) {
        hasChanged = true;
      } else {
        for (int i = 0; i < _questions.length; i++) {
          if (_questions[i]['id'] != newQuestions[i]['id'] ||
              _questions[i]['question_text'] != newQuestions[i]['question_text'] ||
              _questions[i]['question_type'] != newQuestions[i]['question_type'] ||
              !listEquals(_questions[i]['options'], newQuestions[i]['options'])) {
            hasChanged = true;
            break;
          }
        }
      }

      if (hasChanged) {
        // Preserve answers for questions that still exist
        final Map<int, dynamic> preservedAnswers = {};
        for (int i = 0; i < newQuestions.length; i++) {
          final newQ = newQuestions[i];
          // Find matching old question by ID
          for (int j = 0; j < _questions.length; j++) {
            if (_questions[j]['id'] == newQ['id']) {
              if (_answers.containsKey(j)) {
                preservedAnswers[i] = _answers[j];
              }
              break;
            }
          }
        }

        if (!silent || mounted) {
          setState(() {
            _questions = newQuestions;
            _answers.clear();
            _answers.addAll(preservedAnswers);
            if (_loadingQuestions) _loadingQuestions = false;
          });
        }
      } else {
        if (_loadingQuestions && !silent) {
          setState(() {
            _loadingQuestions = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading survey questions: $e");
      if (_loadingQuestions && !silent && mounted) {
        setState(() {
          _loadingQuestions = false;
        });
      }
    }
  }

  // Helper to compare two lists
  bool listEquals(List<dynamic> a, List<dynamic> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _saveAbandonedAttempt() async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(widget.userId);
      await userRef.collection('survey_attempts').doc(widget.activityId).set({
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
      debugPrint("Error saving abandoned survey attempt: $e");
    }
  }

  Future<bool> _onWillPop() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Exit Survey?"),
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

  Future<void> _submitSurvey() async {
    for (int i = 0; i < _questions.length; i++) {
      if (_answers[i] == null || _answers[i] == '') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please answer all questions")),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(widget.userId);
      await userRef.collection('survey_attempts').doc(widget.activityId).set({
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

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'activitiesCompleted': FieldValue.increment(1)});

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

            await userRef.collection('survey_attempts').doc(widget.activityId).update({
              'rewardedItem': _actualRewardValue,
              'rewardCode': _rewardCode,
              'rewardTitle': _rewardTitle,
              'rewardDescription': _rewardDescription,
              'rewardType': _actualRewardType,
            });
          }
        }
      }

      if (mounted) {
        // mark as completed in provider so lists update immediately
        try {
          Provider.of<SurveyProvider>(context, listen: false).markAttempted(widget.activityId);
        } catch (_) {}

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SurveyResultPage(
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

        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error submitting survey: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildQuestion(int index) {
    final q = _questions[index];
    final qType = q['question_type'];
    final qText = q['question_text'];

    switch (qType) {
      case 'short':
        return TextField(
          maxLines: 3,
          decoration: InputDecoration(
            labelText: qText,
            hintText: "Write your review here...",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onChanged: (val) => _answers[index] = val,
        );

      case 'rating':
        final rating = _answers[index] ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(qText, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                return IconButton(
                  icon: Icon(
                    i < rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                  onPressed: () {
                    setState(() {
                      _answers[index] = i + 1;
                    });
                  },
                );
              }),
            ),
          ],
        );

      case 'mcq':
        final options = List<String>.from(q['options']);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(qText, style: const TextStyle(fontWeight: FontWeight.bold)),
            ...options.map((opt) {
              return RadioListTile<String>(
                title: Text(opt),
                value: opt,
                groupValue: _answers[index],
                onChanged: (val) => setState(() => _answers[index] = val!),
              );
            }).toList(),
          ],
        );

      default:
        return Text("$qText (Unsupported type: $qType)");
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
              itemBuilder: (_, index) {
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
                              widget.sponsorName.isNotEmpty
                                  ? widget.sponsorName[0].toUpperCase()
                                  : 'S',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.sponsorName,
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                if (_rewardTitle != null) ...[
                                  Text(_rewardTitle!,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                  if (_rewardDescription != null)
                                    Text(_rewardDescription!,
                                        style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                ] else ...[
                                  Text(
                                      "Reward: ${_actualRewardValue > 0 ? '$_actualRewardValue points' : '${widget.pointsAwarded} points'}"),
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

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildQuestion(index - 1),
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
            onPressed: _isSubmitting ? null : _submitSurvey,
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
              "Submit Survey",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}