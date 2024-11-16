// incoming_call_screen.dart
import 'package:flutter/material.dart';

import '../Services/call_service.dart';
import 'VideoCallScreen.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String userId;
  final String astrologerId;


  IncomingCallScreen({
    required this.callId,
    required this.userId,
    required this.astrologerId,});

  @override
  _IncomingCallScreenState createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final CallService _callService = CallService();

  @override
  void initState() {
    super.initState();
    _callService.playRingtone();
  }

  @override
  void dispose() {
    _callService.stopRingtone();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Incoming Call'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('You have an incoming call from ${widget.astrologerId}'),
            SizedBox(height: 20),
            ElevatedButton(
              child: Text('Accept'),
              onPressed: () {
                _callService.stopRingtone();
                _callService.acceptCall(widget.callId, widget.userId);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VideoCallScreen(
                      callId: widget.callId,
                      userId: widget.userId,
                      isCaller: false,
                      receiverId: widget.userId, // Since the call document is under the user's collection
                    ),
                  ),
                );
              },
            ),
            ElevatedButton(
              child: Text('Reject'),
              onPressed: () async {
                _callService.stopRingtone();
                await _callService.rejectCall(widget.callId, widget.userId);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
