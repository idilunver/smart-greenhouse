import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/env.dart';

import 'pages/dashboard_page.dart';
import 'pages/ai_chat_page.dart';
import 'pages/charts_page.dart';
import 'pages/control_page.dart';

import 'pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: Env.firebaseApiKey,
      appId: Env.firebaseAppId,
      messagingSenderId: Env.firebaseMessagingSenderId,
      projectId: Env.firebaseProjectId,
      databaseURL: Env.firebaseDatabaseUrl,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        cardTheme: CardTheme(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      ),
      home: const LoginPage(),
    );
  }
}

// --- ANA NAVİGASYON ---
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  
  final List<Widget> _pages = [
    const DashboardPage(), 
    const AIChatAnalysisPage(), 
    const ChartsPage(), 
    const ControlPage()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Genel Bakış'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'AI Analiz'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: 'Grafik'),
          NavigationDestination(icon: Icon(Icons.settings_suggest_outlined), selectedIcon: Icon(Icons.settings_suggest), label: 'Kontrol'),
        ],
      ),
    );
  }
}