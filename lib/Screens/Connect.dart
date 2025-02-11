import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'WebRTCVideoCallScreen.dart';

class Connect extends StatefulWidget {
  final String astrologerId;
  final String userId;       // The user you want to call

  const Connect({Key? key, required this.astrologerId, required this.userId})
      : super(key: key);

  @override
  State<Connect> createState() => _ConnectState();
}

class _ConnectState extends State<Connect> {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.video_call, color: Colors.green),
      onPressed: () async {
        // Generate a unique callId
        String callId = Uuid().v4();

        // 1. Create a "call" document in the USER's subcollection indicating an incoming call
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('calls')
            .doc(callId)
            .set({
          'callId': callId,
          'astrologerId': widget.astrologerId,
          'callerName': 'Astrologer ${widget.astrologerId}',
          'status': 'calling',  // The user side listens for this
          'timestamp': Timestamp.now(),
        });

        // 2. Optionally, the astrologer can directly open the WebRTC screen
        //    while the user sees the "incoming call" UI.
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WebRTCVideoCallScreen(
              roomId: callId,
              astrologerId: widget.astrologerId,
              userId: widget.userId,
            ),
          ),
        );
      },
    );
  }
}
