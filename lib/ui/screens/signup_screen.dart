// lib/ui/screens/signup_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:giftardo/providers/auth_provider.dart';
import 'otp_linking_screen.dart';
import 'package:giftardo/main_screen.dart';// 👈 NEW SCREEN

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  String _gender = "Male";

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                const Text(
                  "BestFreethings",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Create your account",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 5),
                const Text(
                  "Join and start winning!",
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 30),

                TextField(controller: _nameController, decoration: InputDecoration(labelText: "Name", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 15),
                TextField(controller: _emailController, decoration: InputDecoration(labelText: "Email", hintText: "hello@example.com", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 15),
                TextField(controller: _phoneController, decoration: InputDecoration(labelText: "Phone", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 15),
                TextField(controller: _passwordController, obscureText: true, decoration: InputDecoration(labelText: "Password", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), suffixIcon: const Icon(Icons.lock))),
                const SizedBox(height: 15),
                TextField(controller: _ageController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Age", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: _gender,
                  items: ['Male', 'Female', 'Other'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (value) => setState(() => _gender = value!),
                  decoration: InputDecoration(labelText: "Gender", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                ),
                const SizedBox(height: 15),
                TextField(controller: _locationController, decoration: InputDecoration(labelText: "Location", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 25),

                authProvider.isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: () async {
                          final email = _emailController.text.trim();
                          final password = _passwordController.text.trim();
                          final phone = _phoneController.text.trim();

                          if (email.isEmpty || password.isEmpty || phone.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please fill all required fields')),
                            );
                            return;
                          }

                          final success = await authProvider.requestOtpAndPrepareSignup(
                            email: email,
                            password: password,
                            name: _nameController.text.trim(),
                            phone: phone,
                            age: _ageController.text.trim().isEmpty ? null : int.tryParse(_ageController.text.trim()),
                            gender: _gender,
                            location: _locationController.text.trim(),
                          );

                          if (success) {
                            // Direct success (auto-verified)
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const MainScreen()),
                            );
                          } else if (authProvider.pendingVerificationId != null) {
                            // Show OTP linking screen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => OtpLinkingScreen(
                                  verificationId: authProvider.pendingVerificationId!,
                                  phoneNumber: phone,
                                ),
                              ),
                            );
                          }
                          // Else: error is shown via authProvider.error
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text("Sign Up"),
                      ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account?"),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Login", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    ),
                  ],
                ),

                if (authProvider.error != null) ...[
                  const SizedBox(height: 10),
                  Text(authProvider.error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}