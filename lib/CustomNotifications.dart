import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starsyncapp/PushNotificationService.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';


final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> startListeningCustomNotifications() async {

  SharedPreferences prefs = await SharedPreferences.getInstance();
  var userId = prefs.getString('contact_number');

  await WidgetsFlutterBinding.ensureInitialized(); // Ensure widgets are initialized
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ); // Initialize Firebase



  CollectionReference notificationsRef = FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('notifications');

  print("Listening Notification on background");

  // Set up the listener
  notificationsRef.snapshots().listen((QuerySnapshot querySnapshot) async {
    print("Receieved Notification on background");
    // Loop through document changes
    print(querySnapshot.docChanges.length);
    for (var change in querySnapshot.docChanges) {
      print("Social ${change.type}");
      if (change.type == DocumentChangeType.added) {
        // A new document has been added, call your function
        // Trigger notification when new data comes.
        print("MAJORSAYING");

        // Trigger notification when new data comes.
        flutterLocalNotificationsPlugin.show(
          0,
          'StarSyync astrologer send you a message',
          'You have a new message!',
          NotificationDetails(
            android: AndroidNotificationDetails(
              'channel_id',
              'channel_name',
              importance: Importance.max,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      }
    }
  });
}

