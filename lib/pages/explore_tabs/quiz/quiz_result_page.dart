import 'package:flutter/material.dart';

class QuizResultPage extends StatelessWidget {
  final String activityId;
  final String title;
  final String description;
  final String sponsorName;
  final String sponsorLogo;
  final String rewardType;
  final dynamic rewardedItem;
  final List<Map<String, dynamic>> questions;
  final List<String?> answers;
  final int score;
  final bool rewarded;
  final int rewardPoints;
  final String userId;
  final String? rewardCode;
  final String? rewardTitle;
  final String? rewardDescription;

  const QuizResultPage({
    Key? key,
    required this.activityId,
    required this.title,
    required this.description,
    required this.sponsorName,
    required this.sponsorLogo,
    required this.rewardType,
    required this.rewardedItem,
    required this.questions,
    required this.answers,
    required this.score,
    required this.rewarded,
    required this.rewardPoints,
    required this.userId,
    this.rewardCode,
    this.rewardTitle,
    this.rewardDescription,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quiz Results"),
        centerTitle: true,
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            Expanded(child: _buildAnalysis()),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  String _getRewardDisplayText() {
    if (!rewarded) {
      return "No reward";
    }

    switch (rewardType.toLowerCase()) {
      case 'points':
        return "Reward: $rewardPoints points";
      case 'voucher':
        return "Reward: ${rewardTitle ?? 'Voucher'} (Code: ${rewardCode ?? 'N/A'})";
      case 'product':
      case 'products':
        return "Reward: ${rewardTitle ?? 'Product'} (Code: ${rewardCode ?? 'N/A'})";
      default:
        return "Reward: ${rewardTitle ?? 'Reward'} (${rewardPoints} points)";
    }
  }

  String _getSuccessMessage() {
    if (!rewarded) {
      return "Better luck next time!";
    }

    switch (rewardType.toLowerCase()) {
      case 'points':
        return "Congratulations! You earned $rewardPoints points!";
      case 'voucher':
        return "Congratulations! You won a ${rewardTitle ?? 'voucher'}! Check your redemptions to claim it.";
      case 'product':
      case 'products':
        return "Congratulations! You won a ${rewardTitle ?? 'product'}! Check your redemptions to claim it.";
      default:
        return "Congratulations! You earned a reward!";
    }
  }

  Widget _buildHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.orange,
          child: Text(
            sponsorName[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sponsorName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(_getRewardDisplayText()),
              Text(title, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysis() {
    return ListView.builder(
      itemCount: questions.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          // Show overall score at top
          return Card(
            color: rewarded ? Colors.green[100] : Colors.orange[100],
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        rewarded ? Icons.check_circle : Icons.info,
                        color: rewarded ? Colors.green : Colors.orange,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Quiz Completed!",
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "Score: $score / ${questions.length}",
                              style: const TextStyle(fontSize: 18),
                            ),
                            Text(
                              _getSuccessMessage(),
                              style: TextStyle(
                                fontSize: 16,
                                color: rewarded
                                    ? Colors.green[700]
                                    : Colors.orange[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        final q = questions[index - 1];
        final userAnswer = answers[index - 1];
        final correctAnswer = q['correct_answer'];
        final isCorrect = userAnswer == correctAnswer;

        return Card(
          color: isCorrect ? Colors.green[50] : Colors.red[50],
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isCorrect ? Colors.green : Colors.red,
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
                    Icon(
                      isCorrect ? Icons.check_circle : Icons.cancel,
                      color: isCorrect ? Colors.green : Colors.red,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "${index}. ${q['question_text']}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCorrect ? Colors.green[100] : Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Your Answer: ${userAnswer ?? 'Not answered'}",
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: isCorrect
                              ? Colors.green[800]
                              : Colors.red[800],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Correct Answer: $correctAnswer",
                        style: TextStyle(
                          color: isCorrect
                              ? Colors.green[700]
                              : Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.home),
            label: const Text("Back to Home"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text("Back to Quiz"),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
