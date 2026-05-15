import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/user_list_screen.dart';

void main() async {
  debugPrint('DEBUG: main() started');
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('DEBUG: Widgets initialized');
  try {
    debugPrint('DEBUG: Initializing Firebase...');
    await Firebase.initializeApp();
    debugPrint('DEBUG: Firebase initialized successfully');
    runApp(
      const ProviderScope(
        child: AdminApp(),
      ),
    );
    debugPrint('DEBUG: runApp() called');
  } catch (e) {
    debugPrint('DEBUG: Firebase error: $e');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SelectableText('Error initializing Firebase: $e'),
          ),
        ),
      ),
    );
  }
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rice Mill Admin',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        primaryColor: Colors.teal,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
          primary: Colors.teal,
          secondary: Colors.tealAccent,
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: const UserListScreen(),
    );
  }
}
