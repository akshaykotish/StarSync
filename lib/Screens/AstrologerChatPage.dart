import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // For date and time formatting
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart'; // For generating unique IDs
import 'dart:async';
import 'dart:io';

import 'FullScreenImagePage.dart'; // For displaying images in full screen
import 'AudioPlayerWidget.dart'; // Custom widget for audio playback
import 'SineWave.dart';
import 'VideoPlayerWidget.dart'; // Custom widget for video playback

import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart'; // For audio file picking
import 'package:flutter_sound/flutter_sound.dart' as fs;
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

class AstrologerChatPage extends StatefulWidget {
  final String userId;
  final String questionId;

  AstrologerChatPage({required this.userId, required this.questionId});

  @override
  _AstrologerChatPageState createState() => _AstrologerChatPageState();
}

class _AstrologerChatPageState extends State<AstrologerChatPage> {
  // Firestore and Firebase Storage instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Controllers and variables for messaging
  final TextEditingController _messageController = TextEditingController();
  String? astrologerId;
  String? userName;
  String? gender;
  String? userContact;
  bool _isPurchased = false;

  // Image picker for media selection
  final ImagePicker _picker = ImagePicker();

  // Variables for audio recording and playback
  final fs.FlutterSoundRecorder _recorder = fs.FlutterSoundRecorder();
  bool _isRecording = false;
  String? _audioFilePath;
  String? _audioDownloadUrl;
  bool _isAudioRecorded = false;
  bool _isPlayingAudio = false;
  final ap.AudioPlayer _audioPlayer = ap.AudioPlayer();
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  // List to hold selected media files before sending
  List<Map<String, dynamic>> selectedMediaFiles = [];

  @override
  void initState() {
    super.initState();
    _loadAstrologerContact();
    _fetchUserName();
    _initRecorder();
    _initializeAudioPlayerListeners();
    _checkInitialPurchaseStatus();
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _audioPlayer.dispose(); // Dispose the audio player
    super.dispose();
  }

  // Initialize the audio recorder
  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
    await _recorder.setSubscriptionDuration(const Duration(milliseconds: 500));
  }

  // Initialize listeners for the audio player
  void _initializeAudioPlayerListeners() {
    // Listen for when the audio player completes playing
    _audioPlayer.onPlayerComplete.listen((event) {
      _resetAudioAndWaveform();
    });

    // Listen for player state changes
    _audioPlayer.onPlayerStateChanged.listen((ap.PlayerState state) {
      if (state == ap.PlayerState.paused || state == ap.PlayerState.stopped) {
        setState(() {
          _isPlayingAudio = false;
        });
      }
    });

    // Listen for audio position changes
    _audioPlayer.onPositionChanged.listen((Duration position) {
      setState(() {
        _currentPosition = position;
      });
    });

    // Listen for audio duration changes
    _audioPlayer.onDurationChanged.listen((Duration duration) {
      setState(() {
        _totalDuration = duration;
      });
    });
  }

  // Load astrologer contact from SharedPreferences
  Future<void> _loadAstrologerContact() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      astrologerId = prefs.getString('astrologer_phone');
    });
  }

  // Fetch user's name, gender, and contact from Firestore
  Future<void> _fetchUserName() async {
    DocumentSnapshot userDoc =
    await _firestore.collection('users').doc(widget.userId).get();
    setState(() {
      userName = userDoc['name']; // Fetch and store the user's name
      userContact = userDoc.id;
      gender = userDoc['gender'];
    });
  }

  // Check if user has available questions on initial load
  Future<void> _checkInitialPurchaseStatus() async {
    if (userContact == null) return;

    DocumentSnapshot userDoc =
    await _firestore.collection('users').doc(userContact).get();
    int availableQuestions = userDoc.exists &&
        (userDoc.data() as Map<String, dynamic>).containsKey('available_questions')
        ? (userDoc.data() as Map<String, dynamic>)['available_questions']
        : 0;

    if (availableQuestions > 0) {
      setState(() {
        _isPurchased = true;
      });
    } else {
      // Optionally, prompt to purchase or grant a free question
      // For example, navigate to BuyQuestionPage
      _navigateToBuyQuestionsPage();
    }
  }

  // Function to give a free question to the user
  Future<void> _giveFreeQuestion() async {
    print("Giving a free question to user: $userContact");

    if (userContact != null) {
      String purchaseId = Uuid().v4(); // Generate unique purchase ID

      try {
        // Store purchase information in 'purchase' collection (with cost 0 for free question)
        await _firestore.collection('purchase').doc(purchaseId).set({
          'purchase_id': purchaseId,
          'user_id': userContact,
          'cost': 0, // Free question, cost is 0
          'margin': 0,
          'tax': 0,
          'price': 0,
          'timestamp': Timestamp.now(),
        });

        // Link purchase to user's purchase history
        await _firestore
            .collection('users')
            .doc(userContact)
            .collection('purchases')
            .doc(purchaseId)
            .set({
          'purchase_id': purchaseId,
          'timestamp': Timestamp.now(),
        });

        // Fetch current available questions
        DocumentSnapshot userDoc =
        await _firestore.collection('users').doc(userContact).get();
        int availableQuestions = userDoc.exists &&
            (userDoc.data() as Map<String, dynamic>)
                .containsKey('available_questions')
            ? (userDoc.data() as Map<String, dynamic>)['available_questions']
            : 0;

        // Increment available questions by 1
        await _firestore.collection('users').doc(userContact).update({
          'available_questions': availableQuestions + 1,
        });

        setState(() {
          _isPurchased = true;
        });

        // Show confirmation of success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Free question granted to the user.")),
        );

        // Optionally, navigate back after a delay
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

  // Confirm before ending the conversation
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

  // End the conversation and handle Firestore updates
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
        String? purchaseId =
        (answerDoc.data() as Map<String, dynamic>)['purchase_id'];

        if (purchaseId != null) {
          // Fetch the cost from the 'purchase' collection using the purchase_id
          DocumentSnapshot purchaseDoc =
          await _firestore.collection('purchase').doc(purchaseId).get();
          if (purchaseDoc.exists && purchaseDoc.data() != null) {
            // Extract the cost value from the purchase document
            int cost = (purchaseDoc.data() as Map<String, dynamic>)['cost'] ??
                100; // Default to 100 if not found

            // Remove the question from astrologer's answers
            await _firestore
                .collection('astrologers')
                .doc(astrologerId)
                .collection('answers')
                .doc(widget.questionId)
                .delete();

            // Move it to the solved collection with additional fields, including iswithdrawn
            await _firestore
                .collection('astrologers')
                .doc(astrologerId)
                .collection('solved')
                .doc(widget.questionId)
                .set({
              'question_id': widget.questionId,
              'user_id': widget.userId,
              'cost': cost, // Use the actual cost from the purchase document
              'timestamp': Timestamp.now(),
              'status': 'completed',
              'iswithdrawn': false, // Mark the earnings as not yet withdrawn
            });

            // Update the withdrawable_amount field in the astrologer's document
            DocumentSnapshot astrologerDoc = await _firestore
                .collection('astrologers')
                .doc(astrologerId)
                .get();

            // Get the current withdrawable_amount, if not found, default to 0
            int currentWithdrawableAmount = astrologerDoc.exists &&
                (astrologerDoc.data() as Map<String, dynamic>)
                    .containsKey('withdrawable_amount')
                ? (astrologerDoc.data()
            as Map<String, dynamic>)['withdrawable_amount']
                : 0;

            // Update the astrologer's withdrawable_amount by adding the cost of this conversation
            await _firestore.collection('astrologers').doc(astrologerId).update({
              'withdrawable_amount': currentWithdrawableAmount + cost,
            });

            // Show confirmation message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      "Conversation ended and amount added to withdrawable balance.")),
            );

            // Pop back to the previous screen after a delay
            Timer(Duration(seconds: 2), () {
              Navigator.pop(context); // Pop back to the previous screen
            });
          } else {
            // If purchase document is not found or no cost field exists
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                  Text("Error: Purchase document not found or missing cost.")),
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

  // Function to send a message with optional media files
  Future<void> _sendMessage() async {
    String replyMessage = _messageController.text.trim();

    if (replyMessage.isEmpty && selectedMediaFiles.isEmpty && !_isAudioRecorded) {
      // No message or media to send
      return;
    }

    if (!_isPurchased && !await _checkAndHandleAvailableQuestions()) {
      // No available questions and failed to grant a free one
      return;
    }

    String newMessageId = Uuid().v4();

    List<Map<String, String>> uploadedFiles = [];

    // Handle audio recording if any
    if (_isAudioRecorded && _audioDownloadUrl != null) {
      uploadedFiles.add({
        'media_url': _audioDownloadUrl!,
        'media_type': 'audio',
      });
    }

    // Handle other selected media files
    for (var fileData in selectedMediaFiles) {
      String? mediaUrl =
      await _uploadMedia(fileData['file'], fileData['mediaType']);
      if (mediaUrl != null) {
        uploadedFiles.add({
          'media_url': mediaUrl,
          'media_type': fileData['mediaType']
        });
      }
    }

    // Send the message to Firestore
    await _firestore
        .collection('users')
        .doc(widget.userId)
        .collection('message')
        .doc(newMessageId)
        .set({
      'message_id': newMessageId,
      'message_text': replyMessage.isNotEmpty ? replyMessage : null,
      'media_files': uploadedFiles.isNotEmpty ? uploadedFiles : null,
      'from': astrologerId,
      'timestamp': Timestamp.now(),
      'usertype': 'astrologer', // Differentiating astrologer messages
    });

    // Optionally, you can notify the user or perform other actions here

    // Clear message controller and selected media files after sending
    _messageController.clear();
    selectedMediaFiles.clear();
    setState(() {
      _isAudioRecorded = false;
      _audioFilePath = null;
      _audioDownloadUrl = null;
    });
  }

  // Check if user has available questions or grant a free one
  Future<bool> _checkAndHandleAvailableQuestions() async {
    if (userContact == null) return false;

    DocumentSnapshot userDoc =
    await _firestore.collection('users').doc(userContact).get();
    int availableQuestions = userDoc.exists &&
        (userDoc.data() as Map<String, dynamic>)
            .containsKey('available_questions')
        ? (userDoc.data() as Map<String, dynamic>)['available_questions']
        : 0;

    if (availableQuestions > 0) {
      return true;
    } else {
      // Optionally, you can grant a free question or navigate to purchase
      await _giveFreeQuestion();
      return _isPurchased;
    }
  }

  // Upload media files to Firebase Storage
  Future<String?> _uploadMedia(File file, String mediaType) async {
    try {
      String fileId = Uuid().v4();
      Reference storageRef = _storage
          .ref()
          .child('chat_media/${widget.userId}/$mediaType/$fileId');

      // Upload file
      TaskSnapshot uploadTask = await storageRef.putFile(file);
      String downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print("Error uploading $mediaType: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to upload $mediaType.")),
      );
      return null;
    }
  }

  // Function to pick media (image, audio, video)
  Future<void> _pickMedia(String mediaType) async {
    final XFile? media;
    if (mediaType == 'image') {
      media = await _picker.pickImage(source: ImageSource.gallery);
    } else if (mediaType == 'video') {
      media = await _picker.pickVideo(source: ImageSource.gallery);
    } else {
      // Use file picker for audio
      FilePickerResult? result =
      await FilePicker.platform.pickFiles(type: FileType.audio);
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

  // Remove a selected media file before sending
  void _removeSelectedFile(int index) {
    setState(() {
      selectedMediaFiles.removeAt(index);
    });
  }

  // Show media options in a bottom sheet
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

  // Build individual media option buttons
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

  // Check if two timestamps are on different days
  bool _isDifferentDay(Timestamp? currentTimestamp, Timestamp nextTimestamp) {
    if (currentTimestamp == null) return true;

    final DateTime currentDate = currentTimestamp.toDate();
    final DateTime nextDate = nextTimestamp.toDate();

    return DateFormat('yyyyMMdd').format(currentDate) !=
        DateFormat('yyyyMMdd').format(nextDate);
  }

  // UI for sending text messages
  Widget _sendTextMessageUI() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(15)),
      ),
      padding: const EdgeInsets.all(8.0),
      margin: EdgeInsets.all(10),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.amber[800], size: 28),
            onPressed: _showMediaOptions,
          ),
          // Audio recording button
          GestureDetector(
            onLongPressStart: (_) => _recordAudio(),
            onLongPressEnd: (_) => _stopRecording(),
            child: Icon(
              _isRecording ? Icons.mic_off : Icons.mic,
              color: _isRecording ? Colors.red : Colors.black,
              size: 28,
            ),
          ),
          SizedBox(width: 5),
          // Display recording waveform or input field
          if (_isRecording)
            Expanded(child: SineWaveWidget(isPlaying: true))
          else
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
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }

  // UI for reviewing recorded audio before sending
  Widget _buildAudioReviewUI() {
    return Container(
      padding: EdgeInsets.all(8),
      margin: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(_isPlayingAudio ? Icons.pause : Icons.play_arrow),
            iconSize: 36,
            color: Colors.amber[800],
            onPressed: _playPauseAudioAndWaveform,
          ),
          Container(
            child: _isPlayingAudio
                ? SineWaveWidget(isPlaying: true)
                : SineWaveWidget(isPlaying: false),
          ),
          IconButton(
            icon: Icon(Icons.delete),
            iconSize: 36,
            color: Colors.red,
            onPressed: _deleteRecordedAudio,
          ),
          IconButton(
            icon: Icon(Icons.send),
            iconSize: 36,
            color: Colors.black,
            onPressed: _sendRecordedAudio,
          ),
        ],
      ),
    );
  }

  // Function to record audio (starts on long press)
  Future<void> _recordAudio() async {
    if (_isRecording) return;

    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      print("Microphone permission not granted");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Microphone permission is required.")),
      );
      return;
    }

    // Get the absolute file path to store the audio
    String audioFilePath = await _getFilePath('audio.aac');
    _audioFilePath = audioFilePath;

    setState(() {
      _isRecording = true;
    });

    // Start recording and specify the absolute path for the output file
    await _recorder.startRecorder(
      toFile: audioFilePath, // Save the audio in the app's documents directory
      codec: fs.Codec.aacADTS, // Set the codec to AAC
    );
    print("Recording started, saving at: $audioFilePath");
  }

  // Function to stop recording audio
  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    await _recorder.stopRecorder();
    setState(() {
      _isRecording = false;
      _isAudioRecorded = true;
    });

    // Get the absolute file path of the recorded audio
    String audioFilePath = _audioFilePath ?? '';
    File recordedFile = File(audioFilePath);
    print("Recording stopped and saved at: $audioFilePath");

    // Upload the audio file
    await _uploadAudio(recordedFile);
  }

  // Get the file path for storing audio
  Future<String> _getFilePath(String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$filename';
  }

  // Upload the audio file to Firebase Storage
  Future<void> _uploadAudio(File audioFile) async {
    String absolutePath = audioFile.path;

    if (!audioFile.existsSync()) {
      print("File does not exist at path: $absolutePath");
      return;
    }

    print("Uploading audio file at path: $absolutePath");

    String fileId = Uuid().v4();
    Reference storageRef =
    _storage.ref().child('chat_media/${widget.userId}/audio/$fileId.mp3');

    try {
      TaskSnapshot uploadTask = await storageRef.putFile(audioFile);
      String downloadUrl = await uploadTask.ref.getDownloadURL();

      setState(() {
        _audioDownloadUrl = downloadUrl;
      });

      print("Audio uploaded successfully: $downloadUrl");
    } catch (e) {
      print("Error uploading audio: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to upload audio.")),
      );
    }
  }

  // Play or pause the audio along with the waveform
  Future<void> _playPauseAudioAndWaveform() async {
    if (_audioFilePath == null && _audioDownloadUrl == null) {
      print("No audio file to play.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No audio recorded to play.")),
      );
      return;
    }

    String sourcePath =
        _audioDownloadUrl ?? (_audioFilePath != null ? _audioFilePath! : '');

    if (_isPlayingAudio) {
      try {
        await _audioPlayer.pause();
        setState(() {
          _isPlayingAudio = false;
        });
      } catch (e) {
        print("Error pausing audio: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to pause audio.")),
        );
      }
    } else {
      try {
        if (_audioDownloadUrl != null) {
          await _audioPlayer.play(UrlSource(_audioDownloadUrl!));
        } else {
          await _audioPlayer.play(DeviceFileSource(_audioFilePath!));
        }
        setState(() {
          _isPlayingAudio = true;
        });
      } catch (e) {
        print("Error playing audio: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to play audio.")),
        );
      }
    }
  }

  // Reset audio playback and waveform
  void _resetAudioAndWaveform() {
    setState(() {
      _isPlayingAudio = false;
      _currentPosition = Duration.zero;
    });
  }

  // Delete the recorded audio
  void _deleteRecordedAudio() {
    if (_audioFilePath != null) {
      File recordedFile = File(_audioFilePath!);
      if (recordedFile.existsSync()) {
        recordedFile.deleteSync();
        setState(() {
          _isAudioRecorded = false;
          _audioFilePath = null;
          _audioDownloadUrl = null;
          _isPlayingAudio = false;
        });
        print("Recorded audio deleted.");
      }
    }
  }

  // Send the recorded audio as a message
  void _sendRecordedAudio() {
    _sendMessage();
  }

  // Navigate to the Buy Questions page
  Future<void> _navigateToBuyQuestionsPage() async {
    // Replace with your actual BuyQuestionPage navigation
    // Example:
    // final result = await Navigator.push(
    //   context,
    //   MaterialPageRoute(builder: (context) => BuyQuestionPage()),
    // );

    // For demonstration, we'll just simulate a purchase
    bool purchaseCompleted = true; // Replace with actual purchase logic

    if (purchaseCompleted) {
      await _fetchUserName(); // Refresh user data if needed
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Purchase successful!")),
      );
    }
  }

  // Grant a free question and update Firestore accordingly
  Future<void> _grantFreeQuestion() async {
    // Implement your logic to grant a free question
    // This is already handled in _giveFreeQuestion()
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Header Section
            SizedBox(height: MediaQuery.of(context).padding.top), // Top spacing
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button and User Name
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                      SizedBox(width: 10),
                      Text(
                        userName != null && userName!.isNotEmpty
                            ? userName!
                            : "Chat",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black),
                      ),
                    ],
                  ),
                  // Action Buttons: Gift and Exit
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.card_giftcard, color: Colors.black),
                        onPressed: _giveFreeQuestion,
                      ),
                      IconButton(
                        icon: Icon(Icons.exit_to_app, color: Colors.black),
                        onPressed: _confirmEndConversation,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),
            // Chat Messages and Input Area
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/bg.png'),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: BorderRadius.all(Radius.circular(15)),
                ),
                child: Column(
                  children: [
                    // Display selected media files before sending
                    if (selectedMediaFiles.isNotEmpty ||
                        (_isAudioRecorded && _audioDownloadUrl != null))
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: selectedMediaFiles.length +
                              (_isAudioRecorded ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index < selectedMediaFiles.length) {
                              var media = selectedMediaFiles[index];
                              return Stack(
                                children: [
                                  if (media['mediaType'] == 'image')
                                    Image.file(media['file'],
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover),
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
                                        child: Icon(Icons.close,
                                            size: 14, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            } else {
                              // Display audio recording preview
                              return _buildAudioReviewUI();
                            }
                          },
                        ),
                      ),
                    // Chat Messages ListView
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('users')
                            .doc(widget.userId)
                            .collection('message')
                            .orderBy('timestamp', descending: true)
                            .snapshots(),
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
                              var currentMessage =
                              messages[index].data() as Map<String, dynamic>;
                              var nextMessage = (index < messages.length - 1)
                                  ? messages[index + 1].data()
                              as Map<String, dynamic>
                                  : null;

                              currentTimestamp = currentMessage['timestamp'];
                              bool isAstrologer = currentMessage['usertype'] ==
                                  'astrologer'
                                  ? true
                                  : false; // Determine if the message is from astrologer
                              String displayTime = DateFormat('h:mm a')
                                  .format(currentTimestamp!.toDate());

                              bool showNameAndIcon = (nextMessage == null) ||
                                  (nextMessage['usertype'] !=
                                      currentMessage['usertype']);
                              bool showDate = nextMessage == null ||
                                  _isDifferentDay(
                                      currentTimestamp, nextMessage['timestamp']);

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Show date if the next message is from a different date
                                  if (showDate)
                                    Container(
                                      margin: EdgeInsets.only(bottom: 20),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.8),
                                        borderRadius:
                                        BorderRadius.all(Radius.circular(10)),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8.0, horizontal: 8.0),
                                      child: Text(
                                        DateFormat('EEEE, MMMM d, yyyy')
                                            .format(currentTimestamp!.toDate()),
                                        style: TextStyle(
                                            color: Colors.grey.shade800,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  Align(
                                    alignment: isAstrologer
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: 0.8,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 5.0, horizontal: 10.0),
                                        child: Row(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            if (!isAstrologer &&
                                                showNameAndIcon)
                                              CircleAvatar(
                                                radius: 15,
                                                backgroundImage: AssetImage(
                                                    gender != "Male"
                                                        ? 'assets/woman.png'
                                                        : 'assets/man.png'),
                                              ),
                                            if (!isAstrologer &&
                                                showNameAndIcon)
                                              SizedBox(width: 8),
                                            if (!isAstrologer &&
                                                !showNameAndIcon)
                                              SizedBox(width: 30),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: isAstrologer
                                                    ? CrossAxisAlignment.end
                                                    : CrossAxisAlignment.start,
                                                children: [
                                                  if (showNameAndIcon)
                                                    Container(
                                                      child: Text(
                                                        isAstrologer
                                                            ? "You"
                                                            : userName ?? "User",
                                                        style: TextStyle(
                                                          fontWeight:
                                                          FontWeight.bold,
                                                          color: isAstrologer
                                                              ? Colors.white
                                                              : Colors.amber,
                                                        ),
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: isAstrologer
                                                            ? Colors.amber
                                                            : Colors.white,
                                                        borderRadius:
                                                        BorderRadius.only(
                                                          topLeft:
                                                          Radius.circular(15),
                                                          topRight:
                                                          Radius.circular(15),
                                                          bottomLeft:
                                                          Radius.circular(15),
                                                          bottomRight:
                                                          Radius.circular(15),
                                                        ),
                                                      ),
                                                      padding: EdgeInsets.only(
                                                          top: 8,
                                                          bottom: 8,
                                                          left: 10,
                                                          right: 10),
                                                    ),
                                                  Container(
                                                    margin: EdgeInsets.only(
                                                        top: 0, bottom: 0),
                                                    padding: EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      color: isAstrologer
                                                          ? Colors.amberAccent
                                                          .shade100
                                                          : Colors.white,
                                                      borderRadius:
                                                      BorderRadius.only(
                                                        topLeft: isAstrologer
                                                            ? Radius.circular(15)
                                                            : Radius.circular(15),
                                                        topRight: isAstrologer
                                                            ? Radius.circular(15)
                                                            : Radius.circular(15),
                                                        bottomLeft:
                                                        Radius.circular(15),
                                                        bottomRight:
                                                        Radius.circular(15),
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
                                                      crossAxisAlignment:
                                                      isAstrologer
                                                          ? CrossAxisAlignment
                                                          .end
                                                          : CrossAxisAlignment
                                                          .start,
                                                      children: [
                                                        if (currentMessage[
                                                        'message_text'] !=
                                                            null)
                                                          Text(
                                                            currentMessage[
                                                            'message_text'] ??
                                                                '',
                                                            style: TextStyle(
                                                              color:
                                                              Colors.black,
                                                            ),
                                                          ),
                                                        if (currentMessage[
                                                        'media_files'] !=
                                                            null)
                                                          Column(
                                                            children: (currentMessage[
                                                            'media_files']
                                                            as List<
                                                                dynamic>)
                                                                .map((media) {
                                                              if (media[
                                                              'media_type'] ==
                                                                  'image') {
                                                                return GestureDetector(
                                                                  onTap: () {
                                                                    Navigator.push(
                                                                      context,
                                                                      MaterialPageRoute(
                                                                        builder:
                                                                            (_) =>
                                                                            FullScreenImagePage(
                                                                              imageUrl:
                                                                              media['media_url'],
                                                                            ),
                                                                      ),
                                                                    );
                                                                  },
                                                                  child: Image.network(
                                                                    media[
                                                                    'media_url'],
                                                                    height: 150,
                                                                    fit: BoxFit.cover,
                                                                  ),
                                                                );
                                                              } else if (media[
                                                              'media_type'] ==
                                                                  'video') {
                                                                return VideoPlayerWidget(
                                                                    videoUrl: media[
                                                                    'media_url']);
                                                              } else if (media[
                                                              'media_type'] ==
                                                                  'audio') {
                                                                return AudioPlayerWidget(
                                                                    audioUrl: media[
                                                                    'media_url']);
                                                              }
                                                              return SizedBox
                                                                  .shrink();
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
                                            if (isAstrologer &&
                                                showNameAndIcon)
                                              SizedBox(width: 8),
                                            if (isAstrologer &&
                                                !showNameAndIcon)
                                              SizedBox(width: 44),
                                            if (isAstrologer &&
                                                showNameAndIcon)
                                            CircleAvatar(
                                              radius: 15,
                                              backgroundImage: AssetImage(
                                                  'assets/astro.png'),
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
                    // Message Input Area
                    if (!_isAudioRecorded)
                      _sendTextMessageUI()
                    else
                      _buildAudioReviewUI(),
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
