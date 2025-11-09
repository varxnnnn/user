import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController contactPersonController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  bool loading = false;
  String role = "admin"; // default role
  File? profileImage;
  final ImagePicker _picker = ImagePicker();

  // 📸 Pick profile image
  Future<void> pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        profileImage = File(image.path);
      });
    }
  }

  // ☁️ Upload image to Firebase Storage
  Future<String?> uploadImage() async {
    if (profileImage == null) return null;

    final String fileName = path.basename(profileImage!.path);
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String storagePath = 'profile_pictures/$timestamp-$fileName';

    try {
      final Reference ref = FirebaseStorage.instance.ref().child(storagePath);
      await ref.putFile(profileImage!);
      return await ref.getDownloadURL();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image: $e')),
      );
      return null;
    }
  }

  // 🧾 Signup Function
  Future<void> signup() async {
    if (nameController.text.isEmpty || 
        emailController.text.isEmpty || 
        passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    // Validate password strength
    if (passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password must be at least 6 characters long")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      // Create Firebase Auth user
      final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      final User? user = userCredential.user;
      if (user == null) {
        throw Exception('Failed to create user account');
      }

      String? profilePicUrl;
      if (role == "sponsor" && profileImage != null) {
        profilePicUrl = await uploadImage();
        if (profilePicUrl == null) return; // Image upload failed
      }

      final now = Timestamp.now();
      final db = FirebaseFirestore.instance;
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String docId = "";

      // Set the user display name
      await user.updateDisplayName(nameController.text.trim());

      if (role == "admin") {
        // Create Admin document
        DocumentReference docRef = db.collection("admins").doc();
        await docRef.set({
          "name": nameController.text.trim(),
          "email": emailController.text.trim(),
          "phone": phoneController.text.trim(),
          "role": "superadmin",
          "created_at": now,
          "updated_at": now,
        });
        docId = docRef.id;
        await prefs.setString('adminId', docId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Admin created successfully!")),
        );
      } else if (role == "sponsor") {
        // Validate fields
        if (contactPersonController.text.isEmpty ||
            addressController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please fill all required fields")),
          );
          return;
        }
        if (profileImage == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please select a profile picture")),
          );
          return;
        }

        // Create Sponsor document
        DocumentReference docRef = db.collection("sponsors").doc();
        await docRef.set({
          "name": nameController.text.trim(),
          "contact_person": contactPersonController.text.trim(),
          "email": emailController.text.trim(),
          "phone": phoneController.text.trim(),
          "address": addressController.text.trim(),
          "status": "active",
          "created_at": now,
          "updated_at": now,
          "profile_pic": profilePicUrl,
        });
        docId = docRef.id;
        await prefs.setString('sponsorId', docId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sponsor created successfully!")),
        );
      }

      // Clear fields
      nameController.clear();
      emailController.clear();
      phoneController.clear();
      contactPersonController.clear();
      addressController.clear();
    } catch (e) {
      String errorMessage = "Error creating account";
      
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'weak-password':
            errorMessage = 'The password provided is too weak.';
            break;
          case 'email-already-in-use':
            errorMessage = 'An account already exists for this email.';
            break;
          case 'invalid-email':
            errorMessage = 'The email address is not valid.';
            break;
          default:
            errorMessage = e.message ?? 'Authentication error occurred.';
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );

      // If auth fails, cleanup any uploaded image
      if (profileImage != null) {
        try {
          final String fileName = path.basename(profileImage!.path);
          final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
          final String storagePath = 'profile_pictures/$timestamp-$fileName';
          await FirebaseStorage.instance.ref().child(storagePath).delete();
        } catch (e) {
          // Ignore cleanup errors
        }
      }
    } finally {
      setState(() => loading = false);
    }
  }

  // 🧱 UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Signup")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Text(
                "Create Account",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              const Text("Sign up to get started",
                  style: TextStyle(color: Colors.grey)),

              // 👤 Sponsor Image Picker
              if (role == "sponsor") ...[
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: pickImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: profileImage != null
                        ? ClipOval(
                            child: Image.file(
                              profileImage!,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(Icons.camera_alt, size: 40),
                  ),
                ),
              ],

              const SizedBox(height: 30),

              // 🧩 Role Selector
              DropdownButtonFormField<String>(
                value: role,
                items: const [
                  DropdownMenuItem(value: "admin", child: Text("Admin")),
                  DropdownMenuItem(value: "sponsor", child: Text("Sponsor")),
                ],
                onChanged: (val) => setState(() => role = val!),
                decoration: const InputDecoration(
                  labelText: "Role",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              // ✏️ Common Fields
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                    labelText: "Name", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                    labelText: "Email", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: "Password", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                    labelText: "Phone", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),

              // 🏢 Sponsor-specific Fields
              if (role == "sponsor") ...[
                TextField(
                  controller: contactPersonController,
                  decoration: const InputDecoration(
                    labelText: "Contact Person",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: "Address",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 🚀 Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: loading ? null : signup,
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Sign Up"),
                ),
              ),
              const SizedBox(height: 20),

              // 🔙 Go back
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Already have an account? Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
