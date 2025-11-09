import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_dashboard.dart';
import 'sponsor_dashboard.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool loading = false;
  String role = "admin"; // default role selection for login

  @override
  void initState() {
    super.initState();
    _checkLoggedIn();
  }

  Future<void> _checkLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? adminId = prefs.getString('adminId');
    String? sponsorId = prefs.getString('sponsorId');

    if (adminId != null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminDashboard()));
    } else if (sponsorId != null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SponsorDashboard()));
    }
  }

  Future<void> login() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => loading = true);

    try {
      final db = FirebaseFirestore.instance;

      if (role == "admin") {
        // Check admin collection for email
        QuerySnapshot snapshot = await db.collection("admins")
            .where("email", isEqualTo: emailController.text.trim())
            .get();

        if (snapshot.docs.isNotEmpty) {
          String adminId = snapshot.docs.first.id;
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('adminId', adminId);

          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminDashboard()));
          return;
        }
      } else if (role == "sponsor") {
        // Check sponsor collection for email
        QuerySnapshot snapshot = await db.collection("sponsors")
            .where("email", isEqualTo: emailController.text.trim())
            .get();

        if (snapshot.docs.isNotEmpty) {
          String sponsorId = snapshot.docs.first.id;
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('sponsorId', sponsorId);

          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SponsorDashboard()));
          return;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid credentials or role")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login failed: $e")));
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Text("Welcome Back!", style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            const Text("Login to continue", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            DropdownButtonFormField<String>(
              value: role,
              items: const [
                DropdownMenuItem(value: "admin", child: Text("Admin")),
                DropdownMenuItem(value: "sponsor", child: Text("Sponsor")),
              ],
              onChanged: (val) => setState(() => role = val!),
              decoration: const InputDecoration(labelText: "Role", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: loading ? null : login,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Login"),
              ),
            ),
            const SizedBox(height: 20),
            if (role == "sponsor") ...[
              const Divider(),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?"),
                  TextButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupPage()));
                    },
                    child: const Text(
                      "Sign Up",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
