import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'Screens/ChatPage.dart';
import 'Screens/Profile.dart';
import 'Screens/AstrologersHome.dart'; // Import AstrologersHome screen
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure widgets are initialized
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ); // Initialize Firebase
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool? isProfileSaved;
  bool? isAstrologerLoggedIn;

  @override
  void initState() {
    super.initState();
    _checkIfProfileOrAstrologerExists(); // Check for saved profile or astrologer login
  }

  // Check if profile or astrologer data is already saved in SharedPreferences
  Future<void> _checkIfProfileOrAstrologerExists() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Check if profile exists
    String? name = prefs.getString('name');
    // Check if astrologer is logged in
    String? astrologerPhone = prefs.getString('astrologer_phone');

    setState(() {
      // If astrologerPhone exists, load AstrologersHome, else check for profile
      if (astrologerPhone != null) {
        isAstrologerLoggedIn = true;
      } else {
        isProfileSaved = name != null; // If profile exists, set true, else false
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isProfileSaved == null && isAstrologerLoggedIn == null) {
      // While checking for SharedPreferences, show a loading indicator
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(), // Loading indicator
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'StarSync App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // Load AstrologersHome if astrologer is logged in, otherwise ProfilePage or ChatPage
      home: isAstrologerLoggedIn == true
          ? AstrologersHome()
          : (isProfileSaved! ? ChatPage() : ProfilePage()),
    );
  }
}
