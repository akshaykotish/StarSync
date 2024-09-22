import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // For date and time formatting
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart'; // For generating unique IDs
import 'dart:async'; // For timer

class AstrologerChatPage extends StatefulWidget {
  final String userId;
  final String questionId;

  AstrologerChatPage({required this.userId, required this.questionId});

  @override
  _AstrologerChatPageState createState() => _AstrologerChatPageState();
}

class _AstrologerChatPageState extends State<AstrologerChatPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  String? astrologerId;
  String? userName;
  String? gender;
  String? usercontact;
  bool _isPurchased = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadAstrologerContact();
    _fetchUserName();
  }

  Future<void> _loadAstrologerContact() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      astrologerId = prefs.getString('astrologer_phone');
    });
  }

  Future<void> _fetchUserName() async {
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(widget.userId).get();
    setState(() {
      userName = userDoc['name']; // Fetch and store the user's name
      usercontact = userDoc.id;
      gender = userDoc['gender'];
    });
  }

  // Function to give a free question to the user
  Future<void> _giveFreeQuestion() async {
    print("KSMFM");
    print(usercontact);

    if (usercontact != null) {
      String purchaseId = Uuid().v4(); // Generate unique purchase ID

      try {
        // Store purchase information in 'purchase' collection (with cost 0 for free question)
        await _firestore.collection('purchase').doc(purchaseId).set({
          'purchase_id': purchaseId,
          'user_id': usercontact,
          'cost': 0,   // Free question, cost is 0
          'margin': 0,
          'tax': 0,
          'price': 0,
          'timestamp': Timestamp.now(),
        });

        // Link purchase to user's purchase history
        await _firestore
            .collection('users')
            .doc(usercontact)
            .collection('purchases')
            .doc(purchaseId)
            .set({
          'purchase_id': purchaseId,
          'timestamp': Timestamp.now(),
        });

        // Fetch current available questions
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(usercontact).get();
        int availableQuestions = userDoc.exists && (userDoc.data() as Map<String, dynamic>).containsKey('available_questions')
            ? (userDoc.data() as Map<String, dynamic>)['available_questions']
            : 0;

        // Increment available questions by 1
        await _firestore.collection('users').doc(usercontact).update({
          'available_questions': availableQuestions + 1,
        });

        setState(() {
          _isPurchased = true;
        });

        // Show confirmation of success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Free question granted to the user.")),
        );

        // Return to the previous screen after a delay
        Timer(Duration(seconds: 3), () {
          Navigator.pop(context, true);
        });
      } catch (e) {
        print("Error giving free question: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error granting free question.")),
        );
      }
    }
  }

  Future<void> _confirmEndConversation() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirm End Conversation"),
          content: Text("Are you sure you want to end this conversation?"),
          actions: <Widget>[
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop(false); // Dismiss dialog with 'Cancel'
              },
            ),
            TextButton(
              child: Text("Confirm"),
              onPressed: () {
                Navigator.of(context).pop(true); // Dismiss dialog with 'Confirm'
              },
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      _endConversation(); // Call the end conversation function only if confirmed
    }
  }


  Future<void> _endConversation() async {
    try {
      // Fetch the astrologer's answer document to retrieve the purchase_id
      DocumentSnapshot answerDoc = await _firestore
          .collection('astrologers')
          .doc(astrologerId)
          .collection('answers')
          .doc(widget.questionId)
          .get();

      if (answerDoc.exists && answerDoc.data() != null) {
        // Extract purchase_id from the answer document
        String? purchaseId = (answerDoc.data() as Map<String, dynamic>)['purchase_id'];

        if (purchaseId != null) {
          // Fetch the cost from the 'purchase' collection using the purchase_id
          DocumentSnapshot purchaseDoc = await _firestore.collection('purchase').doc(purchaseId).get();
          if (purchaseDoc.exists && purchaseDoc.data() != null) {
            // Extract the cost value from the purchase document
            int cost = (purchaseDoc.data() as Map<String, dynamic>)['cost'] ?? 100; // Default to 100 if not found

            // Remove the question from astrologer's answers
            await _firestore
                .collection('astrologers')
                .doc(astrologerId)
                .collection('answers')
                .doc(widget.questionId)
                .delete();

            // Move it to the solved collection with additional fields, including iswithdrawn
            await _firestore.collection('astrologers').doc(astrologerId).collection('solved').doc(widget.questionId).set({
              'question_id': widget.questionId,
              'user_id': widget.userId,
              'cost': cost, // Use the actual cost from the purchase document
              'timestamp': Timestamp.now(),
              'status': 'completed',
              'iswithdrawn': false, // Mark the earnings as not yet withdrawn
            });

            // Update the withdrawable_amount field in the astrologer's document
            DocumentSnapshot astrologerDoc = await _firestore.collection('astrologers').doc(astrologerId).get();

            // Get the current withdrawable_amount, if not found, default to 0
            int currentWithdrawableAmount = astrologerDoc.exists && (astrologerDoc.data() as Map<String, dynamic>).containsKey('withdrawable_amount')
                ? (astrologerDoc.data() as Map<String, dynamic>)['withdrawable_amount']
                : 0;

            // Update the astrologer's withdrawable_amount by adding the cost of this conversation
            await _firestore.collection('astrologers').doc(astrologerId).update({
              'withdrawable_amount': currentWithdrawableAmount + cost, // Add the cost to withdrawable amount
            });

            // Show confirmation message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Conversation ended and amount added to withdrawable balance.")),
            );

            // Pop back to the previous screen after a delay
            Timer(Duration(seconds: 2), () {
              Navigator.pop(context); // Pop back to the previous screen
            });
          } else {
            // If purchase document is not found or no cost field exists
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error: Purchase document not found or missing cost.")),
            );
          }
        } else {
          // If purchase_id is not found in the answer document
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: No purchase ID found for the question.")),
          );
        }
      } else {
        // If answer document is not found or empty
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: Answer document not found.")),
        );
      }
    } catch (e) {
      print("Error ending conversation: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error ending conversation.")),
      );
    }
  }


  Future<void> _sendMessage(String replyMessage) async {
    if (replyMessage.trim().isNotEmpty) {
      String newMessageId = _firestore.collection('users').doc(widget.userId).collection('messages').doc().id;

      // Add message to user's collection
      await _firestore.collection('users').doc(widget.userId)
          .collection('message').doc(newMessageId).set({
        'message_text': replyMessage,
        'from': astrologerId,
        'timestamp': Timestamp.now(),
        'reply_to': widget.questionId,  // Refers to the user's original question
        'usertype': 'astrologer',       // Differentiating astrologer messages
      });

      // Clear message controller after sending
      _messageController.clear();
    }
  }

  Future<void> _pickMedia() async {
    final XFile? media = await _picker.pickVideo(source: ImageSource.gallery);
    if (media != null) {
      print("Media selected: ${media.path}");
    }
  }

  void _showMediaOptions() {
    showModalBottomSheet(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 200,
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Send Media",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber[800],
                ),
              ),
              SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMediaOption(Icons.image, "Image"),
                  _buildMediaOption(Icons.mic, "Audio"),
                  _buildMediaOption(Icons.videocam, "Video"),
                  _buildMediaOption(Icons.call, "Call"),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaOption(IconData icon, String label) {
    return GestureDetector(
      onTap: () async {
        if (label == "Video") {
          await _pickMedia();
        }
        Navigator.pop(context);
      },
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.amber[800],
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          SizedBox(height: 5),
          Text(label, style: TextStyle(color: Colors.black)),
        ],
      ),
    );
  }

  bool _isDifferentDay(Timestamp previousTimestamp, Timestamp currentTimestamp) {
    final DateTime previousDate = previousTimestamp.toDate();
    final DateTime currentDate = currentTimestamp.toDate();

    return DateFormat('yyyyMMdd').format(previousDate) != DateFormat('yyyyMMdd').format(currentDate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber[800]!, Colors.amber[400]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: 60), // Top spacing
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  Text(
                    userName != null && userName != "" ? userName! : "Chat",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.card_giftcard, color: Colors.white), // Free question icon
                        onPressed: _giveFreeQuestion,
                      ),
                      IconButton(
                        icon: Icon(Icons.exit_to_app, color: Colors.white), // End conversation icon
                        onPressed: _confirmEndConversation,
                      ),
                    ],
                  ),
                ],
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
                child: Column(
                  children: [
                    // Chat Messages ListView
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _firestore.collection('users')
                            .doc(widget.userId)
                            .collection('message')
                            .orderBy('timestamp', descending: false)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Center(child: CircularProgressIndicator());
                          }

                          var messages = snapshot.data!.docs;
                          Timestamp? lastTimestamp;

                          return ListView.builder(
                            reverse: true, // Keep the messages aligned to the bottom
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              var currentMessage = messages[messages.length - index - 1].data() as Map<String, dynamic>;
                              var nextMessage = (index < messages.length - 1)
                                  ? messages[messages.length - index - 2].data() as Map<String, dynamic>
                                  : null;

                              Timestamp currentTimestamp = currentMessage['timestamp'];
                              bool isAstrologer = currentMessage['usertype'] == 'astrologer';
                              String sender = isAstrologer ? 'Astrologer' : userName ?? 'User';
                              String displayTime = DateFormat('h:mm a').format(currentTimestamp.toDate());

                              bool showNameAndIcon = (nextMessage == null) || (nextMessage['usertype'] != currentMessage['usertype']);

                              lastTimestamp = currentTimestamp;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (index == messages.length - 1 || (lastTimestamp != null && _isDifferentDay(lastTimestamp!, currentTimestamp)))
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                                      child: Text(
                                        DateFormat('EEEE, MMMM d, yyyy').format(currentTimestamp.toDate()),
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  Align(
                                    alignment: isAstrologer ? Alignment.centerRight : Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: isAstrologer ? 1.0 : 0.9,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (!isAstrologer && showNameAndIcon)
                                              CircleAvatar(
                                                radius: 15,
                                                backgroundImage: AssetImage(gender != "Male"
                                                    ? 'assets/woman.png'
                                                    : 'assets/man.png'),
                                              ),
                                            if (!isAstrologer && showNameAndIcon)
                                              SizedBox(width: 8),
                                            if (!isAstrologer && !showNameAndIcon)
                                              SizedBox(width: 30),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: isAstrologer
                                                    ? CrossAxisAlignment.end
                                                    : CrossAxisAlignment.start,
                                                children: [
                                                  if (showNameAndIcon)
                                                    Text(
                                                      sender,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  Container(
                                                    margin: EdgeInsets.only(top: 5),
                                                    padding: EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      color: isAstrologer ? Colors.amber[800] : Colors.grey[300],
                                                      borderRadius: BorderRadius.only(
                                                        topLeft: isAstrologer ? Radius.circular(15) : Radius.circular(0),
                                                        topRight: isAstrologer ? Radius.circular(0) : Radius.circular(15),
                                                        bottomLeft: Radius.circular(15),
                                                        bottomRight: Radius.circular(15),
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black26,
                                                          blurRadius: 5,
                                                          offset: Offset(0, 3),
                                                        )
                                                      ],
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment: isAstrologer
                                                          ? CrossAxisAlignment.end
                                                          : CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          currentMessage['message_text'] ?? '',
                                                          style: TextStyle(
                                                            color: isAstrologer ? Colors.white : Colors.black87,
                                                          ),
                                                        ),
                                                        SizedBox(height: 5),
                                                        Text(
                                                          displayTime,
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (isAstrologer && showNameAndIcon)
                                              SizedBox(width: 8),
                                            if (isAstrologer && !showNameAndIcon)
                                              SizedBox(width: 30),
                                            if (isAstrologer && showNameAndIcon)
                                              CircleAvatar(
                                                backgroundImage: AssetImage('assets/astro.png'),
                                                radius: 15,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                    Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.add, color: Colors.amber[800], size: 28),
                            onPressed: _showMediaOptions,
                          ),
                          Expanded(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxHeight: 120),
                              child: Scrollbar(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  reverse: true,
                                  child: TextField(
                                    controller: _messageController,
                                    maxLines: null,
                                    decoration: InputDecoration(
                                      hintText: "Type your reply...",
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.send, color: Colors.amber[800]),
                            onPressed: () {
                              _sendMessage(_messageController.text);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
