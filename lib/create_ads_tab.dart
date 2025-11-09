import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class CreateAdsTab extends StatefulWidget {
  const CreateAdsTab({super.key});

  @override
  _CreateAdsTabState createState() => _CreateAdsTabState();
}

class _CreateAdsTabState extends State<CreateAdsTab> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController linkController = TextEditingController();
  
  bool loading = false;
  File? adImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        adImage = File(image.path);
      });
    }
  }

  Future<String?> uploadImage() async {
    if (adImage == null) return null;

    final String fileName = path.basename(adImage!.path);
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String storagePath = 'ads/$timestamp-$fileName';

    try {
      final Reference ref = FirebaseStorage.instance.ref().child(storagePath);
      await ref.putFile(adImage!);
      return await ref.getDownloadURL();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image: $e')),
      );
      return null;
    }
  }

  Future<void> createAd() async {
    if (titleController.text.trim().isEmpty || 
        descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill title and description")),
      );
      return;
    }

    if (adImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an image")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      String? imageUrl = await uploadImage();
      if (imageUrl == null) {
        setState(() => loading = false);
        return;
      }

      await FirebaseFirestore.instance.collection('ads').add({
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'image_url': imageUrl,
        'link': linkController.text.trim().isEmpty ? null : linkController.text.trim(),
        'status': 'active',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ad created successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      // Clear fields
      titleController.clear();
      descriptionController.clear();
      linkController.clear();
      setState(() {
        adImage = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error creating ad: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Create New Ad",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          // Image Picker
          GestureDetector(
            onTap: pickImage,
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey, width: 2, style: BorderStyle.solid),
              ),
              child: adImage == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate, size: 50, color: Colors.grey),
                        SizedBox(height: 10),
                        Text("Tap to select image", style: TextStyle(color: Colors.grey)),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(adImage!, fit: BoxFit.cover),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          
          TextField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: "Title *",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: descriptionController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: "Description *",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: linkController,
            decoration: const InputDecoration(
              labelText: "Link (optional)",
              border: OutlineInputBorder(),
              hintText: "https://example.com",
            ),
          ),
          const SizedBox(height: 30),
          
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: loading ? null : createAd,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Create Ad", style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    linkController.dispose();
    super.dispose();
  }
}