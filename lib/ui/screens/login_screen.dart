import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:giftardo/providers/auth_provider.dart'; // Adjust path
import '../../main_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _showSnackBar(String message, {Color? color}) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  const Text(
                    "Giftardo",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Login\nWelcome back to the app.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),
                  Image.asset(
                    'assets/login_image.webp',
                    height: constraints.maxWidth > 600 ? 200 : 150,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: "Email Address",
                      hintText: "hello@example.com",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      suffixIcon: const Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 20),
                  authProvider.isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: () async {
                            final email = _emailController.text.trim();
                            final password = _passwordController.text.trim();
                            if (email.isEmpty || password.isEmpty) {
                              _showSnackBar(
                                'Please enter both email and password.',
                                color: Colors.red,
                              );
                              return;
                            }
                            // Basic email format check
                            if (!RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+',
                            ).hasMatch(email)) {
                              _showSnackBar(
                                'Invalid email format.',
                                color: Colors.red,
                              );
                              return;
                            }
                            await authProvider.signIn(email, password);
                            if (authProvider.error != null) {
                              String errorMsg = authProvider.error!
                                  .toLowerCase();
                              if (errorMsg.contains('user') &&
                                  errorMsg.contains('not found')) {
                                _showSnackBar(
                                  'No user exists for this email.',
                                  color: Colors.red,
                                );
                              } else if (errorMsg.contains('password') ||
                                  errorMsg.contains('credential') ||
                                  errorMsg.contains('malformed') ||
                                  errorMsg.contains('expire')) {
                                _showSnackBar(
                                  'Incorrect password.',
                                  color: Colors.red,
                                );
                              } else if (errorMsg.contains('email')) {
                                _showSnackBar(
                                  'Invalid email.',
                                  color: Colors.red,
                                );
                              } else {
                                _showSnackBar(
                                  authProvider.error!,
                                  color: Colors.red,
                                );
                              }
                            } else {
                              _showSnackBar(
                                'Login successful!',
                                color: Colors.green,
                              );
                              // Navigation is now handled by AuthWrapper
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 15,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text("Login"),
                        ),
                  const SizedBox(height: 20),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Create an account?"),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SignupScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          "Sign Up",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Remove error text widget, all errors now use snackbars
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
