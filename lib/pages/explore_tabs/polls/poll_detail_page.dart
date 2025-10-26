// poll_detail_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:giftardo/core/services/reward_allocation_service.dart';
import 'package:provider/provider.dart';
import '../../../providers/poll_provider.dart';
import 'poll_result_page.dart';
// Lottie package removed for poll details; using simple overlay instead

class PollDetailPage extends StatefulWidget {
  final String userId;
  final String activityId;
  final String title;
  final String description;
  final String sponsorName;
  final String sponsorProfilePic;
  final int pointsAwarded;
  final String rewardType;

  const PollDetailPage({
    Key? key,
    required this.userId,
    required this.activityId,
    required this.title,
    required this.description,
    required this.sponsorName,
    required this.sponsorProfilePic,
    required this.pointsAwarded,
    required this.rewardType,
  }) : super(key: key);

  @override
  State<PollDetailPage> createState() => _PollDetailPageState();
}

class _PollDetailPageState extends State<PollDetailPage> {
  List<Map<String, dynamic>> _questions = [];
  final Map<int, String> _answers = {};
  bool _loadingQuestions = true;
  bool _isSubmitting = false;
  int _currentIndex = 0;
  String? _rewardTitle;
  String? _rewardDescription;

  @override
  void initState() {
    super.initState();
    _loadPollQuestions();
    _loadRewardMeta();
  }

  @override
  void dispose() {
    super.dispose();
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
        final options = List<String>.from(data['options'] ?? []);
        final rawVotes = List<int>.from(data['votes'] ?? []);
        // Ensure votes list has same length as options (fill missing with zeros)
        final votes = List<int>.filled(options.length, 0);
        for (var i = 0; i < rawVotes.length && i < votes.length; i++) {
          votes[i] = rawVotes[i];
        }

        return {
          'id': doc.id,
          'question_text': data['question_text'],
          'options': options,
          'votes': votes,
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
        content: const Text("Your progress will be saved. Are you sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("No")),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Yes")),
        ],
      ),
    ) ?? false;

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
      // Update votes in Firestore
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

      // Save attempt
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

      int actualRewardValue = widget.pointsAwarded;
      String? rewardCode, actualRewardType, rewardTitle, rewardDescription;

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
            actualRewardValue = rewardResult['reward_value'] as int? ?? widget.pointsAwarded;
            rewardCode = rewardResult['reward_code'] as String?;
            actualRewardType = rewardResult['reward_type'] as String? ?? widget.rewardType;
            rewardTitle = rewardResult['reward_title'] as String?;
            rewardDescription = rewardResult['reward_description'] as String?;

            await userRef.collection('poll_attempts').doc(widget.activityId).update({
              'rewardedItem': actualRewardValue,
              'rewardCode': rewardCode,
              'rewardTitle': rewardTitle,
              'rewardDescription': rewardDescription,
              'rewardType': actualRewardType,
            });
          }
        }
      }

      // Mark as attempted
      Provider.of<PollProvider>(context, listen: false).markAttempted(widget.activityId);

      // Navigate directly to result page (animation removed)
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PollResultPage(
              title: widget.title,
              sponsorName: widget.sponsorName,
              sponsorProfilePic: widget.sponsorProfilePic,
              questions: _questions,
              answers: _answers,
              rewardedItem: actualRewardValue,
              rewardType: actualRewardType ?? widget.rewardType,
              rewardCode: rewardCode,
              rewardTitle: rewardTitle,
              rewardDescription: rewardDescription,
            ),
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Submission failed: $e")));
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _goToNext() {
    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
    } else {
      _submitPoll();
    }
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text("Poll"),
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
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
                  builder: (_) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text("How it works", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text("• Answer each question by selecting an option"),
                      const SizedBox(height: 4),
                      const Text("• Your answers help gather valuable feedback"),
                      const SizedBox(height: 4),
                      const Text("• Complete the poll to claim your reward"),
                      const SizedBox(height: 12),
                      Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.pop(context), child: const Text("Got it"))),
                    ]),
                  ),
                );
              },
            )
          ],
        ),
        body: _loadingQuestions
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // Sponsor Header
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.orange.shade700,
                              backgroundImage: widget.sponsorProfilePic.isNotEmpty ? NetworkImage(widget.sponsorProfilePic) : null,
                              child: widget.sponsorProfilePic.isEmpty
                                  ? Text(
                                      widget.sponsorName.isNotEmpty ? widget.sponsorName[0].toUpperCase() : 'S',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                                    )
                                  : null,
                              onBackgroundImageError: (exception, stackTrace) {
                                debugPrint('Failed to load sponsor profile pic: $exception');
                              },
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(widget.sponsorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  if (_rewardTitle != null)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_rewardTitle!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                        if (_rewardDescription != null)
                                          Text(_rewardDescription!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    )
                                  else
                                    Text("Reward: ${widget.pointsAwarded} points"),
                                  const SizedBox(height: 6),
                                  Text(widget.title, style: const TextStyle(fontSize: 15)),
                                ],
                              ),
                            ),
                            // Progress indicator
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${_currentIndex + 1}/${_questions.isEmpty ? 0 : _questions.length}',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: 60,
                                  child: LinearProgressIndicator(
                                    value: _questions.isEmpty ? 0 : (_currentIndex + 1) / _questions.length,
                                    backgroundColor: Colors.orange.shade100,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade700),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            transitionBuilder: (Widget child, Animation<double> animation) {
                              return FadeScaleTransition(animation: animation, child: child);
                            },
                            child: _buildQuestionCard(_questions[_currentIndex], _currentIndex),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isSubmitting)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.6),
                        child: Center(
                          child: SizedBox(
                            width: 200,
                            height: 200,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                CircularProgressIndicator(color: Colors.white),
                                SizedBox(height: 12),
                                Text('Submitting...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
        bottomNavigationBar: _questions.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _goToNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 4,
                    ),
                    child: Text(
                      _currentIndex == _questions.length - 1 ? 'Submit Poll' : 'Next',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> q, int index) {
    final question = q['question_text'] as String;
    final options = List<String>.from(q['options']);
    final currentAnswer = _answers[index];

    return Card(
      key: ValueKey('question-$index'), // essential for AnimatedSwitcher
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.4),
            ),
            const SizedBox(height: 24),
            ...options.asMap().entries.map((entry) {
              final option = entry.value;
              final isSelected = currentAnswer == option;

              return _buildOptionButton(
                option: option,
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    _answers[index] = option;
                  });
                  // Auto-advance after a short delay for fluidity
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted && _currentIndex == index) _goToNext();
                  });
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required String option,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutExpo,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: isSelected ? Colors.orange.withOpacity(0.15) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? Colors.orange : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 200),
          scale: isSelected ? 1.02 : 1.0,
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.orange : Colors.transparent,
                  border: Border.all(color: Colors.grey[400]!, width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: isSelected
                    ? Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? Colors.orange : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom transition for smooth question swaps
class FadeScaleTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const FadeScaleTransition({
    Key? key,
    required this.animation,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: animation,
        child: child,
      ),
    );
  }
}