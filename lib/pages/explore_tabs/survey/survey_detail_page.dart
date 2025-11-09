// screens/survey_detail_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:giftardo/core/services/reward_allocation_service.dart';
import 'package:giftardo/core/services/milestone_service.dart';
import 'survey_result_page.dart';
import 'package:provider/provider.dart';
import '../../../providers/survey_provider.dart';
import 'package:flutter/gestures.dart';

class SurveyDetailPage extends StatefulWidget {
  final String userId;
  final String activityId;
  final String title;
  final String description;
  final String sponsorName;
  final String sponsorProfilePic;
  final int pointsAwarded;
  final String rewardType;

  const SurveyDetailPage({
    Key? key,
    required this.userId,
    required this.activityId,
    required this.title,
    required this.description,
    required this.sponsorName,
    required this.sponsorProfilePic,
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

  // 👇 New: Instruction state
  bool _hasShownInstructions = false;

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

  Future<void> _loadRewardMeta({bool silent = false}) async {
    try {
      final activityDoc = await FirebaseFirestore.instance
          .collection('sponsor_activities')
          .doc(widget.activityId)
          .get();

      if (activityDoc.exists) {
        final data = activityDoc.data()!;
        final rewardAllocation =
            data['reward_allocation'] as Map<String, dynamic>?;
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

      bool hasChanged = false;
      if (_questions.length != newQuestions.length) {
        hasChanged = true;
      } else {
        for (int i = 0; i < _questions.length; i++) {
          if (_questions[i]['id'] != newQuestions[i]['id'] ||
              _questions[i]['question_text'] !=
                  newQuestions[i]['question_text'] ||
              _questions[i]['question_type'] !=
                  newQuestions[i]['question_type'] ||
              !listEquals(
                _questions[i]['options'],
                newQuestions[i]['options'],
              )) {
            hasChanged = true;
            break;
          }
        }
      }

      if (hasChanged) {
        final Map<int, dynamic> preservedAnswers = {};
        for (int i = 0; i < newQuestions.length; i++) {
          final newQ = newQuestions[i];
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

  bool listEquals(List<dynamic> a, List<dynamic> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _saveAbandonedAttempt() async {
    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId);
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
    final shouldPop =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Exit Survey?"),
            content: const Text(
              "Are you sure you want to exit? Your progress will be saved as completed.",
            ),
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
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId);
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

      // Add to activity_participants collection for easy admin access
      await FirebaseFirestore.instance
          .collection('activity_participants')
          .doc('${widget.activityId}_${widget.userId}')
          .set({
        'activityId': widget.activityId,
        'userId': widget.userId,
        'activityType': 'survey',
        'completedAt': FieldValue.serverTimestamp(),
        'isRewarded': false,
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'activitiesCompleted': FieldValue.increment(1)});

      // Track for milestone progress
      try {
        final milestoneService = MilestoneService();
        await milestoneService.trackActivityCompletion(
          activityId: widget.activityId,
          activityType: 'survey',
        );
      } catch (e) {
        print('Error tracking milestone: $e');
      }

      final rewardService = RewardAllocationService();
      final activityDoc = await FirebaseFirestore.instance
          .collection('sponsor_activities')
          .doc(widget.activityId)
          .get();

      String rewardDistributionType = 'first_come_first_serve';

      if (activityDoc.exists) {
        final data = activityDoc.data()!;
        final sponsorId = data['sponsor_id'] as String?;
        final rewardAllocation =
            data['reward_allocation'] as Map<String, dynamic>?;
        final rewardId = rewardAllocation?['reward_id'] as String?;
        rewardDistributionType = data['reward_distribution_type'] as String? ?? 'first_come_first_serve';

        // For lucky draw activities, show a different message
        if (rewardDistributionType == 'lucky_draw') {
          // For lucky draw, we don't immediately allocate rewards
          // Just mark the user as participated
          _actualRewardValue = 0;
          _rewardCode = 'LUCKY_DRAW_PENDING';
          _actualRewardType = 'lucky_draw';
          _rewardTitle = 'Lucky Draw Participation';
          _rewardDescription = 'Results will be announced soon. Winners will be notified.';

          await userRef
              .collection('survey_attempts')
              .doc(widget.activityId)
              .update({
                'rewardedItem': _actualRewardValue,
                'rewardCode': _rewardCode,
                'rewardTitle': _rewardTitle,
                'rewardDescription': _rewardDescription,
                'rewardType': _actualRewardType,
              });
          
          // Update participant record
          await FirebaseFirestore.instance
              .collection('activity_participants')
              .doc('${widget.activityId}_${widget.userId}')
              .update({
            'rewardStatus': 'pending',
          });
        } else {
          // For first come first serve, allocate rewards immediately
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
              _actualRewardType =
                  rewardResult['reward_type'] as String? ?? widget.rewardType;
              _rewardTitle = rewardResult['reward_title'] as String?;
              _rewardDescription = rewardResult['reward_description'] as String?;

              await userRef
                  .collection('survey_attempts')
                  .doc(widget.activityId)
                  .update({
                    'rewardedItem': _actualRewardValue,
                    'rewardCode': _rewardCode,
                    'rewardTitle': _rewardTitle,
                    'rewardDescription': _rewardDescription,
                    'rewardType': _actualRewardType,
                  });
              
              // Update participant record
              await FirebaseFirestore.instance
                  .collection('activity_participants')
                  .doc('${widget.activityId}_${widget.userId}')
                  .update({
                'isRewarded': true,
                'rewardCode': _rewardCode,
                'rewardedAt': FieldValue.serverTimestamp(),
              });
            }
          }
        }
      }

      if (mounted) {
        try {
          Provider.of<SurveyProvider>(
            context,
            listen: false,
          ).markAttempted(widget.activityId);
        } catch (_) {}

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SurveyResultPage(
              title: widget.title,
              sponsorName: widget.sponsorName,
              sponsorProfilePic: widget.sponsorProfilePic,
              questions: _questions,
              answers: _answers,
              rewardedItem: _actualRewardValue > 0
                  ? _actualRewardValue
                  : widget.pointsAwarded,
              rewardType: rewardDistributionType == 'lucky_draw' ? 'lucky_draw' : (_actualRewardType ?? widget.rewardType),
              rewardCode: _rewardCode,
              rewardTitle: _rewardTitle,
              rewardDescription: _rewardDescription,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error submitting survey: $e")));
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

  // 👇 New: Instruction Overlay UI
  Widget _buildInstructionsOverlay() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.rate_review,
                      color: Colors.orange,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Survey Instructions',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Please read all questions carefully and answer honestly based on your experience.',
                        style: TextStyle(fontSize: 16, height: 1.6),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '• Your responses will help the app and its sponsors improve products and services.',
                        style: TextStyle(fontSize: 16, height: 1.6),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• All information you provide will remain confidential and will not be shared with any third party.',
                        style: TextStyle(fontSize: 16, height: 1.6),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Once you start the survey, it will be considered completed even if you exit before finishing.',
                        style: TextStyle(fontSize: 16, height: 1.6),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Rewards or benefits (if applicable) will be provided after successful completion.',
                        style: TextStyle(fontSize: 16, height: 1.6),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Each user can participate only once per survey unless otherwise stated.',
                        style: TextStyle(fontSize: 16, height: 1.6),
                      ),
                      const SizedBox(height: 16),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.6,
                            color: Colors.black,
                          ),
                          children: [
                            const TextSpan(
                              text: 'By participating, you agree to the app’s ',
                            ),
                            TextSpan(
                              text: 'Terms & Conditions',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Opening Terms & Conditions...",
                                      ),
                                    ),
                                  );
                                },
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Opening Privacy Policy...",
                                      ),
                                    ),
                                  );
                                },
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _hasShownInstructions = true;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 4,
                  ),
                  child: const Text(
                    '✅ I Understand – Start Survey',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 👇 Show instructions first
    if (!_hasShownInstructions) {
      return _buildInstructionsOverlay();
    }

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Survey"),
          centerTitle: true,
          backgroundColor: Colors.orange.shade700,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                  builder: (_) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "How it works",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text("• Answer each question with your feedback"),
                        const SizedBox(height: 4),
                        const Text(
                          "• Some questions may require text, ratings, or choices",
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "• Complete all questions to claim your reward",
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Got it"),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: Stack(
          children: [
            _loadingQuestions
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 90,
                          width: 90,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                strokeWidth: 8,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.orange.shade200,
                                ),
                              ),
                              Icon(
                                Icons.rate_review,
                                size: 40,
                                color: Colors.orange.shade700,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "Loading survey...",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.orange.shade700,
                                backgroundImage:
                                    widget.sponsorProfilePic.isNotEmpty
                                    ? NetworkImage(widget.sponsorProfilePic)
                                    : null,
                                child: widget.sponsorProfilePic.isEmpty
                                    ? Text(
                                        widget.sponsorName.isNotEmpty
                                            ? widget.sponsorName[0]
                                                  .toUpperCase()
                                            : 'S',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      )
                                    : null,
                                onBackgroundImageError: (exception, stackTrace) {
                                  debugPrint(
                                    'Failed to load sponsor logo: $exception',
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.sponsorName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (_rewardTitle != null) ...[
                                      Text(
                                        _rewardTitle!,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (_rewardDescription != null)
                                        Text(
                                          _rewardDescription!,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey,
                                          ),
                                        ),
                                    ] else ...[
                                      Text(
                                        "Reward: ${_actualRewardValue > 0 ? '$_actualRewardValue points' : '${widget.pointsAwarded} points'}",
                                      ),
                                    ],
                                    Text(
                                      widget.title,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...List.generate(_questions.length, (index) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.orange.shade100,
                                width: 1,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          "Q${index + 1}",
                                          style: TextStyle(
                                            color: Colors.orange.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _questions[index]['question_text']
                                              as String,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _buildQuestion(index),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmitting
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        "Submitting",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
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
