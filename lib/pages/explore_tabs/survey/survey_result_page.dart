import 'package:flutter/material.dart';

class SurveyResultPage extends StatefulWidget {
  final String title;
  final String sponsorName;
  final String sponsorProfilePic;
  final List<Map<String, dynamic>> questions;
  final Map<int, dynamic> answers;
  final int rewardedItem;
  final String rewardType;
  final String? rewardCode;
  final String? rewardTitle;
  final String? rewardDescription;

  const SurveyResultPage({
    super.key,
    required this.title,
    required this.sponsorName,
    required this.sponsorProfilePic,
    required this.questions,
    required this.answers,
    required this.rewardedItem,
    required this.rewardType,
    this.rewardCode,
    this.rewardTitle,
    this.rewardDescription,
  });

  @override
  State<SurveyResultPage> createState() => _SurveyResultPageState();
}

class _SurveyResultPageState extends State<SurveyResultPage> {
  @override
  void initState() {
    super.initState();
    // Auto-close after 2.5 seconds and signal success
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.of(context).pop(true); // returns true to caller
      }
    });
  }

  Widget _buildAnswerDisplay(Map<String, dynamic> q, dynamic answer) {
    final type = q['question_type'];
    switch (type) {
      case 'short':
        return Text("Your Answer: ${answer ?? 'Not answered'}");
      case 'rating':
        return Text("Your Rating: ${answer ?? 'Not answered'}");
      case 'mcq':
        // Note: surveys don't store 'votes' like polls — so we skip progress bars
        // If you DO store votes, keep this logic. Otherwise, simplify.
        return Text("Your Answer: $answer");
      default:
        return Text("Answer: $answer (Unsupported type: $type)");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Survey Results"),
        centerTitle: true,
        backgroundColor: Colors.orange.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ]
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.questions.length + 2,
        itemBuilder: (context, index) {
          if (index == widget.questions.length + 1) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
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
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                      label: const Text("Back to Survey"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade700,
                        side: BorderSide(color: Colors.orange.shade700),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          if (index == 0) {
            return Card(
              color: Colors.orange.shade50,
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.sponsorName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                "Survey Completed!",
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                "Thank you for your valuable feedback!",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.rewardType.toLowerCase() == 'lucky_draw' 
                                    ? "Lucky Draw Participation: Results will be announced soon. Winners will be notified."
                                    : "You received: ${widget.rewardedItem} ${widget.rewardType}",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (widget.rewardCode != null ||
                        widget.rewardTitle != null ||
                        widget.rewardDescription != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.rewardTitle != null)
                              Text(
                                widget.rewardTitle!,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            if (widget.rewardDescription != null)
                              Text(widget.rewardDescription!),
                            if (widget.rewardCode != null)
                              Text(
                                "Code: ${widget.rewardCode}",
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          final q = widget.questions[index - 1];
          final answer = widget.answers[index - 1];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Colors.orange.shade200,
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
                        Icons.question_answer,
                        color: Colors.orange.shade700,
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
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: _buildAnswerDisplay(q, answer),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}