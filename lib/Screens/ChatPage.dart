import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'Astrologerbranding.dart';
import 'AudioPlayerWidget.dart';
import 'AudioWaveFormWidget.dart';
import 'BuyQuestions.dart';
import 'FullScreenImagePage.dart';
import 'IncomingCallScreen.dart';
import 'NeedHelp.dart';
import 'Profile.dart';
import 'SineWave.dart';
import 'VideoPlayerWidget.dart';

class ChatPage extends StatefulWidget {
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TextEditingController _messageController = TextEditingController();
  String? userId, name, gender, contactNumber;
  int availableQuestions = 0;
  final ImagePicker _picker = ImagePicker();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecording = false;
  String? _audioFilePath;
  String? _audioDownloadUrl;
  bool _isAudioRecorded = false;
  bool _isPlayingAudio = false;
  final ap.AudioPlayer _audioPlayer = ap.AudioPlayer();
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  List<Map<String, dynamic>> selectedMediaFiles = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _callSubscription;
  static bool islisteningforincomingcalls = false;

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _loadUserProfile().then((e) {
      _listenForIncomingCalls();
    });
    _analytics.logScreenView(screenName: 'ChatPage');
    _audioPlayer.onPlayerComplete.listen((event) {
      _resetAudioAndWaveform();
    });
    _audioPlayer.onPlayerStateChanged.listen((ap.PlayerState state) {
      if (state == ap.PlayerState.paused || state == ap.PlayerState.stopped) {
        setState(() {
          _isPlayingAudio = false;
        });
      }
    });
    _audioPlayer.onPositionChanged.listen((Duration position) {
      setState(() {
        _currentPosition = position;
      });
    });
    _audioPlayer.onDurationChanged.listen((Duration duration) {
      setState(() {
        _totalDuration = duration;
      });
    });
  }

  Set<String> _processedCallIds = {};

  void _listenForIncomingCalls() {
    if (islisteningforincomingcalls) {
      print("Already listening for incoming calls.");
      return;
    }
    islisteningforincomingcalls = true;

    print("Listening for incoming calls...");

    if (userId == null) {
      print("User ID is null. Cannot listen for calls.");
      return;
    }

    _callSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('calls')
        .snapshots()
        .listen((QuerySnapshot<Map<String, dynamic>> snapshot) {

      for (var doc in snapshot.docs) {
        Map<String, dynamic>? data = doc.data();
        // Check if call is in "calling" state
        if (data != null && data['status'] == 'calling') {
          String callId = data['callId'];
          // Make sure we haven't processed this callId before
          if (!_processedCallIds.contains(callId) && data['astrologerId'] != null) {
            _processedCallIds.add(callId);

            // Navigate to IncomingCallScreen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => IncomingCallScreen(
                  callId: callId,
                  callerId: data['astrologerId'].toString(), // or callerId
                  receiverId: userId!,                       // "this" user
                  callerName: data['callerName'] ?? "Astrologer",
                ),
              ),
            ).then((_) {
              // Once the call screen is popped, remove from set
              _processedCallIds.remove(callId);
            });

            return; // We only want to handle one new "calling" doc at a time
          }
        }
      }
    }, onError: (error) {
      print("Error listening for incoming calls: $error");
    });

  }

  Future<void> _initRecorder() async {
    await _recorder.openRecorder();
    await _recorder.setSubscriptionDuration(const Duration(milliseconds: 500));
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
      });

      QuerySnapshot purchasesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('purchases')
          .get();

      int count = 0;
      for (var doc in purchasesSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        if (!data.containsKey('status') || data['status'] != 'used') {
          count++;
        }
      }

      setState(() {
        availableQuestions = count;
      });

      await _firestore.collection('users').doc(userId).update({
        'available_questions': count,
      });

      if (availableQuestions == 0) {
        _navigateToBuyQuestionsPage();
      }
    }
  }

  Future<void> _recordAudio() async {
    if (_isRecording) return;

    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      print("Microphone permission not granted");
      return;
    }

    String audioFilePath = await getFilePath('audio.aac');
    _audioFilePath = audioFilePath;

    setState(() {
      _isRecording = true;
    });

    await _recorder.startRecorder(
      toFile: audioFilePath,
      codec: Codec.aacADTS, // Use Codec.aacADTS instead of fs.Codec.aacADTS
    );
    print("Recording started, saving at: $audioFilePath");

    _analytics.logEvent(name: 'audio_recording_started');
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    await _recorder.stopRecorder();
    setState(() {
      _isRecording = false;
    });

    String audioFilePath = await getFilePath('audio.aac');
    File recordedFile = File(audioFilePath);
    print("Recording stopped and saved at: $audioFilePath");

    setState(() {
      _isRecording = false;
      _isAudioRecorded = true;
      _audioFilePath = audioFilePath;
    });

    _uploadAudio(recordedFile);
  }

  Future<String> getFilePath(String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$filename';
  }

  Future<void> _uploadAudio(File audioFile) async {
    String absolutePath = audioFile.path;

    if (!audioFile.existsSync()) {
      print("File does not exist at path: $absolutePath");
      return;
    }

    print("Uploading file at path: $absolutePath");

    String fileId = Uuid().v4();
    Reference storageRef = _storage.ref().child('chat_media/$userId/audio/$fileId.mp3');

    try {
      TaskSnapshot uploadTask = await storageRef.putFile(audioFile);
      String downloadUrl = await uploadTask.ref.getDownloadURL();

      setState(() {
        _audioDownloadUrl = downloadUrl;
      });
    } catch (e) {
      print("Error uploading audio: $e");
    }
  }

  Future<void> _sendQuestion(String messageText) async {
    if ((messageText.trim().isNotEmpty || selectedMediaFiles.isNotEmpty) && availableQuestions > 0) {
      String questionId = Uuid().v4();

      QuerySnapshot purchaseDocs = await _firestore.collection('users').doc(userId).collection('purchases').get();
      String? purchaseId;
      for (var doc in purchaseDocs.docs) {
        var data = doc.data() as Map<String, dynamic>;
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

      if (_audioDownloadUrl != null) {
        uploadedFiles.add({
          'media_url': _audioDownloadUrl!,
          'media_type': 'audio',
        });
      }

      for (var fileData in selectedMediaFiles) {
        String? mediaUrl = await _uploadMedia(fileData['file'], fileData['mediaType']);
        if (mediaUrl != null) {
          uploadedFiles.add({'media_url': mediaUrl, 'media_type': fileData['mediaType']});
        }
      }

      await _firestore.collection('users').doc(userId).collection('message').doc(questionId).set({
        'question_id': questionId,
        'message_text': messageText.isNotEmpty ? messageText : null,
        'media_files': uploadedFiles.isNotEmpty ? uploadedFiles : null,
        'from': userId,
        'timestamp': Timestamp.now(),
        'status': 'pending',
        'assigned_to_astrologer': false,
        'purchase_id': purchaseId,
      });

      await _firestore.collection('unassign').doc(questionId).set({
        'user_id': userId,
        'question_id': questionId,
        'status': 'unassigned',
        'timestamp': Timestamp.now(),
        'purchase_id': purchaseId,
      });

      await _firestore.collection('users').doc(userId).collection('purchases').doc(purchaseId).update({
        'status': 'used',
      });

      _analytics.logEvent(name: 'question_sent', parameters: {
        'user_id': userId!,
        'message_length': messageText.length,
        'media_files_count': uploadedFiles.length,
      });

      setState(() {
        availableQuestions--;
      });

      await _firestore.collection('users').doc(userId).update({
        'available_questions': availableQuestions,
      });

      _messageController.clear();
      selectedMediaFiles.clear();
      setState(() {
        _isAudioRecorded = false;
        _audioFilePath = null;
        _audioDownloadUrl = null;
      });
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

    _analytics.logEvent(name: 'navigated_to_buy_questions');

    if (result != null && result is bool && result == true) {
      await _loadUserProfile();
      setState(() {});
    }
  }

  Future<String?> _uploadMedia(File file, String mediaType) async {
    try {
      String fileId = Uuid().v4();
      Reference storageRef = _storage.ref().child('chat_media/$userId/$mediaType/$fileId');

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

  Widget _buildRecordingButton() {
    return GestureDetector(
      onLongPressStart: (_) => _recordAudio(),
      onLongPressEnd: (_) => _stopRecording(),
      child: Icon(
        _isRecording ? Icons.mic_off : Icons.mic,
        color: _isRecording ? Colors.red : Colors.black,
        size: 28,
      ),
    );
  }

  Widget _sendTextMessageUI() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(15)),
      ),
      padding: const EdgeInsets.all(8.0),
      margin: EdgeInsets.all(10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.amber[800], size: 28),
            onPressed: _showMediaOptions,
          ),
          _buildRecordingButton(),
          if (_isRecording)
            Expanded(child: SineWaveWidget(isPlaying: true)),
          if (!_isRecording)
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
    );
  }

  Future<void> _playPauseAudioAndWaveform() async {
    if (_audioFilePath == null) {
      print("No audio file to play.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No audio recorded to play.")),
      );
      return;
    }

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
        await _audioPlayer.play(DeviceFileSource(_audioFilePath!));
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

  void _resetAudioAndWaveform() {
    setState(() {
      _isPlayingAudio = false;
      _currentPosition = Duration.zero;
    });
  }

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
            onPressed: _playPauseAudio,
          ),
          Container(
            child: _isPlayingAudio ? SineWaveWidget(isPlaying: true) : Container(child: SineWaveWidget(isPlaying: false)),
          ),
          _buildRecordingButton(),
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

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: Colors.white,
        ),
        padding: EdgeInsets.all(10),
        child: Stack(
          children: [
            Container(
              margin: EdgeInsets.only(top: 150),
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/bg.png'),
                  fit: BoxFit.cover,
                ),
                borderRadius: BorderRadius.all(Radius.circular(15)),
              ),
            ),
            Column(
              children: [
                // Header Section
                Container(
                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, bottom: 0, left: 10, right: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Image.asset('assets/logo.png', height: 45, width: 45),
                          SizedBox(width: 10),
                          Text(
                            "StarSyync",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        child: Row(
                          children: <Widget>[
                            SizedBox(width: 20,),
                            GestureDetector(
                              onTap: _navigateToBuyQuestionsPage,
                              child: Container(
                                child: Row(
                                  children: <Widget>[
                                    Icon(Icons.account_balance_wallet_outlined,),
                                    SizedBox(width: 5,),
                                    Text("$availableQuestions")
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(width: 20,),
                            GestureDetector(
                              onTap: () async {
                                SharedPreferences prefs = await SharedPreferences.getInstance();
                                await prefs.clear(); // Clear shared preferences

                                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ProfilePage()));
                              },
                              child: Container(
                                child: Row(
                                  children: <Widget>[
                                    Icon(Icons.stars_outlined,),
                                    SizedBox(width: 5,),
                                    Text(name.toString().length > 6 ? name.toString().substring(0, 6) + ".." : name.toString())
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.only(top: 10, bottom: 10, left: 20, right: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: _navigateToBuyQuestionsPage,
                        child: Container(
                          padding: EdgeInsets.only(left: 20, right: 20, top: 5, bottom: 5),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(Icons.chat_bubble, color: Colors.white,),
                              SizedBox(width: 5,),
                              Text("Chat", style: TextStyle(color: Colors.white),)
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: (){
                          Navigator.push(context, MaterialPageRoute(builder: (context)=>Asrologerbranding()));
                        },
                        child: Container(
                          padding: EdgeInsets.only(left: 20, right: 20, top: 5, bottom: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(Icons.mark_chat_read_sharp, color: Colors.black,),
                              SizedBox(width: 5,),
                              Text("Astrologer", style: TextStyle(color: Colors.black),)
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: (){
                          Navigator.push(context, MaterialPageRoute(builder: (context)=>NeedHelp()));
                        },
                        child: Container(
                          child: Row(
                            children: <Widget>[
                              Icon(Icons.help,),
                              SizedBox(width: 5,),
                              Text("Need help?")
                            ],
                          ),
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

                          currentTimestamp = currentMessage['timestamp'] == null ? DateTime.now() : currentMessage['timestamp'];
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
                                Container(
                                  margin: EdgeInsets.only(bottom: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.8),
                                    borderRadius: BorderRadius.all(Radius.circular(10)),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                                  child: Text(
                                    DateFormat('EEEE, MMMM d, yyyy').format(currentTimestamp!.toDate()),
                                    style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              Align(
                                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: isUser ? 0.8 : 0.8, // Adjust width for user and astrologer messages
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
                                                Container(
                                                  child: Text(
                                                    isUser ? name.toString() : "The Real Astrologer",
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: isUser ? Colors.amber : Colors.white,
                                                    ),
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: isUser ? Colors.white : Colors.amber,
                                                    borderRadius: BorderRadius.only(
                                                      bottomLeft: Radius.circular(0),
                                                      topLeft: isUser ? Radius.circular(15) : Radius.circular(0),
                                                      bottomRight: Radius.circular(0),
                                                      topRight: isUser ? Radius.circular(5) : Radius.circular(15),
                                                    ),

                                                  ),
                                                  padding: EdgeInsets.only(top: 8, bottom: 8, left: 10, right: 5),
                                                ),
                                              Container(
                                                margin: EdgeInsets.only(top: 0, bottom: 0),
                                                padding: EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: isUser ? Colors.white : Colors.amberAccent.shade100,
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
                                                          color: isUser ? Colors.black : Colors.black,
                                                        ),
                                                      ),
                                                    if (currentMessage['media_files'] != null)
                                                      Column(
                                                        children: (currentMessage['media_files'] as List<dynamic>).map((media) {
                                                          if (media['media_type'] == 'image') {
                                                            return GestureDetector(
                                                              onTap: () {
                                                                Navigator.push(
                                                                  context,
                                                                  MaterialPageRoute(
                                                                    builder: (_) => FullScreenImagePage(imageUrl: media['media_url']),
                                                                  ),
                                                                );
                                                              },
                                                              child: Image.network(
                                                                media['media_url'],
                                                                height: 150, // You can adjust the height as needed
                                                                fit: BoxFit.cover,
                                                              ),
                                                            );
                                                          } else if (media['media_type'] == 'video') {
                                                            return VideoPlayerWidget(videoUrl: media['media_url']);
                                                          } else if (media['media_type'] == 'audio') {
                                                            return AudioPlayerWidget(audioUrl: media['media_url']);
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
                                          SizedBox(width: 44),
                                        if (isUser && showNameAndIcon)
                                          Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white, // Set the border color
                                                width: 2.0, // Set the border width
                                              ),
                                            ),
                                            child: CircleAvatar(
                                              backgroundImage: AssetImage(gender != "Male"
                                                  ? 'assets/woman.png'
                                                  : 'assets/man.png'),
                                              radius: 15,
                                            ),
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
                if (!_isAudioRecorded)
                  _sendTextMessageUI()

                else if(_isAudioRecorded)
                  _buildAudioReviewUI()
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    _recorder.closeRecorder();
    _audioPlayer.dispose(); // Dispose the audio player
    super.dispose();
    super.dispose();
  }


  Widget _buildAudioPlayer(String audioUrl) {
    final AudioPlayer audioPlayer = AudioPlayer();

    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.play_arrow),
          onPressed: () async {
            await audioPlayer.play(UrlSource(audioUrl)); // Use UrlSource for network URLs
          },
        ),
        IconButton(
          icon: Icon(Icons.stop),
          onPressed: () async {
            await audioPlayer.stop();
          },
        ),
      ],
    );
  }

  void _playPauseAudio() async {
    if (_audioFilePath == null) {
      print("No audio file to play.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No audio recorded to play.")),
      );
      return;
    }

    if (_isPlayingAudio) {
      // Pause the audio
      try {
        _isPlayingAudio = false;
        await _audioPlayer.pause();
        setState(() {
        });
      } catch (e) {
        print("Error pausing audio: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to pause audio.")),
        );
      }
    } else {
      // Play the audio
      try {
        _isPlayingAudio = true;
        await _audioPlayer.play(DeviceFileSource(_audioFilePath!));
        setState(() {
        });
      } catch (e) {
        print("Error playing audio: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to play audio.")),
        );
      }
    }
  }


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

  void _sendRecordedAudio() {
    _sendQuestion("I recorded my message in audio");
  }
}