import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'select_reward_page.dart';

class CreateActivityPage extends StatefulWidget {
  const CreateActivityPage({super.key});

  @override
  State<CreateActivityPage> createState() => _CreateActivityPageState();
}

class _CreateActivityPageState extends State<CreateActivityPage> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController minAgeController = TextEditingController(text: "18");
  final TextEditingController maxAgeController = TextEditingController(text: "60");
  final TextEditingController attemptsController = TextEditingController(text: "1");
  
  // New controllers for dates
  DateTime? startDate;
  DateTime? endDate;
  
  // New field for reward distribution type
  String rewardDistributionType = "first_come_first_serve"; // or "lucky_draw"
  final List<String> distributionTypes = ["first_come_first_serve", "lucky_draw"];

  String selectedType = "quiz";
  final List<String> activityTypes = ["quiz", "poll", "survey", "advertise_video"];
  String? sponsorId;
  String? sponsorProfilePic;

  @override
  void initState() {
    super.initState();
    loadSponsorId();
    // Set default dates
    startDate = DateTime.now();
    endDate = DateTime.now().add(const Duration(days: 30));
  }

  Future<void> loadSponsorId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? id = prefs.getString('sponsorId');
    if (id != null) {
      final doc = await FirebaseFirestore.instance.collection('sponsors').doc(id).get();
      final data = doc.data();
      setState(() {
        sponsorId = id;
        if (data != null && data['profile_pic'] != null) {
          sponsorProfilePic = data['profile_pic'];
        }
      });
    }
  }

  void goToRewardSelection() {
    if (titleController.text.isEmpty || 
        descriptionController.text.isEmpty || 
        attemptsController.text.isEmpty ||
        startDate == null || 
        endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields")));
      return;
    }
    
    if (startDate!.isAfter(endDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Start date must be before end date")));
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectRewardPage(
          title: titleController.text.trim(),
          description: descriptionController.text.trim(),
          type: selectedType,
          minAge: int.tryParse(minAgeController.text) ?? 18,
          maxAge: int.tryParse(maxAgeController.text) ?? 60,
          sponsorId: sponsorId!,
          attemptsAllowed: int.tryParse(attemptsController.text) ?? 1,
          sponsorProfilePic: sponsorProfilePic,
          startDate: startDate!,
          endDate: endDate!,
          rewardDistributionType: rewardDistributionType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Step 1: Activity Info")),
      body: sponsorId == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: "Title")),
            const SizedBox(height: 10),
            TextField(controller: descriptionController, decoration: const InputDecoration(labelText: "Description")),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedType,
              items: activityTypes.map((type) => DropdownMenuItem(value: type, child: Text(
                type == "advertise_video" ? "Advertise Video" : type
              ))).toList(),
              onChanged: (val) => setState(() => selectedType = val!),
              decoration: const InputDecoration(labelText: "Activity Type", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                    child: TextField(
                      controller: minAgeController,
                      decoration: const InputDecoration(labelText: "Min Age"),
                      keyboardType: TextInputType.number,
                    )),
                const SizedBox(width: 10),
                Expanded(
                    child: TextField(
                      controller: maxAgeController,
                      decoration: const InputDecoration(labelText: "Max Age"),
                      keyboardType: TextInputType.number,
                    )),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: attemptsController,
              decoration: const InputDecoration(labelText: "Attempts Allowed"),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            
            // Date pickers
            const Text("Participation Period", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text("Start Date"),
                    subtitle: Text(startDate != null 
                        ? "${startDate!.day}/${startDate!.month}/${startDate!.year}" 
                        : "Select start date"),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() {
                          startDate = picked;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ListTile(
                    title: const Text("End Date"),
                    subtitle: Text(endDate != null 
                        ? "${endDate!.day}/${endDate!.month}/${endDate!.year}" 
                        : "Select end date"),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: endDate ?? DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() {
                          endDate = picked;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Reward distribution type
            const Text("Reward Distribution", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: rewardDistributionType,
              items: distributionTypes.map((type) => DropdownMenuItem(
                value: type, 
                child: Text(
                  type == "first_come_first_serve" 
                    ? "First Come First Serve" 
                    : "Lucky Draw"
                )
              )).toList(),
              onChanged: (val) => setState(() => rewardDistributionType = val!),
              decoration: const InputDecoration(
                labelText: "Distribution Type", 
                border: OutlineInputBorder()
              ),
            ),
            
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: goToRewardSelection,
                child: const Text("Next: Select Reward"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}