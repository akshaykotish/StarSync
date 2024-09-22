  import 'package:flutter/material.dart';
  import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

  class PickQuestionPage extends StatefulWidget {
    @override
    _PickQuestionPageState createState() => _PickQuestionPageState();
  }

  class _PickQuestionPageState extends State<PickQuestionPage> {
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    String? contactNumber; // Astrologer’s contact number

    @override
    void initState() {
      super.initState();
      _loadAstrologerContact();
    }


    Future<void> _loadAstrologerContact() async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      contactNumber = prefs.getString('astrologer_phone'); // Load astrologer phone from SharedPreferences

      if (contactNumber == null) {
        // Handle case when 'astrologer_phone' is not set
        print("No astrologer phone found in SharedPreferences");
      } else {
        print("Loaded astrologer phone: $contactNumber");
      }
    }


    Future<void> _assignQuestion(String userId, String questionId, String purchaseId) async {
      try {
        // 1. Remove the document from 'unassign' collection
        await _firestore.collection('unassign').doc(questionId).delete();


        print("KAMdK:- " + contactNumber.toString());
        // 2. Add the question document to 'answers' collection under 'astrologer' document
        await _firestore.collection('astrologers').doc(contactNumber)
            .collection('answers').doc(questionId).set({
          'user_id': userId,
          'question_id': questionId,
          'status': 'assigned',
          'astrologer_id': contactNumber,
          'timestamp': Timestamp.now(),
          'purchase_id': purchaseId, // You may want to store purchase details as well
        });

        // 3. Update the status in user's 'messages' collection to 'assigned'
        await _firestore.collection('users').doc(userId).collection('message').doc(questionId).update({
          'status': 'assigned',
          'astrologer_phone': contactNumber, // Optionally add astrologer info
        });

        // Show a success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Question assigned successfully!")),
        );
      } catch (e) {
        print("Error assigning question: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to assign question!")),
        );
      }
    }


    Widget _buildQuestionCard(DocumentSnapshot questionData) {
      String userId = questionData['user_id'];
      String questionId = questionData['question_id'];
      String purchaseId = questionData['purchase_id'];

      return GestureDetector(
        onTap: () {
          _showQuestionDetails(userId, questionId, purchaseId);
        },
        child: Card(
          elevation: 5,
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber[800]!, Colors.amber[400]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Question ID: $questionId", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                SizedBox(height: 5),
                Text("Status: ${questionData['status']}", style: TextStyle(color: Colors.white70)),
                SizedBox(height: 5),
                Text("User ID: $userId", style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
      );
    }

    void _showQuestionDetails(String userId, String questionId, String purchaseId) async {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      DocumentSnapshot questionDoc = await _firestore.collection('users').doc(userId).collection('message').doc(questionId).get();
      DocumentSnapshot purchaseDoc = await _firestore.collection('purchase').doc(purchaseId).get();

      var userData = userDoc.data() as Map<String, dynamic>;
      var questionData = questionDoc.data() as Map<String, dynamic>;
      var purchaseData = purchaseDoc.data() as Map<String, dynamic>;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        builder: (context) {
          return FractionallySizedBox(
            heightFactor: 0.95,
            child: Column(
              children: [
                // This part makes the content scrollable
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            "Question Details",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[800],
                            ),
                          ),
                        ),
                        SizedBox(height: 20),

                        // Full Question
                        Text(
                          "Full Question",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                        ),
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Text(
                            questionData['message_text'],
                            style: TextStyle(fontSize: 16, color: Colors.black87),
                          ),
                        ),

                        SizedBox(height: 20),

                        Divider(color: Colors.grey),

                        // User Profile (Kundali) in a Card
                        Text(
                          "Kundali",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                        ),
                        SizedBox(height: 8),
                        Card(
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildProfileInfoRow("Name:", userData['name']),
                                _buildProfileInfoRow("DOB:", userData['dob'].toString().substring(0, 10)),
                                _buildProfileInfoRow("Time of Birth:", userData['time_of_birth']),
                                _buildProfileInfoRow("Location:", userData['location']),
                                _buildProfileInfoRow("Gender:", userData['gender']),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: 20),

                        Divider(color: Colors.grey),

                        // Earnings for Astrologer
                        Text(
                          "Your Earning",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                        ),
                        SizedBox(height: 8),
                        Card(
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Cost Price (Earning):",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  "₹${purchaseData['cost']}",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[800]),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Accept and Reply button at the bottom
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        _assignQuestion(userId, questionId, purchaseId);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber[800],
                        padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text("Accept and Reply", style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }


  // Helper widget to display profile information row
    Widget _buildProfileInfoRow(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                value,
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ],
        ),
      );
    }




    @override
    Widget build(BuildContext context) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber[800]!, Colors.amber[400]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: 60), // For spacing
            Center(
              child: Text(
                "Pick a Question",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('unassign').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }

                    final questions = snapshot.data!.docs;

                    return ListView.builder(
                      itemCount: questions.length,
                      itemBuilder: (context, index) {
                        return _buildQuestionCard(questions[index]);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
