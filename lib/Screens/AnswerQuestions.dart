import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'AstrologerChatPage.dart';

class AnswerQuestionsPage extends StatefulWidget {
  @override
  _AnswerQuestionsPageState createState() => _AnswerQuestionsPageState();
}

class _AnswerQuestionsPageState extends State<AnswerQuestionsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? astrologerId;

  @override
  void initState() {
    super.initState();
    _loadAstrologerContact();
  }

  Future<void> _loadAstrologerContact() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      astrologerId = prefs.getString('astrologer_phone');
    });
  }

  // Fetch question text from user's message collection
  Future<String?> _getQuestionText(String userId, String questionId) async {
    try {
      DocumentSnapshot questionDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('message')
          .doc(questionId)
          .get();

      if (questionDoc.exists) {
        return questionDoc['message_text'] as String;
      }
    } catch (e) {
      print("Error fetching question text: $e");
    }
    return null;
  }

  Widget _buildQuestionCard(DocumentSnapshot questionData) {
    String userId = questionData['user_id'];
    String questionId = questionData['question_id'];

    return FutureBuilder<String?>(
      future: _getQuestionText(userId, questionId), // Fetch question text
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Card(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text("Error loading question"),
              ),
            ),
          );
        }

        String questionText = snapshot.data ?? "No question text available";

        return GestureDetector(
          onTap: () {
            _navigateToChatPage(userId, questionId);
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
                  Text(
                    "Question: $questionText", // Show question text
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  SizedBox(height: 5),
                  Text("Status: ${questionData['status']}", style: TextStyle(color: Colors.white70)),
                  SizedBox(height: 5),
                  Text("User ID: $userId", style: TextStyle(color: Colors.white70)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _navigateToChatPage(String userId, String questionId) {
    // Navigate to the astrologer's chat page with userId and questionId
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AstrologerChatPage(
          userId: userId,
          questionId: questionId,
        ),
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
              "Answer Questions",
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
                stream: _firestore
                    .collection('astrologers')
                    .doc(astrologerId)
                    .collection('answers')
                    .snapshots(),
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