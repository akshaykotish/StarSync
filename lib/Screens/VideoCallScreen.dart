// video_call_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../Services/call_service.dart';

class VideoCallScreen extends StatefulWidget {
  final String callId;
  final String userId;
  final bool isCaller;
  final String receiverId; // The other participant's ID

  VideoCallScreen({ required this.callId,
    required this.userId,
    required this.isCaller,
    required this.receiverId,});

  @override
  _VideoCallScreenState createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final CallService _callService = CallService();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
    _callService.openUserMedia(_localRenderer, _remoteRenderer);
    _callService.joinCall(
      widget.callId,
      widget.userId,
      _localRenderer,
      _remoteRenderer,
      widget.isCaller,
      widget.receiverId,
        context
    );
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _callService.endCall(widget.callId, widget.userId, widget.receiverId, widget.isCaller);
    super.dispose();
  }

  Future<void> _initializeRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Video Call'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            _callService.endCall(widget.callId, widget.userId, widget.receiverId, widget.isCaller);
            Navigator.pop(context);
          },
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,),
          ),
          Positioned(
            right: 20,
            bottom: 100,
            child: Container(
              width: 120,
              height: 160,
              child: RTCVideoView(_localRenderer, mirror: true, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 50,
            right: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: Icon(_muted ? Icons.mic_off : Icons.mic),
                  color: Colors.white,
                  onPressed: () {
                    setState(() {
                      _muted = !_muted;
                      _callService.toggleMute(_muted);
                    });
                  },
                ),
                IconButton(
                  icon: Icon(Icons.call_end),
                  color: Colors.red,
                  onPressed: () {
                    _callService.endCall(widget.callId, widget.userId, widget.receiverId, widget.isCaller);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
