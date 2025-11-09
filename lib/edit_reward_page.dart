import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditRewardPage extends StatefulWidget {
  final String rewardId;
  final String sponsorId;
  final Map<String, dynamic> rewardData;

  const EditRewardPage({
    super.key,
    required this.rewardId,
    required this.sponsorId,
    required this.rewardData,
  });

  @override
  _EditRewardPageState createState() => _EditRewardPageState();
}

class _EditRewardPageState extends State<EditRewardPage> {
  late TextEditingController titleController;
  late TextEditingController descriptionController;
  late TextEditingController costController;
  late TextEditingController availableQuantityController;
  late String status;
  late String type;

  bool loading = false;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.rewardData['title']);
    descriptionController = TextEditingController(text: widget.rewardData['description']);
    costController = TextEditingController(text: widget.rewardData['cost_points'].toString());
    availableQuantityController = TextEditingController(text: widget.rewardData['available_quantity'].toString());
    status = widget.rewardData['status'] ?? 'active';
    type = widget.rewardData['type'] ?? 'points';
  }

  void saveReward() async {
    setState(() => loading = true);

    final updatedData = {
      "title": titleController.text,
      "description": descriptionController.text,
      "cost_points": int.tryParse(costController.text) ?? 0,
      "available_quantity": int.tryParse(availableQuantityController.text) ?? 0,
      "status": status,
      "type": type,
      "updated_at": FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('sponsor_rewards')
          .doc(widget.rewardId)
          .update(updatedData);

      // Update subcollection under sponsor
      final subCollectionQuery = await FirebaseFirestore.instance
          .collection('sponsors')
          .doc(widget.sponsorId)
          .collection('rewards')
          .where('title', isEqualTo: widget.rewardData['title'])
          .get();

      for (var doc in subCollectionQuery.docs) {
        await doc.reference.update(updatedData);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Reward updated successfully")),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Reward")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: "Title")),
            const SizedBox(height: 10),
            TextField(controller: descriptionController, decoration: const InputDecoration(labelText: "Description")),
            const SizedBox(height: 10),
            TextField(
              controller: costController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Cost Points"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: availableQuantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Available Quantity"),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: status,
              items: const [
                DropdownMenuItem(value: "active", child: Text("Active")),
                DropdownMenuItem(value: "inactive", child: Text("Inactive")),
              ],
              onChanged: (val) => status = val!,
              decoration: const InputDecoration(labelText: "Status"),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: type,
              items: const [
                DropdownMenuItem(value: "points", child: Text("Points")),
                DropdownMenuItem(value: "coins", child: Text("Coins")),
                DropdownMenuItem(value: "vouchers", child: Text("Vouchers")),
                DropdownMenuItem(value: "products", child: Text("Products")),
                DropdownMenuItem(value: "others", child: Text("Others")),
              ],
              onChanged: (val) => type = val!,
              decoration: const InputDecoration(labelText: "Type"),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: loading ? null : saveReward,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Save Changes"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
