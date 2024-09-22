import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // For date and time formatting
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart'; // For audio file picking
import 'package:uuid/uuid.dart'; // For generating unique IDs
import 'package:starsyncapp/Screens/BuyQuestions.dart';

class ChatPage extends StatefulWidget {
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TextEditingController _messageController = TextEditingController();
  String? userId, name, gender, contactNumber;
  int availableQuestions = 0;
  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> selectedMediaFiles = [];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString('contact_number');
      name = prefs.getString('name');
      gender = prefs.getString('gender');
    });

    if (userId != null) {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      setState(() {
        contactNumber = userDoc.id;
        availableQuestions = userDoc.exists && (userDoc.data() as Map<String, dynamic>).containsKey('available_questions')
            ? (userDoc.data() as Map<String, dynamic>)['available_questions']
            : 0;
      });

      // Redirect to BuyQuestionPage if availableQuestions is zero
      if (availableQuestions == 0) {
        _navigateToBuyQuestionsPage();
      }
    }
  }

  Future<void> _sendQuestion(String messageText) async {
    if ((messageText.trim().isNotEmpty || selectedMediaFiles.isNotEmpty) && availableQuestions > 0) {
      String questionId = Uuid().v4(); // Generate unique ID for the message

      // Fetch the first unused purchase
      QuerySnapshot purchaseDocs = await _firestore.collection('users').doc(userId).collection('purchases').get();
      String? purchaseId;
      for (var doc in purchaseDocs.docs) {
        var data = doc.data() as Map<String, dynamic>;
        print(data['status']);
        if (data['status'] == null || data['status'] == 'unused' || data['free_question'] == true) {
          purchaseId = doc.id;
          break;
        }
      }

      if (purchaseId == null) {
        print("No available purchases.");
        return;
      }

      List<Map<String, String>> uploadedFiles = [];

      // Upload each selected file
      for (var fileData in selectedMediaFiles) {
        String? mediaUrl = await _uploadMedia(fileData['file'], fileData['mediaType']);
        if (mediaUrl != null) {
          uploadedFiles.add({'media_url': mediaUrl, 'media_type': fileData['mediaType']});
        }
      }

      // Save the message with media files to Firestore
      await _firestore.collection('users').doc(userId).collection('message').doc(questionId).set({
        'question_id': questionId,
        'message_text': messageText.isNotEmpty ? messageText : null,
        'media_files': uploadedFiles.isNotEmpty ? uploadedFiles : null, // Store all media files
        'from': userId,
        'timestamp': Timestamp.now(),
        'status': 'pending',
        'assigned_to_astrologer': false,
      });

      // Add reference to the 'unassign' collection with status 'unassigned'
      await _firestore.collection('unassign').doc(questionId).set({
        'user_id': userId,              // Store user's ID
        'question_id': questionId,       // Store the message/question ID
        'status': 'unassigned',          // Set status to unassigned
        'timestamp': Timestamp.now(),    // Add current timestamp
      });

      // Update the purchase status to "used"
      await _firestore.collection('users').doc(userId).collection('purchases').doc(purchaseId).update({
        'status': 'used',
      });

      // Update the available questions count
      setState(() {
        availableQuestions--;
      });

      // Update the available questions in the user's document
      await _firestore.collection('users').doc(userId).update({
        'available_questions': availableQuestions,
      });

      // Clear the input field and selected media files
      _messageController.clear();
      selectedMediaFiles.clear();
      setState(() {});
    } else {
      print("No available questions or invalid input.");
      _navigateToBuyQuestionsPage();
    }
  }

  Future<void> _navigateToBuyQuestionsPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BuyQuestionPage()),
    );

    if (result != null && result is bool && result == true) {
      await _loadUserProfile(); // Re-fetch user profile to update availableQuestions
      setState(() {}); // Call setState to reflect the updated questions count
    }
  }

  Future<String?> _uploadMedia(File file, String mediaType) async {
    try {
      String fileId = Uuid().v4();
      Reference storageRef = _storage.ref().child('chat_media/$userId/$mediaType/$fileId');

      // Upload file
      TaskSnapshot uploadTask = await storageRef.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      print("Error uploading $mediaType: $e");
      return null;
    }
  }

  Future<void> _pickMedia(String mediaType) async {
    final XFile? media;
    if (mediaType == 'image') {
      media = await _picker.pickImage(source: ImageSource.gallery);
    } else if (mediaType == 'video') {
      media = await _picker.pickVideo(source: ImageSource.gallery);
    } else {
      // Use file picker for audio
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        setState(() {
          selectedMediaFiles.add({'file': file, 'mediaType': 'audio'});
        });
        return;
      }
      return;
    }

    if (media != null) {
      File file = File(media.path);
      setState(() {
        selectedMediaFiles.add({'file': file, 'mediaType': mediaType});
      });
    }
  }

  void _removeSelectedFile(int index) {
    setState(() {
      selectedMediaFiles.removeAt(index);
    });
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
                  _buildMediaOption(Icons.image, "Image", 'image'),
                  _buildMediaOption(Icons.mic, "Audio", 'audio'),
                  _buildMediaOption(Icons.videocam, "Video", 'video'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaOption(IconData icon, String label, String mediaType) {
    return GestureDetector(
      onTap: () async {
        await _pickMedia(mediaType);
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

  bool _isDifferentDay(Timestamp? currentTimestamp, Timestamp nextTimestamp) {
    if (currentTimestamp == null) return true;

    final DateTime currentDate = currentTimestamp.toDate();
    final DateTime nextDate = nextTimestamp.toDate();

    return DateFormat('yyyyMMdd').format(currentDate) != DateFormat('yyyyMMdd').format(nextDate);
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Column(
            children: [
              // Header Section
              Container(
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, bottom: 10, left: 10, right: 10),
                decoration: BoxDecoration(
                  color: Colors.amber[800],
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Image.asset('assets/logo.png', height: 60, width: 60),
                        SizedBox(width: 10),
                        Text(
                          "StarSync",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.amber[800],
                        backgroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.amber.shade800, width: 2),
                        ),
                        elevation: 5,
                      ),
                      onPressed: _navigateToBuyQuestionsPage,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "$availableQuestions",
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(width: 10),
                          Text(
                            "Buy Question",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Display selected media files (before sending)
              if (selectedMediaFiles.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8.0),
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: selectedMediaFiles.length,
                    itemBuilder: (context, index) {
                      var media = selectedMediaFiles[index];
                      return Stack(
                        children: [
                          if (media['mediaType'] == 'image')
                            Image.file(media['file'], width: 100, height: 100, fit: BoxFit.cover),
                          if (media['mediaType'] == 'audio')
                            Icon(Icons.audiotrack, size: 50),
                          if (media['mediaType'] == 'video')
                            Icon(Icons.play_circle_filled, size: 50),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: GestureDetector(
                              onTap: () => _removeSelectedFile(index),
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.red,
                                child: Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('users').doc(userId).collection('message').orderBy('timestamp').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }

                    var messages = snapshot.data!.docs;
                    Timestamp? currentTimestamp;

                    return ListView.builder(
                      reverse: true, // Keep messages aligned from bottom to top
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        var currentMessage = messages[messages.length - index - 1].data() as Map<String, dynamic>;
                        var nextMessage = (index < messages.length - 1)
                            ? messages[messages.length - index - 2].data() as Map<String, dynamic>
                            : null;

                        currentTimestamp = currentMessage['timestamp'];
                        bool isUser = currentMessage['usertype'] == null ? true : currentMessage['usertype'] == 'user'; // Determine if the message is from the user
                        String sender = isUser ? 'User' : 'Astrologer';
                        String displayTime = DateFormat('h:mm a').format(currentTimestamp!.toDate());

                        bool showNameAndIcon = (nextMessage == null) || (nextMessage['usertype'] != currentMessage['usertype']);
                        bool showDate = nextMessage == null || _isDifferentDay(currentTimestamp, nextMessage['timestamp']);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Show date if the next message is from a different date
                            if (showDate)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  DateFormat('EEEE, MMMM d, yyyy').format(currentTimestamp!.toDate()),
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            Align(
                              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: isUser ? 0.9 : 0.8, // Adjust width for user and astrologer messages
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (!isUser && showNameAndIcon)
                                        CircleAvatar(
                                          radius: 15,
                                          backgroundImage: AssetImage('assets/astro.png'),
                                        ),
                                      if (!isUser && showNameAndIcon)
                                        SizedBox(width: 8),
                                      if (!isUser && !showNameAndIcon)
                                        SizedBox(width: 30),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                          children: [
                                            if (showNameAndIcon)
                                              Text(
                                                name.toString(),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            Container(
                                              margin: EdgeInsets.only(top: 5),
                                              padding: EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: isUser ? Colors.amber[800] : Colors.grey[300],
                                                borderRadius: BorderRadius.only(
                                                  topLeft: isUser ? Radius.circular(15) : Radius.circular(0),
                                                  topRight: isUser ? Radius.circular(0) : Radius.circular(15),
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
                                                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                                children: [
                                                  if (currentMessage['message_text'] != null)
                                                    Text(
                                                      currentMessage['message_text'] ?? '',
                                                      style: TextStyle(
                                                        color: isUser ? Colors.white : Colors.black87,
                                                      ),
                                                    ),
                                                  if (currentMessage['media_files'] != null)
                                                    Column(
                                                      children: (currentMessage['media_files'] as List<dynamic>).map((media) {
                                                        if (media['media_type'] == 'image') {
                                                          return Image.network(media['media_url']);
                                                        } else if (media['media_type'] == 'video') {
                                                          return Icon(Icons.play_circle_outline);
                                                        } else if (media['media_type'] == 'audio') {
                                                          return Icon(Icons.audiotrack);
                                                        }
                                                        return SizedBox.shrink();
                                                      }).toList(),
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
                                      if (isUser && showNameAndIcon)
                                        SizedBox(width: 8),
                                      if (isUser && !showNameAndIcon)
                                        SizedBox(width: 30),
                                      if (isUser && showNameAndIcon)
                                        CircleAvatar(
                                          backgroundImage: AssetImage(gender != "Male"
                                              ? 'assets/woman.png'
                                              : 'assets/man.png'),
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
                                hintText: "Enter your message...",
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
                        _sendQuestion(_messageController.text);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
