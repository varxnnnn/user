import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_screen.dart';

class AdditionalInfoScreen extends StatefulWidget {
  final User user;
  const AdditionalInfoScreen({super.key, required this.user});

  @override
  State<AdditionalInfoScreen> createState() => _AdditionalInfoScreenState();
}

class _AdditionalInfoScreenState extends State<AdditionalInfoScreen> {
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _locationController = TextEditingController();
  String _gender = "Male";
  bool _loading = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _saveAdditionalInfo() async {
    setState(() => _loading = true);
    try {
      await _firestore.collection('users').doc(widget.user.uid).set({
        'name': widget.user.displayName ?? 'Google User',
        'email': widget.user.email,
        'phone': _phoneController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()) ?? 0,
        'gender': _gender,
        'location': _locationController.text.trim(),
        'coins': 0,
        'uid': widget.user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const MainScreen()));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save info: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Additional Info")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: "Phone", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: _ageController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Age", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _gender,
              items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
              onChanged: (value) => setState(() => _gender = value!),
              decoration: const InputDecoration(labelText: "Gender", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(controller: _locationController, decoration: const InputDecoration(labelText: "Location", border: OutlineInputBorder())),
            const SizedBox(height: 20),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(onPressed: _saveAdditionalInfo, child: const Text("Submit")),
          ],
        ),
      ),
    );
  }
}
