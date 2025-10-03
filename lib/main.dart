import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'ui/screens/login_screen.dart';
import 'providers/wallet_provider.dart';
import 'providers/leaderboard_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/home_provider.dart';
import 'providers/reward_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/milestone_provider.dart';
import 'providers/poll_provider.dart';
import 'providers/quiz_provider.dart';
import 'providers/survey_provider.dart';
import 'providers/all_activities_provider.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
runApp(
  MultiProvider(
    providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (context) => WalletProvider()),
        ChangeNotifierProvider(create: (context) => HomeProvider()),
        ChangeNotifierProvider(create: (context) => MilestoneProvider()),
        ChangeNotifierProvider(create: (context) => LeaderboardProvider()),
        ChangeNotifierProvider(create: (context) => RewardProvider()),
        ChangeNotifierProvider(create: (context) => ProfileProvider()),
        ChangeNotifierProvider(create: (context) => PollProvider()),
        ChangeNotifierProvider(create: (_) => QuizProvider()),
        ChangeNotifierProvider(create: (_) => SurveyProvider()),
        ChangeNotifierProvider(create: (_) => AllActivitiesProvider())
      ],
      child: const MyApp(),
    ),
  );
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Giftardo', // Updated to match your app name
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        // Add other routes here later (e.g., '/main')
      },
    );
  }
}