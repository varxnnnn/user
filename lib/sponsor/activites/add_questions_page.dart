import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class AddQuestionsPage extends StatefulWidget {
  final String title;
  final String description;
  final String type;
  final int minAge;
  final int maxAge;
  final String sponsorId;
  final String rewardId;
  final int allocatedQty;
  final int attemptsAllowed;
  final String? sponsorProfilePic;
  final DateTime startDate;
  final DateTime endDate;
  final String rewardDistributionType;

  const AddQuestionsPage({
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
    this.sponsorProfilePic,
    required this.startDate,
    required this.endDate,
    required this.rewardDistributionType,
  });

  @override
  State<AddQuestionsPage> createState() => _AddQuestionsPageState();
}

class _AddQuestionsPageState extends State<AddQuestionsPage> {
  List<Map<String, dynamic>> questions = [];
  final TextEditingController questionController = TextEditingController();
  List<TextEditingController> optionControllers = [TextEditingController(), TextEditingController()];
  int? correctOptionIndex;

  bool loading = false;

  void addOption() => setState(() => optionControllers.add(TextEditingController()));

  void removeOption(int index) {
    if (optionControllers.length <= 2) return;
    setState(() {
      if (correctOptionIndex != null && correctOptionIndex! >= index) correctOptionIndex = correctOptionIndex! - 1;
      optionControllers.removeAt(index);
    });
  }

  void addQuestion() {
    if (questionController.text.isEmpty || optionControllers.any((c) => c.text.isEmpty) || correctOptionIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    final qData = {
      "question_text": questionController.text.trim(),
      "options": optionControllers.map((c) => c.text.trim()).toList(),
      "correct_answer": optionControllers[correctOptionIndex!].text.trim(),
    };

    setState(() {
      questions.add(qData);
      questionController.clear();
      optionControllers = [TextEditingController(), TextEditingController()];
      correctOptionIndex = null;
    });
  }

  Future<void> createActivity() async {
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Add at least 1 question")));
      return;
    }

    setState(() => loading = true);

    try {
      final String activityId = const Uuid().v4();
      // Get sponsor details
      final sponsorDoc = await FirebaseFirestore.instance
          .collection('sponsors')
          .doc(widget.sponsorId)
          .get();
      
      final sponsorData = sponsorDoc.data() ?? {};

      final activityData = {
        "title": widget.title,
        "description": widget.description,
        "type": widget.type,
        "sponsor_id": widget.sponsorId,
        "sponsor_details": {
          "name": sponsorData['name'],
          "profile_pic": sponsorData['profile_pic'],
          "contact_person": sponsorData['contact_person'],
          "email": sponsorData['email'],
          "phone": sponsorData['phone'],
        },
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

      // 1️⃣ Save activity in main collection
      await FirebaseFirestore.instance.collection("sponsor_activities").doc(activityId).set(activityData);

      // 2️⃣ Save under sponsor's subcollection
      final sponsorActivityRef = FirebaseFirestore.instance
          .collection("sponsors")
          .doc(widget.sponsorId)
          .collection("activities")
          .doc(activityId);

      await sponsorActivityRef.set(activityData);

      // 3️⃣ Save questions in main collection, activity subcollection & sponsor subcollection
      final questionsRef = FirebaseFirestore.instance.collection("activity_questions");
      for (var q in questions) {
        final qId = const Uuid().v4();
        final qDataWithId = {
          ...q,
          "activity_id": activityId,
          "created_at": FieldValue.serverTimestamp(),
        };

        // Main questions collection
        await questionsRef.doc(qId).set(qDataWithId);

        // Activity subcollection
        await FirebaseFirestore.instance
            .collection("sponsor_activities")
            .doc(activityId)
            .collection("questions")
            .doc(qId)
            .set(qDataWithId);

        // Sponsor's activity questions subcollection
        await sponsorActivityRef.collection("questions").doc(qId).set(qDataWithId);
      }

      // 4️⃣ Update reward available_quantity and assign reward items to activity
      final rewardRef = FirebaseFirestore.instance.collection('sponsor_rewards').doc(widget.rewardId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Read the current reward data first
        final snapshot = await transaction.get(rewardRef);
        
        if (!snapshot.exists) {
          throw Exception('Reward not found');
        }
        
        final currentQuantity = snapshot.data()?['available_quantity'] ?? 0;
        final newQuantity = currentQuantity - widget.allocatedQty;
        
        // Update the reward with new available quantity
        transaction.update(rewardRef, {
          "available_quantity": newQuantity < 0 ? 0 : newQuantity,
          "updated_at": FieldValue.serverTimestamp(),
        });
      });

      // 5️⃣ Assign specific reward items to this activity
      await _assignRewardItemsToActivity(activityId, widget.rewardId, widget.allocatedQty);

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Activity created successfully")));
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Step 3: Add Questions")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: questionController, decoration: const InputDecoration(labelText: "Question", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: optionControllers.length,
              itemBuilder: (context, index) {
                return Row(
                  children: [
                    Radio<int>(
                        value: index,
                        groupValue: correctOptionIndex,
                        onChanged: (val) => setState(() => correctOptionIndex = val)),
                    Expanded(
                        child: TextField(
                          controller: optionControllers[index],
                          decoration: InputDecoration(labelText: "Option ${index + 1}", border: const OutlineInputBorder()),
                        )),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => removeOption(index)),
                  ],
                );
              },
            ),
            TextButton.icon(onPressed: addOption, icon: const Icon(Icons.add), label: const Text("Add Option")),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: addQuestion, child: const Text("Add Question to Activity")),
            const SizedBox(height: 20),
            const Text("Questions Preview", style: TextStyle(fontWeight: FontWeight.bold)),
            ...questions.map((q) => Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                title: Text(q['question_text']),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(q['options'].length, (i) => Text("${i + 1}. ${q['options'][i]}")) +
                      [Text("Answer: ${q['correct_answer']}", style: const TextStyle(fontWeight: FontWeight.bold))],
                ),
              ),
            )),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : createActivity,
                child: loading ? const CircularProgressIndicator(color: Colors.white) : const Text("Create Activity"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assignRewardItemsToActivity(String activityId, String rewardId, int allocatedQty) async {
    try {
      // Get available reward items
      final rewardItemsQuery = await FirebaseFirestore.instance
          .collection('sponsor_rewards')
          .doc(rewardId)
          .collection('items')
          .where('status', isEqualTo: 'available')
          .limit(allocatedQty)
          .get();

      if (rewardItemsQuery.docs.length < allocatedQty) {
        throw Exception('Not enough available reward items. Available: ${rewardItemsQuery.docs.length}, Required: $allocatedQty');
      }

      // Update the selected items to assigned status
      final batch = FirebaseFirestore.instance.batch();
      
      for (final doc in rewardItemsQuery.docs) {
        batch.update(doc.reference, {
          'status': 'assigned',
          'activity_id': activityId,
          'assigned_at': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // Also update the activity's reward allocation with the assigned item IDs
      final assignedItemIds = rewardItemsQuery.docs.map((doc) => doc.id).toList();
      
      await FirebaseFirestore.instance
          .collection('sponsor_activities')
          .doc(activityId)
          .update({
        'reward_allocation.assigned_item_ids': assignedItemIds,
        'reward_allocation.assigned_at': FieldValue.serverTimestamp(),
      });

      // Update sponsor's activity as well
      await FirebaseFirestore.instance
          .collection('sponsors')
          .doc(widget.sponsorId)
          .collection('activities')
          .doc(activityId)
          .update({
        'reward_allocation.assigned_item_ids': assignedItemIds,
        'reward_allocation.assigned_at': FieldValue.serverTimestamp(),
      });

    } catch (e) {
      print('Error assigning reward items: $e');
      rethrow;
    }
  }
}