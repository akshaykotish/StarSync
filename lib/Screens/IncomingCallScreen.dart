// IncomingCallScreen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'WebRTCVideoCallScreen.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String callerId;
  final String receiverId;
  final String callerName;

  const IncomingCallScreen({
    Key? key,
    required this.callId,
    required this.callerId,
    required this.receiverId,
    required this.callerName,
  }) : super(key: key);

  @override
  _IncomingCallScreenState createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _playRingtone();
  }

  void _playRingtone() async {
    // Make sure you have a "ringtone.mp3" in your assets and declared in pubspec.yaml
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource("ringtone.mp3"));
  }

  void _stopRingtone() async {
    await _audioPlayer.stop();
  }

  @override
  void dispose() {
    _stopRingtone();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _acceptCall() async {
    _stopRingtone();
    // Update call status to "in_progress" on Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.receiverId)
        .collection('calls')
        .doc(widget.callId)
        .update({"status": "in_progress"});

    // Then navigate to the actual video call screen (WebRTC)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => WebRTCVideoCallScreen(
          roomId: widget.callId,
          astrologerId: widget.callerId,
          userId: widget.receiverId,
        ),
      ),
    );
  }

  void _rejectCall() async {
    _stopRingtone();
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.receiverId)
        .collection('calls')
        .doc(widget.callId)
        .update({"status": "rejected"});
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Incoming Call"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              "${widget.callerName} is calling...",
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _acceptCall,
                  child: Text("Accept"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
                ElevatedButton(
                  onPressed: _rejectCall,
                  child: Text("Reject"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
