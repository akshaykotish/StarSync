import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class BuyQuestionPage extends StatefulWidget {
  @override
  _BuyQuestionPageState createState() => _BuyQuestionPageState();
}

class _BuyQuestionPageState extends State<BuyQuestionPage> {
  bool _isPurchased = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final int cost = 100;
  final int margin = 20;
  final int tax = 10;
  final int price = 130;

  Future<void> buyQuestion() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? contactNumber = prefs.getString('contact_number'); // Fetch contact number from SharedPreferences

    if (contactNumber != null) {
      String purchaseId = Uuid().v4(); // Generate unique purchase ID

      try {
        // Store purchase information in 'purchase' collection
        await _firestore.collection('purchase').doc(purchaseId).set({
          'purchase_id': purchaseId,
          'user_id': contactNumber,
          'cost': cost,
          'margin': margin,
          'tax': tax,
          'price': price,
          'timestamp': Timestamp.now(),
        });

        // Link purchase to user's purchase history
        await _firestore
            .collection('users')
            .doc(contactNumber)
            .collection('purchases')
            .doc(purchaseId)
            .set({
          'purchase_id': purchaseId,
          'timestamp': Timestamp.now(),
        });

        // Fetch current available questions
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(contactNumber).get();
        int availableQuestions = userDoc.exists && (userDoc.data() as Map<String, dynamic>).containsKey('available_questions')
            ? (userDoc.data() as Map<String, dynamic>)['available_questions']
            : 0;

        // Increment available questions by 1
        await _firestore.collection('users').doc(contactNumber).update({
          'available_questions': availableQuestions + 1,
        });

        setState(() {
          _isPurchased = true;
        });

        // Return to the previous screen with a result indicating purchase success
        Timer(Duration(seconds: 3), (){
          Navigator.pop(context, true);
        });

      } catch (e) {
        print("Error purchasing question: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error purchasing question.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Buy Question"),
        backgroundColor: Colors.amber[800],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_isPurchased)
              ElevatedButton(
                onPressed: buyQuestion,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.amber[800],
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  "Buy a Question",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            if (_isPurchased)
              Column(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 80),
                  SizedBox(height: 10),
                  Text(
                    "Purchase Complete!",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text("You can now ask your question."),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
