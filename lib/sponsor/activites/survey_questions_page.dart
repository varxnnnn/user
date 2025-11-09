import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class AddSurveyQuestionsPage extends StatefulWidget {
  final String title;
  final String description;
  final String type;
  final int minAge;
  final int maxAge;
  final String sponsorId;
  final String rewardId;
  final int allocatedQty;
  final int attemptsAllowed;
  final DateTime startDate;
  final DateTime endDate;
  final String rewardDistributionType;

  const AddSurveyQuestionsPage({
    super.key,
    required this.title,
    required this.description,
    required this.type,
    required this.minAge,
    required this.maxAge,
    required this.sponsorId,
    required this.rewardId,
    required this.allocatedQty,
    required this.attemptsAllowed,
    required this.startDate,
    required this.endDate,
    required this.rewardDistributionType,
  });

  @override
  State<AddSurveyQuestionsPage> createState() => _AddSurveyQuestionsPageState();
}

class _AddSurveyQuestionsPageState extends State<AddSurveyQuestionsPage> {
  List<Map<String, dynamic>> questions = [];
  final TextEditingController questionController = TextEditingController();
  String selectedQuestionType = "mcq"; // mcq | short | rating
  List<TextEditingController> optionControllers = [TextEditingController(text: "Excellent"), TextEditingController(text: "Good"), TextEditingController(text: "Average")];
  bool loading = false;

  void addOption() => setState(() => optionControllers.add(TextEditingController()));

  void removeOption(int index) {
    if (optionControllers.length <= 1) return;
    setState(() {
      optionControllers.removeAt(index);
    });
  }

  void addQuestion() {
    if (questionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter question text")));
      return;
    }

    if (selectedQuestionType == "mcq" && optionControllers.any((c) => c.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all MCQ options")));
      return;
    }

    final qData = {
      "question_text": questionController.text.trim(),
      "question_type": selectedQuestionType,
      if (selectedQuestionType == "mcq") "options": optionControllers.map((c) => c.text.trim()).toList(),
    };

    setState(() {
      questions.add(qData);
      questionController.clear();
      selectedQuestionType = "mcq";
      optionControllers = [TextEditingController(text: "Excellent"), TextEditingController(text: "Good"), TextEditingController(text: "Average")];
    });
  }

  Future<void> createSurveyActivity() async {
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Add at least 1 question")));
      return;
    }

    setState(() => loading = true);

    try {
      final String activityId = const Uuid().v4();
      final activityData = {
        "title": widget.title,
        "description": widget.description,
        "type": widget.type,
        "sponsor_id": widget.sponsorId,
        "status": "active",
        "created_at": FieldValue.serverTimestamp(),
        "updated_at": FieldValue.serverTimestamp(),
        "start_date": widget.startDate,
        "end_date": widget.endDate,
        "reward_distribution_type": widget.rewardDistributionType,
        "rules": {"attempts_allowed": widget.attemptsAllowed},
        "targeting": {"min_age": widget.minAge, "max_age": widget.maxAge},
        "reward_allocation": {
          "reward_id": widget.rewardId,
          "allocated_quantity": widget.allocatedQty,
          "remaining_quantity": widget.allocatedQty,
        },
      };

      // Save activity
      await FirebaseFirestore.instance.collection("sponsor_activities").doc(activityId).set(activityData);
      final sponsorActivityRef = FirebaseFirestore.instance.collection("sponsors").doc(widget.sponsorId).collection("activities").doc(activityId);
      await sponsorActivityRef.set(activityData);

      // Save survey questions
      final questionsRef = FirebaseFirestore.instance.collection("survey_questions");
      for (var q in questions) {
        final qId = const Uuid().v4();
        final qDataWithId = {
          ...q,
          "activity_id": activityId,
          "created_at": FieldValue.serverTimestamp(),
        };

        await questionsRef.doc(qId).set(qDataWithId);
        await FirebaseFirestore.instance.collection("sponsor_activities").doc(activityId).collection("questions").doc(qId).set(qDataWithId);
        await sponsorActivityRef.collection("questions").doc(qId).set(qDataWithId);
      }

      // Update reward quantity & assign reward items (same as before)
      final rewardRef = FirebaseFirestore.instance.collection('sponsor_rewards').doc(widget.rewardId);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(rewardRef);
        if (!snapshot.exists) throw Exception('Reward not found');
        final currentQuantity = snapshot.data()?['available_quantity'] ?? 0;
        final newQuantity = currentQuantity - widget.allocatedQty;
        transaction.update(rewardRef, {
          "available_quantity": newQuantity < 0 ? 0 : newQuantity,
          "updated_at": FieldValue.serverTimestamp(),
        });
      });
      await _assignRewardItemsToActivity(activityId, widget.rewardId, widget.allocatedQty);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Survey created successfully")));
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    setState(() => loading = false);
  }

  Future<void> _assignRewardItemsToActivity(String activityId, String rewardId, int allocatedQty) async {
    try {
      final rewardItemsQuery = await FirebaseFirestore.instance.collection('sponsor_rewards').doc(rewardId).collection('items').where('status', isEqualTo: 'available').limit(allocatedQty).get();
      if (rewardItemsQuery.docs.length < allocatedQty) throw Exception('Not enough available reward items.');
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in rewardItemsQuery.docs) {
        batch.update(doc.reference, {'status': 'assigned', 'activity_id': activityId, 'assigned_at': FieldValue.serverTimestamp()});
      }
      await batch.commit();

      final assignedItemIds = rewardItemsQuery.docs.map((doc) => doc.id).toList();
      await FirebaseFirestore.instance.collection('sponsor_activities').doc(activityId).update({'reward_allocation.assigned_item_ids': assignedItemIds, 'reward_allocation.assigned_at': FieldValue.serverTimestamp()});
      await FirebaseFirestore.instance.collection('sponsors').doc(widget.sponsorId).collection('activities').doc(activityId).update({'reward_allocation.assigned_item_ids': assignedItemIds, 'reward_allocation.assigned_at': FieldValue.serverTimestamp()});
    } catch (e) {
      print('Error assigning reward items: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Step 3: Add Survey Questions")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: questionController, decoration: const InputDecoration(labelText: "Question", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedQuestionType,
              items: const [
                DropdownMenuItem(value: "mcq", child: Text("MCQ")),
                DropdownMenuItem(value: "short", child: Text("Short Text")),
                DropdownMenuItem(value: "rating", child: Text("Rating (1-5 stars)")),
              ],
              onChanged: (val) => setState(() => selectedQuestionType = val!),
              decoration: const InputDecoration(labelText: "Question Type", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            if (selectedQuestionType == "mcq")
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: optionControllers.length,
                itemBuilder: (context, index) {
                  return Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: optionControllers[index],
                          decoration: InputDecoration(labelText: "Option ${index + 1}", border: const OutlineInputBorder()),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => removeOption(index)),
                    ],
                  );
                },
              ),
            if (selectedQuestionType == "mcq")
              TextButton.icon(onPressed: addOption, icon: const Icon(Icons.add), label: const Text("Add Option")),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: addQuestion, child: const Text("Add Question to Survey")),
            const SizedBox(height: 20),
            const Text("Questions Preview", style: TextStyle(fontWeight: FontWeight.bold)),
            ...questions.map((q) => Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text(q['question_text']),
                subtitle: q['question_type'] == "mcq"
                    ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(
                    (q['options'] ?? []).length,
                        (i) => Text("${i + 1}. ${q['options'][i]}"),
                  ),
                )
                    : Text("Type: ${q['question_type']}"),
              ),
            )),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : createSurveyActivity,
                child: loading ? const CircularProgressIndicator(color: Colors.white) : const Text("Create Survey"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}