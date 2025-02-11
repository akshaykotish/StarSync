import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:starsyncapp/PushNotificationService.dart';
import 'package:workmanager/workmanager.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'Screens/ChatPage.dart';
import 'Screens/Profile.dart';
import 'Screens/AstrologersHome.dart';
import 'WorkBench.dart';
import 'firebase_options.dart';

void main() async {
  // Ensure Flutter widgets are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Firebase App Check
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug, // Use debug for testing
    appleProvider: AppleProvider.debug, // Use debug for testing
  );

  // Initialize Push Notifications
  await NotificationService.instance.initialize();

  // Initialize Firebase In-App Messaging
  FirebaseInAppMessaging.instance;

  // Initialize Workmanager for background tasks
  Workmanager().initialize(
    callbackDispatcher, // Top-level function for background tasks
    isInDebugMode: false, // Set to true for debugging
  );

  // Register a periodic background task
  Workmanager().registerPeriodicTask(
    "starsyync",
    "checkForUpdatesTask",
    frequency: Duration(minutes: 15), // Adjust frequency as needed
  );

  // Run the app
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
  late FirebaseAnalytics analytics;
  late FirebaseAnalyticsObserver observer;

  @override
  void initState() {
    super.initState();

    // Initialize Firebase Analytics
    analytics = FirebaseAnalytics.instance;
    observer = FirebaseAnalyticsObserver(analytics: analytics);

    // Log app start event
    analytics.logEvent(name: 'app_started');

    // Enable analytics collection
    analytics.setAnalyticsCollectionEnabled(true);

    // Sign in anonymously if no user is signed in
    signInAnonymously();

    // Check if profile or astrologer data exists
    _checkIfProfileOrAstrologerExists();
  }

  // Sign in anonymously
  Future<void> signInAnonymously() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
        print('User signed in anonymously');
        analytics.logEvent(name: 'user_signed_in_anonymously');
      } on FirebaseAuthException catch (e) {
        print('Error signing in: ${e.code} - ${e.message}');
      }
    }
  }

  // Check if profile or astrologer data exists in SharedPreferences
  Future<void> _checkIfProfileOrAstrologerExists() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Check if profile exists
    String? name = prefs.getString('name');

    // Check if astrologer is logged in
    String? astrologerPhone = prefs.getString('astrologer_phone');

    setState(() {
      isAstrologerLoggedIn = astrologerPhone != null;
      isProfileSaved = name != null;

      // Log events based on conditions
      if (isAstrologerLoggedIn!) {
        analytics.logEvent(name: 'astrologer_logged_in');
      } else if (isProfileSaved!) {
        analytics.logEvent(name: 'profile_exists');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator while checking SharedPreferences
    if (isProfileSaved == null && isAstrologerLoggedIn == null) {
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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      navigatorObservers: [observer], // Add FirebaseAnalyticsObserver
      // Load appropriate screen based on conditions
      home: isAstrologerLoggedIn == true
          ? AstrologersHome()
          : (isProfileSaved! ? ChatPage() : ProfilePage()),
    );
  }
}