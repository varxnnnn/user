import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:giftardo/providers/auth_provider.dart';
import 'package:giftardo/ui/screens/login_screen.dart';
import 'package:giftardo/main_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Show loading screen while checking authentication state
        if (!authProvider.isInitialized) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Show login screen if user is not authenticated
        if (!authProvider.isAuthenticated) {
          return const LoginScreen();
        }

        // Show main screen if user is authenticated
        return const MainScreen();
      },
    );
  }
}

