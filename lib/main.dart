import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart'; // Import FirebaseAnalytics
import 'package:firebase_analytics/observer.dart'; // Import FirebaseAnalyticsObserver
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:starsyncapp/PushNotificationService.dart';
import 'package:workmanager/workmanager.dart';
import 'Screens/ChatPage.dart';
import 'Screens/Profile.dart';
import 'Screens/AstrologersHome.dart'; // Import AstrologersHome screen
import 'WorkBench.dart';
import 'firebase_options.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';


void main() async {
  await WidgetsFlutterBinding.ensureInitialized(); // Ensure widgets are initialized
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ); // Initialize Firebase

  await NotificationService.instance.initialize();


  await FirebaseAppCheck.instance.activate(
    //androidProvider: AndroidProvider.playIntegrity,
    // For iOS, you might use AppleProvider.appAttest or AppleProvider.deviceCheck
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );

  FirebaseInAppMessaging fiam = FirebaseInAppMessaging.instance;

  Workmanager().initialize(
    callbackDispatcher, // The top level function
    isInDebugMode: false, // Set to true for debugging
  );

  // Register the background task
  Workmanager().registerPeriodicTask(
    "starsyync",
    "checkForUpdatesTask",
    frequency: Duration(minutes: 15), // Adjust the frequency as needed
  );

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

  // Declare FirebaseAnalytics and FirebaseAnalyticsObserver
  late FirebaseAnalytics analytics;
  late FirebaseAnalyticsObserver observer;
  // Instantiate the PushNotificationService

  @override
  void initState() {
    super.initState();

    FirebaseAnalytics.instance.logEvent(name: 'view_${this.runtimeType}');

    signInAnonymously();

    // Initialize FirebaseAnalytics and FirebaseAnalyticsObserver
    analytics = FirebaseAnalytics.instance;
    observer = FirebaseAnalyticsObserver(analytics: analytics);


    analytics.logEvent(name: "App_Logined", parameters: {'InMainFile': "Yes"}).then((value)=>print("EVENTJNJGN Logged"));
    analytics.setAnalyticsCollectionEnabled(true);

    _checkIfProfileOrAstrologerExists(); // Check for saved profile or astrologer login
  }

  signInAnonymously() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // User is not signed in, proceed to sign in
      await signInUser();
      analytics.logEvent(name: 'sign_in_anonymously');
    }
  }

  // Sign in anonymously
  Future<void> signInUser() async {
    try {
      await FirebaseAuth.instance.signInAnonymously();
      print('User signed in anonymously');
      analytics.logEvent(name: 'user_signed_in');
    } on FirebaseAuthException catch (e) {
      print('Error signing in: \${e.code} - \${e.message}');
    }
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
        analytics.logEvent(name: 'astrologer_logged_in');
        isAstrologerLoggedIn = true;
      } else {
        isProfileSaved = name != null;
        if (isProfileSaved!) {
          analytics.logEvent(name: 'profile_exists');
        } // If profile exists, set true, else false
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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      navigatorObservers: [observer], // Add FirebaseAnalyticsObserver
      // Load AstrologersHome if astrologer is logged in, otherwise ProfilePage or ChatPage
      home: isAstrologerLoggedIn == true
          ? AstrologersHome()
          : (isProfileSaved! ? ChatPage() : ProfilePage()),
    );
  }
}
