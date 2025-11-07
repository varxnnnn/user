// screens/quiz_detail_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../providers/quiz_provider.dart';
import 'quiz_result_page.dart';
import 'package:giftardo/core/services/reward_allocation_service.dart';
import 'package:flutter/gestures.dart';

class QuizDetailPage extends StatefulWidget {
  final String activityId;
  final String title;
  final String description;
  final String sponsorName;
  final String sponsorLogo;
  final String rewardType;
  final dynamic rewardedItem;
  final List<Map<String, dynamic>> questions;
  final dynamic pointsAwarded;
  final String userId;

  const QuizDetailPage({
    Key? key,
    required this.activityId,
    required this.title,
    required this.description,
    required this.sponsorName,
    required this.sponsorLogo,
    required this.rewardType,
    required this.rewardedItem,
    required this.questions,
    required this.pointsAwarded,
    required this.userId,
  }) : super(key: key);

  @override
  State<QuizDetailPage> createState() => _QuizDetailPageState();
}

class _QuizDetailPageState extends State<QuizDetailPage> with SingleTickerProviderStateMixin {
  late List<String?> _answers;
  bool _submitted = false;
  List<Map<String, dynamic>> _questions = [];
  bool _loadingQuestions = true;
  bool _isSubmitting = false;
  int _rewardPoints = 0;
  String? _rewardTitle;
  String? _rewardDescription;

  late PageController _pageController;
  int _currentIndex = 0;
  bool _autoAdvanceOnSelect = true;

  late AnimationController _animController;

  // 👇 New: Instruction state
  bool _hasShownInstructions = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _loadActivityDetails();
    _loadQuestions();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadActivityDetails() async {
    try {
      final activityDoc = await FirebaseFirestore.instance
          .collection('sponsor_activities')
          .doc(widget.activityId)
          .get();

      if (activityDoc.exists) {
        final data = activityDoc.data()!;
        setState(() {
          _rewardPoints = data['cost_points'] ?? 0;
          final rewardAlloc = data['reward_allocation'] as Map<String, dynamic>?;
          if (rewardAlloc != null && rewardAlloc['reward_id'] != null) {
            FirebaseFirestore.instance
                .collection('sponsor_rewards')
                .doc(rewardAlloc['reward_id'] as String)
                .get()
                .then((rdoc) {
              if (rdoc.exists) {
                final rdata = rdoc.data()!;
                setState(() {
                  _rewardTitle = rdata['title'] as String?;
                  _rewardDescription = rdata['description'] as String?;
                });
              }
            }).catchError((_) {});
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading activity details: $e");
    }
  }

  Future<void> _loadQuestions() async {
    try {
      final questionsSnapshot = await FirebaseFirestore.instance
          .collection('sponsor_activities')
          .doc(widget.activityId)
          .collection('questions')
          .get();

      final questions = questionsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'question_text': data['question_text'],
          'options': data['options'],
          'correct_answer': data['correct_answer'],
          'created_at': data['created_at'],
        };
      }).toList();

      final finalQuestions = questions.isNotEmpty
          ? questions
          : widget.questions.map<Map<String, dynamic>>((q) {
              return {
                'id': q['id'] ?? UniqueKey().toString(),
                'question_text': q['question_text'],
                'options': q['options'],
                'correct_answer': q['correct_answer'],
              };
            }).toList();

      setState(() {
        _questions = finalQuestions;
        _answers = List<String?>.filled(finalQuestions.length, null);
        _loadingQuestions = false;
      });

      _animController.forward();
    } catch (e) {
      debugPrint("Error loading questions: $e");
      setState(() {
        _loadingQuestions = false;
      });
    }
  }

  Future<void> _saveAbandonedAttempt() async {
    final attemptData = {
      'activityId': widget.activityId,
      'activityTitle': widget.title,
      'description': widget.description,
      'sponsorName': widget.sponsorName,
      'rewardType': widget.rewardType,
      'rewardedItem': 0,
      'rewardCode': null,
      'rewardTitle': null,
      'rewardDescription': null,
      'score': 0,
      'totalQuestions': _questions.length,
      'answers': _answers,
      'timestamp': FieldValue.serverTimestamp(),
      'rewarded': false,
      'userId': widget.userId,
      'isAbandoned': true,
    };

    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(widget.userId);
      await userDoc.collection('quiz_attempts').doc(widget.activityId).set(attemptData, SetOptions(merge: true));
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'activitiesCompleted': FieldValue.increment(1)});
    } catch (e) {
      debugPrint("Error saving abandoned quiz attempt: $e");
    }
  }

  Future<bool> _onWillPop() async {
    final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Exit Quiz?"),
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

  void _onOptionSelected(int questionIndex, String option) {
    if (_submitted || _isSubmitting) return;

    setState(() {
      _answers[questionIndex] = option;
    });

    if (_autoAdvanceOnSelect) {
      if (questionIndex < _questions.length - 1) {
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted) {
            _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
          }
        });
      }
    }
  }

  Future<void> _submitQuiz() async {
    if (_submitted || _questions.isEmpty || _isSubmitting) return;

    for (int i = 0; i < _answers.length; i++) {
      if (_answers[i] == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please answer all questions before submitting")),
        );
        final idx = _answers.indexOf(null);
        if (idx != -1 && mounted) {
          _pageController.animateToPage(idx, duration: const Duration(milliseconds: 350), curve: Curves.ease);
        }
        return;
      }
    }

    setState(() {
      _submitted = true;
      _isSubmitting = true;
    });

    int score = 0;
    bool allCorrect = true;

    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (_answers[i] != null && _answers[i] == q['correct_answer']) {
        score++;
      } else {
        allCorrect = false;
      }
    }

    int finalRewardPoints = _rewardPoints;
    String? rewardCode;
    String? actualRewardType;
    String? rewardTitle;
    String? rewardDescription;

    try {
      if (allCorrect) {
        final rewardService = RewardAllocationService();
        final activityDoc = await FirebaseFirestore.instance
            .collection('sponsor_activities')
            .doc(widget.activityId)
            .get();

        if (activityDoc.exists) {
          final activityData = activityDoc.data()!;
          final sponsorId = activityData['sponsor_id'] as String?;
          final rewardAllocation = activityData['reward_allocation'] as Map<String, dynamic>?;
          final rewardId = rewardAllocation?['reward_id'] as String?;

          if (sponsorId != null && rewardId != null) {
            final rewardResult = await rewardService.allocateRewardToUser(
              activityId: widget.activityId,
              userId: widget.userId,
              sponsorId: sponsorId,
              rewardId: rewardId,
            );

            if (rewardResult != null) {
              finalRewardPoints = rewardResult['reward_value'] as int? ?? 0;
              rewardCode = rewardResult['reward_code'] as String?;
              actualRewardType = rewardResult['reward_type'] as String? ?? 'points';
              rewardTitle = rewardResult['reward_title'] as String? ?? 'Reward';
              rewardDescription = rewardResult['reward_description'] as String? ?? '';
            }
          }
        }
      }

      final attemptData = {
        'activityId': widget.activityId,
        'activityTitle': widget.title,
        'description': widget.description,
        'sponsorName': widget.sponsorName,
        'rewardType': actualRewardType ?? widget.rewardType,
        'rewardedItem': finalRewardPoints,
        'rewardCode': rewardCode,
        'rewardTitle': rewardTitle,
        'rewardDescription': rewardDescription,
        'score': score,
        'totalQuestions': _questions.length,
        'answers': _answers,
        'timestamp': FieldValue.serverTimestamp(),
        'rewarded': allCorrect,
        'userId': widget.userId,
      };

      final userDoc = FirebaseFirestore.instance.collection('users').doc(widget.userId);
      await userDoc.collection('quiz_attempts').doc(widget.activityId).set(attemptData);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'activitiesCompleted': FieldValue.increment(1)});

      if (mounted) {
        try {
          Provider.of<QuizProvider>(context, listen: false).markAttempted(widget.activityId);
        } catch (_) {}
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => QuizResultPage(
              activityId: widget.activityId,
              title: widget.title,
              description: widget.description,
              sponsorName: widget.sponsorName,
              sponsorLogo: widget.sponsorLogo,
              rewardType: actualRewardType ?? widget.rewardType,
              rewardedItem: widget.rewardedItem,
              questions: _questions,
              answers: _answers,
              score: score,
              rewarded: allCorrect,
              rewardPoints: finalRewardPoints,
              userId: widget.userId,
              rewardCode: rewardCode,
              rewardTitle: rewardTitle,
              rewardDescription: rewardDescription,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error saving quiz attempt: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error submitting quiz: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
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
                    child: const Icon(Icons.quiz, color: Colors.orange, size: 32),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Quiz Instructions',
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
                        'Please read each question carefully before selecting your answer.',
                        style: TextStyle(fontSize: 16, height: 1.6),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '• Once the quiz begins, you cannot pause or exit midway — doing so will still mark it as completed.',
                        style: TextStyle(fontSize: 16, height: 1.6),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Your responses will be used by the app to improve content quality and user experience.',
                        style: TextStyle(fontSize: 16, height: 1.6),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Your data will remain private and secure — it will not be shared with any third party.',
                        style: TextStyle(fontSize: 16, height: 1.6),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Rewards or points will be awarded after successful completion of the quiz.',
                        style: TextStyle(fontSize: 16, height: 1.6),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Multiple attempts for the same quiz are not allowed unless specified.',
                        style: TextStyle(fontSize: 16, height: 1.6),
                      ),
                      const SizedBox(height: 16),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black),
                          children: [
                            const TextSpan(text: 'By participating, you agree to the app’s '),
                            TextSpan(
                              text: 'Terms & Conditions',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                              recognizer: TapGestureRecognizer()..onTap = () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Opening Terms & Conditions...")),
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
                              recognizer: TapGestureRecognizer()..onTap = () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Opening Privacy Policy...")),
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
                    '✅ I Understand – Start Quiz',
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

  Widget _buildHeader() {
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: _animController, curve: Curves.easeOut),
      axisAlignment: -1,
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.orange.shade700,
            backgroundImage: widget.sponsorLogo.isNotEmpty ? NetworkImage(widget.sponsorLogo) : null,
            child: widget.sponsorLogo.isEmpty
                ? Text(
                    widget.sponsorName.isNotEmpty ? widget.sponsorName[0].toUpperCase() : 'S',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                  )
                : null,
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
                  Text("Reward: ${_rewardPoints > 0 ? '$_rewardPoints points' : 'No reward'}"),
                const SizedBox(height: 6),
                Text(widget.title, style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
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
    );
  }

  Widget _buildQuestionCard(int index) {
    final q = _questions[index];
    final options = List<String>.from((q['options'] as List<dynamic>?) ?? []);
    final userSelection = _answers[index];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Question ${index + 1}",
                style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                q['question_text'] ?? '—',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              ...List.generate(options.length, (optIndex) {
                final option = options[optIndex];
                final isSelected = userSelection == option;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () {
                      _onOptionSelected(index, option);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.orange.shade50 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: isSelected ? Colors.orange.shade700 : Colors.grey.shade300, width: isSelected ? 1.8 : 1),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                )
                              ]
                            : [],
                      ),
                      child: Row(
                        children: [
                          Container(
                            height: 26,
                            width: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: isSelected ? Colors.orange.shade700 : Colors.grey.shade400),
                              color: isSelected ? Colors.orange.shade700 : Colors.transparent,
                            ),
                            child: Center(
                              child: isSelected
                                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                                  : Text(
                                      String.fromCharCode(65 + optIndex),
                                      style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.grey.shade700, fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(fontSize: 15, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPager() {
    if (_questions.isEmpty) {
      return const Center(
        child: Text("No questions available for this quiz.", style: TextStyle(fontSize: 16, color: Colors.grey)),
      );
    }

    return PageView.builder(
      controller: _pageController,
      physics: const BouncingScrollPhysics(),
      itemCount: _questions.length,
      onPageChanged: (idx) {
        setState(() {
          _currentIndex = idx;
        });
      },
      itemBuilder: (context, index) {
        return _buildQuestionCard(index);
      },
    );
  }

  Widget _buildBottomControls() {
    final isLast = _currentIndex == _questions.length - 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(_questions.length, (i) {
              final answered = _answers[i] != null;
              final active = i == _currentIndex;
              return GestureDetector(
                onTap: () {
                  _pageController.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.ease);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: active ? 12 : 8,
                  width: active ? 32 : 12,
                  decoration: BoxDecoration(
                    color: answered ? Colors.orange.shade700 : (active ? Colors.orange.shade300 : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _currentIndex > 0 && !_isSubmitting ? () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut) : null,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text("Back"),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.orange.shade700),
                  foregroundColor: Colors.orange.shade700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (!isLast)
              Expanded(
                child: ElevatedButton(
                  onPressed: !_isSubmitting
                      ? () {
                          _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("Next"),
                ),
              )
            else
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitQuiz,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isSubmitting
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text("Submitting..."),
                            SizedBox(width: 8),
                            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                          ],
                        )
                      : const Text("Submit Quiz"),
                ),
              ),
          ],
        ),
      ],
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
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text("Quiz"),
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
                      const Text("• Answer questions one-by-one. Tap an option to select and auto-advance."),
                      const SizedBox(height: 4),
                      const Text("• Use Back/Next to navigate."),
                      const SizedBox(height: 4),
                      const Text("• Submit at the end. The attempt will be recorded immediately."),
                      const SizedBox(height: 12),
                      Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.pop(context), child: const Text("Got it"))),
                    ]),
                  ),
                );
              },
            )
          ],
        ),
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _loadingQuestions
                          ? Center(
                              key: const ValueKey('loader'),
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
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade200),
                                        ),
                                        const Icon(Icons.quiz, size: 40, color: Colors.orange),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text("Preparing questions...", style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            )
                          : _buildPager(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildBottomControls(),
                ],
              ),
            ),
            if (_isSubmitting)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.4),
                  child: const Center(
                    child: Card(
                      elevation: 10,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text("Submitting your answers...", style: TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}